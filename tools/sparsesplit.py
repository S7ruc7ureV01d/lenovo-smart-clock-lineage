# sparsesplit.py <sparse.img> <out_prefix> <max_bytes>: split an Android sparse image into
# pieces <= max_bytes, each covering the whole partition (gaps as DONT_CARE), like libsparse resparse
import struct, sys
RAW, FILL, DONT_CARE, CRC = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4
src, prefix, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
f = open(src, "rb")
magic, major, minor, fhs, chs, blk, total_blks, total_chunks, _ = struct.unpack("<IHHHHIIII", f.read(28))
assert magic == 0xED26FF3A and fhs == 28 and chs == 12
chunks, pos = [], 0  # (start_block, type, nblocks, payload)
for _ in range(total_chunks):
    t, _, n, sz = struct.unpack("<HHII", f.read(12))
    body = f.read(sz - 12)
    if t == RAW:
        chunks.append((pos, RAW, n, body))
    elif t == FILL:
        chunks.append((pos, FILL, n, body))
    pos += n if t != CRC else 0
assert pos == total_blks
pieces, cur, cur_size = [], [], 28 + 2 * 12
for start, t, n, body in chunks:
    while n:
        room = limit - cur_size - 2 * 12
        take = n if t == FILL else min(n, max(room // blk, 0))
        cost = 12 + (len(body) if t == FILL else take * blk)
        if take == 0 or cost > limit - cur_size - 12:
            pieces.append(cur); cur, cur_size = [], 28 + 2 * 12; continue
        cur.append((start, t, take, body if t == FILL else body[:take * blk]))
        cur_size += cost
        if t == RAW: body = body[take * blk:]
        start += take; n -= take
if cur: pieces.append(cur)
def hdr(t, n, payload_len): return struct.pack("<HHII", t, 0, n, 12 + payload_len)
for i, piece in enumerate(pieces):
    out, at = [], 0
    for start, t, n, body in piece:
        if start > at: out.append(hdr(DONT_CARE, start - at, 0))
        out.append(hdr(t, n, len(body)) + body); at = start + n
    if at < total_blks: out.append(hdr(DONT_CARE, total_blks - at, 0))
    data = struct.pack("<IHHHHIIII", magic, 1, 0, 28, 12, blk, total_blks, len(out), 0) + b"".join(out)
    assert len(data) <= limit
    open("%s.%d" % (prefix, i), "wb").write(data)
    print("%s.%d %d bytes, %d chunks" % (prefix, i, len(data), len(out)))
