/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * On stock, the Android Things OEM app (sparrow.oem) drives the speaker amp
 * and microphone ADC over userspace I2C/GPIO and reads the volume keys from
 * GPIOs. Without the Things framework this daemon does the same: it sets up
 * the amp and ADC once, then turns volume key GPIO changes into key events.
 */

#define LOG_TAG "smartclockd"

#include <errno.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <log/log.h>

#include "tables.h"

/* Linux GPIO numbers: the SoC pinctrl starts at 387, the PMIC GPIO is 576 */
#define GPIO_AMP_EN (387 + 19)
#define GPIO_ADC_RESET (387 + 24)
#define GPIO_VOLUME_UP (387 + 42)
#define GPIO_VOLUME_DOWN 576
/* Back slider; high = muted (stock GpioMicObserver, active high) */
#define GPIO_MIC_MUTE (387 + 23)

#define AMP_I2C_BUS "/dev/i2c-2"
#define AMP_I2C_ADDR 0x2c
#define ADC_I2C_BUS "/dev/i2c-1"
#define ADC_I2C_ADDR 0x1b

#define KEY_POLL_US 20000
#define COMBO_WINDOW_US 100000
#define MUTE_DEBOUNCE_US 200000

static int write_file(const char* path, const char* value) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) return -errno;
    int ret = write(fd, value, strlen(value)) < 0 ? -errno : 0;
    close(fd);
    return ret;
}

static int gpio_setup(int gpio, const char* direction) {
    char path[64], num[16];
    snprintf(num, sizeof(num), "%d", gpio);
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio);
    if (access(path, F_OK)) write_file("/sys/class/gpio/export", num);
    int ret = write_file(path, direction);
    if (ret) ALOGE("gpio%d: direction %s: %s", gpio, direction, strerror(-ret));
    return ret;
}

static void gpio_write(int gpio, const char* value) {
    char path[64];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio);
    write_file(path, value);
}

static int gpio_open_value(int gpio) {
    char path[64];
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio);
    return open(path, O_RDONLY);
}

static int gpio_read(int fd) {
    char c;
    if (pread(fd, &c, 1, 0) != 1) return -1;
    return c == '1';
}

static int i2c_write_table(const char* bus, int addr, const uint8_t (*table)[2], size_t count) {
    int fd = open(bus, O_RDWR);
    if (fd < 0) {
        ALOGE("%s: %s", bus, strerror(errno));
        return -1;
    }
    if (ioctl(fd, I2C_SLAVE, addr) < 0) {
        ALOGE("%s 0x%02x: I2C_SLAVE: %s", bus, addr, strerror(errno));
        close(fd);
        return -1;
    }
    size_t failed = 0;
    for (size_t i = 0; i < count; i++) {
        if (write(fd, table[i], 2) != 2) failed++;
    }
    close(fd);
    if (failed) ALOGE("%s 0x%02x: %zu of %zu writes failed", bus, addr, failed, count);
    return failed ? -1 : 0;
}

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

static void amp_init(void) {
    /* Same order as Lenovo.enableAmplifier() then turnonAmplifier(true). The
     * amp is left out of standby for good: the 8.1 HAL has no hook for it. */
    static const uint8_t play[][2] = {{0, 0}, {127, 0}, {3, 3}};
    gpio_setup(GPIO_AMP_EN, "high");
    usleep(10000);
    i2c_write_table(AMP_I2C_BUS, AMP_I2C_ADDR, amp_mute, ARRAY_SIZE(amp_mute));
    i2c_write_table(AMP_I2C_BUS, AMP_I2C_ADDR, play, ARRAY_SIZE(play));
    usleep(10000);
    if (!i2c_write_table(AMP_I2C_BUS, AMP_I2C_ADDR, amp_setup, ARRAY_SIZE(amp_setup)))
        ALOGI("amplifier initialized");
}

static void mic_init(void) {
    /* Lenovo.enableMicrophone(): pulse the ADC reset, then load its setup */
    gpio_setup(GPIO_ADC_RESET, "high");
    gpio_write(GPIO_ADC_RESET, "0");
    usleep(20000);
    gpio_write(GPIO_ADC_RESET, "1");
    if (!i2c_write_table(ADC_I2C_BUS, ADC_I2C_ADDR, mic_setup, ARRAY_SIZE(mic_setup)))
        ALOGI("microphone ADC initialized");
}

static void mic_set_muted(int muted) {
    /* TLV320ADC page 0 register 82: bit 7 mutes the left channel, bit 3 the
     * right one. The stock app only reported the switch to the Things
     * framework; muting the ADC itself holds for every app. */
    const uint8_t regs[][2] = {{0, 0}, {82, muted ? 0x88 : 0x00}};
    if (!i2c_write_table(ADC_I2C_BUS, ADC_I2C_ADDR, regs, ARRAY_SIZE(regs)))
        ALOGI("microphone %s", muted ? "muted" : "unmuted");
}

