# Generates prebuilt/vbmeta_stock_slot_b.img (inside the build box, python2):
#   python2 stockdesc.py external/avb/avbtool backup/vbmeta_b.img prebuilt/vbmeta_stock_slot_b.img oem_bootloader factory oem
# stockdesc.py <avbtool> <stock vbmeta> <out> <partition>...: unsigned vbmeta holding only the
# named partitions' descriptors from the stock vbmeta, for --include_descriptors_from_image
import imp, sys
avbtool = imp.load_source('avbtool', sys.argv[1])
avb = avbtool.Avb()
_, _, descs, _ = avb._parse_image(avbtool.ImageHandler(sys.argv[2]))
keep = [d for d in descs if getattr(d, 'partition_name', None) in sys.argv[4:]]
assert sorted(d.partition_name for d in keep) == sorted(sys.argv[4:]), keep
blob = avb._generate_vbmeta_blob('NONE', None, None, keep, None, 0, 0, None, None, None,
                                 False, None, None, None, None, 'avbtool', None, 0)
open(sys.argv[3], 'wb').write(blob)
print('kept', [d.partition_name for d in keep])
