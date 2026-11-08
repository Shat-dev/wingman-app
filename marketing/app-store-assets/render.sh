#!/bin/zsh
# Renders each mockup to a PNG at App Store size, with the alpha channel removed.
#   ./render.sh            → png/*.png
#   ./render.sh guides     → png/*-guides.png (dashed assumed safe area)
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
suffix=""; query=""
[[ "$1" == "guides" ]] && suffix="-guides" && query="?guides"

render() { # name width height
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=3000 \
    --window-size=$2,$3 --screenshot="png/$1$suffix.png" "file://$PWD/$1.html$query" 2>/dev/null
}

render header-a 3840 1646
render header-b 3840 1646
render search-a 3840 2560
render search-b 3840 2560

# Apple rejects images with an alpha channel; also make a 1920×1280 search size.
python3 - "$suffix" <<'EOF'
import sys, glob
from PIL import Image
for p in glob.glob(f"png/*{sys.argv[1]}.png"):
    if sys.argv[1] == "" and "-guides" in p or "@1x" in p: continue
    im = Image.open(p).convert("RGB"); im.save(p)
    if "search" in p and not sys.argv[1]:
        im.resize((1920, 1280), Image.LANCZOS).save(p.replace(".png", "@1x.png"))
    print(p, im.size, im.mode)
EOF
