#!/usr/bin/env python3
"""Export lesson text for translation, and check the translations that come back.

The app's 94 lessons ship as 25 English JSON files, one per course. A
translation is a separate small file per course per language that maps the
English files' IDs to translated text (see Wingman/Content/LessonOverlay.swift):

    lesson_overlay_<courseId>_<language>.json
    {
      "lesson_14_1.title":   "...",
      "lesson_14_1.summary": "...",
      "course_14.summary":   "...",
      "content_14_1_1_1":    "..."
    }

Run from the repo root.

    python3 scripts/lesson_overlays.py export de out/
        Writes one file per course into out/, already named for German and
        in the app's format, with the ENGLISH text as each value. A
        translator replaces the values and sends the files back. Keys, and
        the order they are in, must not change.

    python3 scripts/lesson_overlays.py check de [folder]
        Checks every German overlay in the folder (default: anywhere under
        Wingman/) against the English lessons. Exits non-zero on a problem.

        Problems (the file must be fixed):
          - an ID the English lessons do not have (a typo, or the English
            changed since the export);
          - a blank translation;
          - a file that is not a flat JSON object of text.
        Notes (allowed; the app shows English for these):
          - IDs with no translation;
          - text still identical to the English.

    python3 scripts/lesson_overlays.py stats
        Words and items per course in the English lessons.

To ship a language, put its checked files anywhere under Wingman/ (for
example Wingman/Courses/Lesson Overlays/); the project picks them up. With no
file for a course the app shows that course in English.
"""

import argparse
import json
import sys
from collections import OrderedDict
from pathlib import Path

LESSONS = Path("Wingman/Courses/Wingman Lessons")
APP = Path("Wingman")


def english_by_course():
    """{courseId: OrderedDict(key -> English text)}, in reading order."""
    courses = {}
    for path in sorted(LESSONS.rglob("*.json")):
        lessons = json.loads(path.read_text(encoding="utf-8"))
        for lesson in sorted(lessons, key=lambda item: item["lessonNumber"]):
            course_id = lesson["courseId"]
            texts = courses.setdefault(course_id, OrderedDict())
            summary = lesson.get("courseSummary")
            if summary and f"{course_id}.summary" not in texts:
                texts[f"{course_id}.summary"] = summary
            texts[f"{lesson['id']}.title"] = lesson["title"]
            texts[f"{lesson['id']}.summary"] = lesson["summary"]
            for screen in sorted(lesson["screens"], key=lambda item: item["order"]):
                for paragraph in sorted(screen["content"], key=lambda item: item["order"]):
                    texts[paragraph["id"]] = paragraph["text"]
    return courses


def course_order(course_id):
    digits = "".join(character for character in course_id if character.isdigit())
    return int(digits) if digits else 0


def file_name(course_id, language):
    return f"lesson_overlay_{course_id}_{language}.json"


def export(language, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    courses = english_by_course()
    for course_id in sorted(courses, key=course_order):
        target = out_dir / file_name(course_id, language)
        target.write_text(
            json.dumps(courses[course_id], ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    items = sum(len(texts) for texts in courses.values())
    print(f"Wrote {len(courses)} files ({items} items) to {out_dir}/")
    print("Values are the English text; translate them in place and keep every key.")
    return 0


def check(language, folder):
    courses = english_by_course()
    suffix = f"_{language}.json"
    files = sorted(
        path for path in folder.rglob("lesson_overlay_*.json") if path.name.endswith(suffix)
    )
    if not files:
        print(f"No lesson overlays for '{language}' under {folder}/. The app shows lessons in English.")
        return 0

    problems = []
    seen_courses = set()
    total_translated = 0
    total_items = sum(len(texts) for texts in courses.values())

    for path in files:
        course_id = path.name[len("lesson_overlay_"):-len(suffix)]
        if course_id not in courses:
            problems.append(f"{path}: there is no course '{course_id}'")
            continue
        if course_id in seen_courses:
            problems.append(f"{path}: a second overlay for {course_id} in '{language}'")
            continue
        seen_courses.add(course_id)

        try:
            overlay = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as problem:
            problems.append(f"{path}: cannot be read as JSON: {problem}")
            continue
        if not isinstance(overlay, dict) or not all(isinstance(value, str) for value in overlay.values()):
            problems.append(f"{path}: must be one flat JSON object whose values are all text")
            continue

        english = courses[course_id]
        unknown = [key for key in overlay if key not in english]
        blank = [key for key, value in overlay.items() if key in english and not value.strip()]
        missing = [key for key in english if key not in overlay]
        same = [key for key, value in overlay.items() if key in english and value.strip() and value == english[key]]
        translated = len(overlay) - len(unknown) - len(blank) - len(same)
        total_translated += translated

        for key in unknown:
            problems.append(f"{path}: '{key}' is not an ID in the English lessons")
        for key in blank:
            problems.append(f"{path}: '{key}' is blank")

        notes = []
        if missing:
            notes.append(f"{len(missing)} not translated")
        if same:
            notes.append(f"{len(same)} identical to English")
        print(
            f"{course_id}: {translated} of {len(english)} translated"
            + (f" ({', '.join(notes)}; shown in English)" if notes else "")
        )

    untouched = sorted(set(courses) - seen_courses, key=course_order)
    if untouched:
        print(f"No overlay for {len(untouched)} course(s): {', '.join(untouched)} (shown in English)")
    print(f"\n{language}: {total_translated} of {total_items} items translated across {len(seen_courses)} course(s).")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print("OK: no problems found.")
    return 0


def stats():
    courses = english_by_course()
    total_items = total_words = 0
    for course_id in sorted(courses, key=course_order):
        texts = courses[course_id]
        words = sum(len(text.split()) for text in texts.values())
        total_items += len(texts)
        total_words += words
        print(f"{course_id}: {len(texts)} items, {words} words")
    print(f"\n{len(courses)} courses, {total_items} items, {total_words} words")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    export_parser = commands.add_parser("export", help="write English text per course, in the overlay format")
    export_parser.add_argument("language", help="language tag for the file names, e.g. de")
    export_parser.add_argument("out_dir", type=Path)

    check_parser = commands.add_parser("check", help="check overlay files against the English lessons")
    check_parser.add_argument("language", help="language tag, e.g. de")
    check_parser.add_argument("folder", type=Path, nargs="?", default=APP)

    commands.add_parser("stats", help="items and words per course")

    arguments = parser.parse_args()
    if not LESSONS.is_dir():
        print(f"Run from the repo root: {LESSONS}/ not found.")
        return 2
    if arguments.command == "export":
        return export(arguments.language, arguments.out_dir)
    if arguments.command == "check":
        return check(arguments.language, arguments.folder)
    return stats()


if __name__ == "__main__":
    sys.exit(main())
