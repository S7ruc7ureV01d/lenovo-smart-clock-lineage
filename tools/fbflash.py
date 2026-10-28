# fbflash.py <image> <partition> [extra command...]: wait for LK fastboot, then send only
# download + flash (+ extras) over raw USB; this LK freezes on fastboot's own getvar queries
import sys, time, usb.core, usb.util
img, part, extra = sys.argv[1], sys.argv[2], sys.argv[3:]
data = open(img, "rb").read()
t0 = time.time()
while (dev := usb.core.find(idVendor=0x0bb4, idProduct=0x0c01)) is None:
    if time.time() - t0 > 300: sys.exit("no fastboot device after 300 s")
    time.sleep(0.1)
for _ in range(50):
    try:
        intf = dev.get_active_configuration()[(0, 0)]; break
    except usb.core.USBError: time.sleep(0.1)
if dev.is_kernel_driver_active(0): dev.detach_kernel_driver(0)
usb.util.claim_interface(dev, 0)
ep = lambda d: usb.util.find_descriptor(intf, custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == d)
out, inp = ep(usb.util.ENDPOINT_OUT), ep(usb.util.ENDPOINT_IN)
def reply(tmo=30000):
    while True:
        r = bytes(inp.read(256, timeout=tmo)).decode(errors="replace"); print("  <-", r, flush=True)
        if not r.startswith("INFO"): return r
def cmd(c, tmo=30000):
    print("->", c, flush=True); out.write(c.encode(), timeout=5000); return reply(tmo)
r = cmd("download:%08x" % len(data))
if not r.startswith("DATA"): sys.exit("download refused")
for off in range(0, len(data), 1 << 20):
    out.write(data[off:off + (1 << 20)], timeout=20000)
print("  sent %d bytes in %.1f s" % (len(data), time.time() - t0), flush=True)
if not reply().startswith("OKAY"): sys.exit("download failed")
if not cmd("flash:" + part, 120000).startswith("OKAY"): sys.exit("flash failed")
for c in extra: cmd(c)
