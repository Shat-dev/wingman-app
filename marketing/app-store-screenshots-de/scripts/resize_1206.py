# 1284x2778 -> 1206x2622 (Apple's required iPhone 6.1"/6.3" slot): scale to height, trim 3 px each side.
import sys, glob, os
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
for p in sorted(glob.glob(os.path.join(src, '*.png'))):
    im = Image.open(p).convert('RGB')
    h = 2622; w = round(im.width * h / im.height)
    im = im.resize((w, h), Image.LANCZOS)
    l = (w - 1206) // 2
    im.crop((l, 0, l + 1206, h)).save(os.path.join(dst, os.path.basename(p)))
