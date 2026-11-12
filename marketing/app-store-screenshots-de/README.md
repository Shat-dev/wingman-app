# German App Store screenshots (1.15)

- `1284x2778/` holds the full-size set, from Arthur's Figma export of 2026-11-12 23:06 (`Assets/Base #1/Base #1/`), in upload order: 1 = `1.png`, 2 = `2.png`, 3 = `5.png` (Quiz), 4 = `7.png` and 5 = `6.png` (the scenario cards, left half then right half). Images 4 and 5 have the German cards applied by `fix_screenshots_3_4.py`; 1–3 are unchanged copies of the export. Image 1's headline still lacks the comma in "der Chancen, die" (Figma fix). Image 2's lesson cards still show English titles; the app shows German ones.
- `1206x2622/` holds what is uploaded to App Store Connect (German, iPhone 6.1"/6.3", the required slot).
- `scripts/fix_screenshot_1.py` rebuilds image 1's bottom-right text from its own letters (`python3 fix_screenshot_1.py <in> <out> 0.93`).
- `scripts/fix_screenshots_3_4.py` re-sets the three practice cards across images 3 and 4 in Manrope (`<in3> <in4> <out3> <out4>`).
- `scripts/resize_1206.py <dir> <outdir>` scales to 2622 high and trims 3 px off each side.

If the Figma frames are fixed instead, export at 1284 × 2778 and run `resize_1206.py` before uploading.
