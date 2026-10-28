# fbraw.py <command>...: send raw fastboot commands (no extra getvar queries) and print replies
import sys, usb.core, usb.util
dev = usb.core.find(idVendor=0x0bb4, idProduct=0x0c01)
if dev is None: sys.exit("no fastboot device")
cfg = dev.get_active_configuration(); intf = cfg[(0, 0)]
if dev.is_kernel_driver_active(0): dev.detach_kernel_driver(0)
usb.util.claim_interface(dev, 0)
ep = lambda d: usb.util.find_descriptor(intf, custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == d)
out, inp = ep(usb.util.ENDPOINT_OUT), ep(usb.util.ENDPOINT_IN)
for cmd in sys.argv[1:]:
    out.write(cmd.encode(), timeout=5000)
    while True:
        r = bytes(inp.read(256, timeout=10000)).decode(errors="replace")
        print(f"{cmd!r} -> {r!r}")
        if not r.startswith("INFO"): break