static int uinput_open(void) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        ALOGE("/dev/uinput: %s", strerror(errno));
        return -1;
    }
    struct uinput_user_dev dev;
    memset(&dev, 0, sizeof(dev));
    snprintf(dev.name, sizeof(dev.name), "smartclock-keys");
    dev.id.bustype = BUS_HOST;
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_KEYBIT, KEY_VOLUMEUP);
    ioctl(fd, UI_SET_KEYBIT, KEY_VOLUMEDOWN);
    ioctl(fd, UI_SET_KEYBIT, KEY_POWER);
    if (write(fd, &dev, sizeof(dev)) != sizeof(dev) || ioctl(fd, UI_DEV_CREATE) < 0) {
        ALOGE("uinput setup: %s", strerror(errno));
        close(fd);
        return -1;
    }
    return fd;
}

static void emit_key(int fd, int code, int value) {
    struct input_event ev[2];
    memset(ev, 0, sizeof(ev));
    ev[0].type = EV_KEY;
    ev[0].code = code;
    ev[0].value = value;
    ev[1].type = EV_SYN;
    ev[1].code = SYN_REPORT;
    write(fd, ev, sizeof(ev));
}

struct key {
    int gpio, active_level, code, fd;
    int pressed;  /* debounced physical state */
    int sent;     /* key down already sent to Android */
    int held_us;  /* time since press, while not yet sent */
};

int main(void) {
    amp_init();
    mic_init();

    /* The device has no battery and nothing here can wake it from suspend
     * (the GPIOs are polled), so stay awake */
    write_file("/sys/power/wake_lock", "smartclockd");

    struct key keys[] = {
        {GPIO_VOLUME_UP, 0, KEY_VOLUMEUP, -1, 0, 0, 0},
        {GPIO_VOLUME_DOWN, 1, KEY_VOLUMEDOWN, -1, 0, 0, 0},
    };
    for (size_t i = 0; i < ARRAY_SIZE(keys); i++) {
        gpio_setup(keys[i].gpio, "in");
        keys[i].fd = gpio_open_value(keys[i].gpio);
    }

    gpio_setup(GPIO_MIC_MUTE, "in");
    int mute_fd = gpio_open_value(GPIO_MIC_MUTE);
    int muted = gpio_read(mute_fd) == 1;
    int mute_changed_us = -1;
    mic_set_muted(muted);

    int ui = uinput_open();
    if (ui < 0) return 1;

    /* Volume up + down together act as power. A key's own event waits
     * COMBO_WINDOW_US so that the second key can still join in. */
    int combo = 0;
    for (;;) {
        usleep(KEY_POLL_US);

        for (size_t i = 0; i < ARRAY_SIZE(keys); i++) {
            struct key* k = &keys[i];
            int level = gpio_read(k->fd);
            if (level < 0) continue;
            int pressed = level == k->active_level;
            if (pressed && !k->pressed) k->held_us = 0;
            if (!pressed && k->pressed && !combo) {
                if (!k->sent) emit_key(ui, k->code, 1);  /* short tap */
                emit_key(ui, k->code, 0);
                k->sent = 0;
            }
            k->pressed = pressed;
        }

        if (keys[0].pressed && keys[1].pressed && !combo) {
            combo = 1;
            for (size_t i = 0; i < ARRAY_SIZE(keys); i++) {
                if (keys[i].sent) emit_key(ui, keys[i].code, 0);
                keys[i].sent = 0;
            }
            emit_key(ui, KEY_POWER, 1);
        } else if (combo && !keys[0].pressed && !keys[1].pressed) {
            combo = 0;
            emit_key(ui, KEY_POWER, 0);
        } else if (!combo) {
            for (size_t i = 0; i < ARRAY_SIZE(keys); i++) {
                struct key* k = &keys[i];
                if (!k->pressed || k->sent) continue;
                k->held_us += KEY_POLL_US;
                if (k->held_us >= COMBO_WINDOW_US) {
                    emit_key(ui, k->code, 1);
                    k->sent = 1;
                }
            }
        }

        /* Mute slider, debounced like the stock app (200 ms) */
        int m = gpio_read(mute_fd) == 1;
        if (m != muted) {
            if (mute_changed_us < 0) mute_changed_us = 0;
            mute_changed_us += KEY_POLL_US;
            if (mute_changed_us >= MUTE_DEBOUNCE_US) {
                muted = m;
                mute_changed_us = -1;
                mic_set_muted(muted);
            }
        } else {
            mute_changed_us = -1;
        }
    }
}
