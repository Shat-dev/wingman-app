#!/usr/bin/env python3
"""Pull screenshots out of a UI-test run and compare them with a baseline.

The onboarding sweep (WingmanUITests/OnboardingSweepTests) attaches a named
screenshot of every screen to its test result. This script turns a result
bundle into a folder of PNGs and compares that folder, pixel for pixel, with
the reference set in docs/localization-baseline/.

    python3 scripts/screenshots.py export run.xcresult out/
        Writes every attachment whose name starts with two digits
        ("01-landing", "17-paywall", "17b-paywall-monthly-selected", …) to
        out/<name>.png.

    python3 scripts/screenshots.py compare docs/localization-baseline/iphone-17-pro out/
        Compares each PNG in the baseline folder with the one of the same
        name in out/. Exits non-zero if any differs.

        --ignore-top N     skip the top N pixels (default 190: the status
                           bar, whose clock changes every minute)
        --allow NAME       a screen that is expected to differ (an animation
                           caught mid-frame); may be given more than once.
                           It is still measured and reported.
        --only-numbered-to N
                           compare only screens numbered up to N (the first
                           17 are the fixed onboarding path; later ones show
                           content that changes between runs)

Needs Pillow (`python3 -m pip install Pillow`). Run from the repo root.

A typical check after a layout change (the sweep creates a guest user in
production each time it runs; see the note in OnboardingSweepTests.swift):

    xcodebuild test -project Wingman.xcodeproj -scheme Wingman \\
        -destination 'platform=iOS Simulator,name=Wingman L10n 17 Pro' \\
        -skipMacroValidation -skipPackagePluginValidation \\
        -only-testing:WingmanUITests/OnboardingSweepTests/testOnboardingToPaywall \\
        -resultBundlePath /tmp/sweep.xcresult
    python3 scripts/screenshots.py export /tmp/sweep.xcresult /tmp/sweep
    python3 scripts/screenshots.py compare docs/localization-baseline/iphone-17-pro /tmp/sweep \\
        --only-numbered-to 17 --allow 14-loading-notification-prompt
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

NUMBERED = re.compile(r"^(\d{2,3})[a-z]?-")


def export(result_bundle, out_dir):
    if not result_bundle.exists():
        print(f"{result_bundle} does not exist.")
        return 2
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as scratch:
        completed = subprocess.run(
            ["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_bundle), "--output-path", scratch],
            capture_output=True, text=True,
        )
        manifest_path = Path(scratch) / "manifest.json"
        if completed.returncode != 0 or not manifest_path.exists():
            print(f"xcresulttool could not export attachments:\n{completed.stderr.strip()}")
            return 2
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        written = []
        for test in manifest:
            for attachment in test.get("attachments", []):
                suggested = attachment.get("suggestedHumanReadableName", "")
                if not NUMBERED.match(suggested):
                    continue
                # "17-paywall_0_<UUID>.png" -> "17-paywall"
                name = suggested.rsplit("_", 2)[0]
                shutil.copy(Path(scratch) / attachment["exportedFileName"], out_dir / f"{name}.png")
                written.append(name)
    print(f"Wrote {len(written)} screenshots to {out_dir}/")
    return 0 if written else 1


def compare(baseline_dir, new_dir, ignore_top, allowed, only_numbered_to):
    try:
        from PIL import Image, ImageChops
    except ImportError:
        print("This command needs Pillow: python3 -m pip install Pillow")
        return 2

    baseline = sorted(baseline_dir.glob("*.png"))
    if only_numbered_to is not None:
        baseline = [
            path for path in baseline
            if NUMBERED.match(path.name) and int(NUMBERED.match(path.name).group(1)) <= only_numbered_to
        ]
    if not baseline:
        print(f"No baseline screenshots found in {baseline_dir}/")
        return 2

    identical = 0
    problems = []
    for reference in baseline:
        name = reference.stem
        candidate = new_dir / reference.name
        if not candidate.exists():
            problems.append(f"{name}: missing from {new_dir}/")
            continue
        before = Image.open(reference).convert("RGB")
        after = Image.open(candidate).convert("RGB")
        if before.size != after.size:
            problems.append(f"{name}: size {after.size} does not match the baseline's {before.size}")
            continue
        box = (0, min(ignore_top, before.height), before.width, before.height)
        difference = ImageChops.difference(before.crop(box), after.crop(box))
        bounds = difference.getbbox()
        if bounds is None:
            identical += 1
            print(f"{name}: identical")
            continue
        changed = sum(1 for pixel in difference.getdata() if pixel != (0, 0, 0))
        share = 100 * changed / (difference.width * difference.height)
        where = (bounds[0], bounds[1] + box[1], bounds[2], bounds[3] + box[1])
        line = f"{name}: {share:.3f}% of pixels differ, inside {where}"
        if name in allowed:
            print(f"{line} (allowed)")
        else:
            print(line)
            problems.append(line)

    print(f"\n{identical} of {len(baseline)} identical below the top {ignore_top} px.")
    if problems:
        print(f"{len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print("OK: nothing unexpected differs.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    export_parser = commands.add_parser("export", help="write a test run's numbered screenshots to a folder")
    export_parser.add_argument("result_bundle", type=Path)
    export_parser.add_argument("out_dir", type=Path)

    compare_parser = commands.add_parser("compare", help="compare a folder of screenshots with a baseline folder")
    compare_parser.add_argument("baseline_dir", type=Path)
    compare_parser.add_argument("new_dir", type=Path)
    compare_parser.add_argument("--ignore-top", type=int, default=190)
    compare_parser.add_argument("--allow", action="append", default=[])
    compare_parser.add_argument("--only-numbered-to", type=int, default=None)

    arguments = parser.parse_args()
    if arguments.command == "export":
        return export(arguments.result_bundle, arguments.out_dir)
    return compare(
        arguments.baseline_dir, arguments.new_dir, arguments.ignore_top,
        set(arguments.allow), arguments.only_numbered_to,
    )


if __name__ == "__main__":
    sys.exit(main())
