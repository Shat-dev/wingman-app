# German App Store screenshots (1.15)

- `1284x2778/` holds the full-size set. Images 1, 3 and 4 are corrected copies of Arthur's Figma exports; 2 and 5 are unchanged copies.
- `1206x2622/` holds what is uploaded to App Store Connect (German, iPhone 6.1"/6.3", the required slot).
- `scripts/fix_screenshot_1.py` rebuilds image 1's bottom-right text from its own letters (`python3 fix_screenshot_1.py <in> <out> 0.93`).
- `scripts/fix_screenshots_3_4.py` re-sets the three practice cards across images 3 and 4 in Manrope (`<in3> <in4> <out3> <out4>`).
- `scripts/resize_1206.py <dir> <outdir>` scales to 2622 high and trims 3 px off each side.

If the Figma frames are fixed instead, export at 1284 × 2778 and run `resize_1206.py` before uploading.
