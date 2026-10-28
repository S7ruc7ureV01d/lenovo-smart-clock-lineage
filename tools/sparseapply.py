# sparseapply.py <raw_out> <size> <piece>...: apply sparse pieces onto a zeroed raw image (self-test)
import struct, sys
out, size = sys.argv[1], int(sys.argv[2])
img = bytearray(size)
for p in sys.argv[3:]:
    f = open(p, "rb"); _, _, _, _, _, blk, tb, tc, _ = struct.unpack("<IHHHHIIII", f.read(28)); at = 0
    for _ in range(tc):
        t, _, n, sz = struct.unpack("<HHII", f.read(12)); body = f.read(sz - 12)
        if t == 0xCAC1: img[at * blk:(at + n) * blk] = body
        elif t == 0xCAC2: img[at * blk:(at + n) * blk] = body * (n * blk // 4)
        at += n
open(out, "wb").write(img)
