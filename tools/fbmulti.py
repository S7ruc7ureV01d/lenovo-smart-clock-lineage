# fbmulti.py <file=partition | cmd:COMMAND>...: wait for LK fastboot, then flash each file to its
# partition (download + flash only) and send raw commands, in order, in one USB session
import sys, time, usb.core, usb.util
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
def reply(tmo=60000):
    while True:
        r = bytes(inp.read(256, timeout=tmo)).decode(errors="replace"); print("  <-", r, flush=True)
        if not r.startswith("INFO"): return r
def cmd(c, tmo=60000):
    print("->", c, flush=True); out.write(c.encode(), timeout=5000); return reply(tmo)
for arg in sys.argv[1:]:
    if arg.startswith("cmd:"):
        if not cmd(arg[4:]).startswith("OKAY"): sys.exit("command failed")
        continue
    path, part = arg.rsplit("=", 1); data = open(path, "rb").read(); t1 = time.time()
    if not cmd("download:%08x" % len(data)).startswith("DATA"): sys.exit("download refused")
    for off in range(0, len(data), 1 << 20):
        out.write(data[off:off + (1 << 20)], timeout=30000)
    if not reply().startswith("OKAY"): sys.exit("download failed")
    print("  %s: %d bytes in %.1f s" % (path.rsplit("/", 1)[-1], len(data), time.time() - t1), flush=True)
    if not cmd("flash:" + part, 300000).startswith("OKAY"): sys.exit("flash failed: " + part)
print("ALL DONE in %.0f s" % (time.time() - t0))
