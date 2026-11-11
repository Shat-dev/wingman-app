#!/usr/bin/env python3
"""Build the German review pack: one Excel workbook for a native proofreader.

    python3 scripts/german_review_pack.py [out.xlsx]

Default output: localization/de/review/wingman-german-review-pack.xlsx

Sheets:
  Read me          what the app is, the house rules, how to fill the sheet in
  Choices to check translation decisions the reviewer should confirm or change
  Interface        every app string (Localizable catalog + onboarding answers
                   and course titles from Content), English next to the German
                   draft, sorted so paywall, sign-in, onboarding and
                   notifications come first
  Lesson 1_1, Lesson 6_1
                   two sample lessons, paragraph by paragraph
  Daily quotes     the 120 Home-screen quotes (lower priority)

The reviewer writes only in the yellow columns ("Your version", "Status",
"Comment"). The grey "Key" column identifies each row for re-import (catalog
name and English key, or the lesson overlay id); it must not be edited.
Reads the repo only; changes nothing.
"""

import json
import re
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lesson_overlays  # noqa: E402
from check_string_catalogs import LENGTH_LIMITS  # noqa: E402

CATALOG_FILES = {
    "Localizable": Path("Wingman/Resources/Localizable.xcstrings"),
    "Content": Path("Wingman/Resources/Content.xcstrings"),
}
DRAFT = Path("localization/de/catalogs.de.json")
OUT = Path("localization/de/review/wingman-german-review-pack.xlsx")
SAMPLE_LESSONS = [("course_1", "lesson_1_1"), ("course_6", "lesson_6_1")]

# Where a string is used -> (area, order, priority). First match wins.
AREAS = [
    (r"Payment/|Paywall|OneTimeOffer|Offer", "Paywall & one-time offer", 1, "Must read"),
    (r"Auth/|Landing/", "Sign-in & account", 2, "Must read"),
    (r"Onboarding/|Commitment/", "Onboarding", 3, "Must read"),
    (r"Notification", "Notifications", 4, "Must read"),
    (r"Walkthrough/", "First-run walkthrough", 5, "Read"),
    (r"Home/|DailyPractice/", "Home & Daily Practice", 6, "Read"),
    (r"Courses/|Lesson/|Quiz/", "Courses, lessons & quiz", 7, "Read"),
    (r"PracticeGame/", "Scenarios", 8, "Read"),
    (r"LogApproch/", "Logging an approach", 9, "Read"),
    (r"Profile/|XP/", "Profile, settings & XP", 10, "Read"),
]
OTHER = ("Other / shared", 11, "Read")
# The catalog comment, when there is one, says where a string is shown more
# reliably than a text search does. Checked before the source search.
COMMENT_AREAS = [
    (r"(?i)one-time offer|paywall|subscription plan|purchase button", "Paywall & one-time offer"),
    (r"(?i)notification", "Notifications"),
    (r"(?i)onboarding|commitment", "Onboarding"),
    (r"(?i)sign[- ]in|account", "Sign-in & account"),
    (r"(?i)\bXP\b|level", "Profile, settings & XP"),
    (r"(?i)scenario", "Scenarios"),
    (r"(?i)approach", "Logging an approach"),
    (r"(?i)lesson|course|quiz", "Courses, lessons & quiz"),
    (r"(?i)home|daily practice", "Home & Daily Practice"),
]

CHOICES = [
    ("Tone overall", "Calm, direct older brother; informal du everywhere, including errors and the paywall.", "Whole app", "Does it sound like a German man would talk? Anything stiff, translated or cringe?"),
    ("„…“ quotation marks", "German quotes open low and close high: „So wie hier.“", "Whole app", "Deliberate. Confirm; Arthur asked about it."),
    ("Scheiß drauf", "\"screw it\" became Scheiß drauf (course 2, Fear & Exposure).", "Lessons", "Coarsest phrase in the app. Keep, or soften to Egal?"),
    ("flirty / flirtend", "\"flirtatious\" appears as both flirtend and flirty (the paywall tick uses flirty).", "Lessons, paywall", "Pick one."),
    ("Social Proof", "\"social proof\" became sozialer Beweis (Social Proof).", "Lessons", "Natural, or too technical?"),
    ("Course titles", "Guessed without the lesson text: Die Annäherung (The Physical Approach), Das Pflichtprogramm (Non-negotiables), Der Abschluss (Closing), Bereit zum Ansprechen (Approach Readiness).", "Interface sheet, area Courses", "Check each against its lessons."),
    ("Der Held deines Lebens", "Nora Ephron's \"be the heroine of your life\" became der Held deines Lebens, since the readers are men.", "Daily quotes", "Keep, or restore the original?"),
    ("Guten Tag,", "Home greeting from 12:00 to 17:59 (Guten Morgen, / Guten Tag, / Guten Abend,). \"Guten Nachmittag\" is rarely said.", "Interface sheet, area Home", "Agree?"),
    ("Loanwords kept", "Smalltalk, Opener, Date, Feedback, Level, Mindset, Lifestyle stay as normal German usage.", "Whole app", "Any that sound wrong to you?"),
    ("Never translated", "Wingman, XP and the five category names (Mindset & Foundations, Approach Mechanics, Conversation Flow, Flirting & Chemistry, Integration & Mastery) stay in English.", "Whole app", "Deliberate; no change needed."),
    ("Abo, gratis, Testzeitraum", "Subscription = Abo (Monatsabo, Jahresabo); free trial = gratis on a badge, Testzeitraum in sentences.", "Paywall", "Natural?"),
    ("AGB / Datenschutz", "Footer links read AGB and Datenschutz; the pages themselves stay English for now.", "Sign-in, paywall", "OK?"),
]

RULES = [
    "Edit only the yellow columns: \"Your version\", \"Status\" and \"Comment\". Leave a row's \"Your version\" empty if the German is fine, and set Status to OK.",
    "Keep placeholders exactly: %@, %lld, %1$@, %2$lld and so on. They may move within the sentence, but don't change, add or remove them. %% is a percent sign.",
    "Keep link targets: in [AGB](terms) translate the word in square brackets only; never change (terms) or (privacy).",
    "Paywall ticks have a hard limit of 36 characters (see the \"Max length\" column); longer lines get hidden on small iPhones.",
    "Use du everywhere. Imperatives in the short form: versuch, wähl, prüf.",
    "Numbers: a space before %, as in 45 %. Ranges with an en dash: 18–24. Ellipsis: Wird geladen … (space, then the single … character).",
    "Adapt rather than translate word for word: if an American image doesn't land in German, replace it with one that does.",
    "Don't edit the grey Key column; it is how your changes get back into the app.",
]

YELLOW = PatternFill("solid", start_color="FFF6CC")
HEADER = PatternFill("solid", start_color="1F1F1F")
MUST = PatternFill("solid", start_color="FDE2E1")
GREY = Font(name="Arial", size=8, color="8A8A8A")
BODY = Font(name="Arial", size=10)
BOLD = Font(name="Arial", size=10, bold=True)
HEAD = Font(name="Arial", size=10, bold=True, color="FFFFFF")
WRAP = Alignment(wrap_text=True, vertical="top")


def swift_sources():
    """Swift files with \\u{2019}-style escapes decoded, so curly quotes and
    apostrophes in catalog keys match the source."""
    decode = lambda text: re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), text)
    return {str(p): decode(p.read_text(encoding="utf-8", errors="ignore")) for p in Path("Wingman").rglob("*.swift")}


def fragments(key):
    """Literal pieces of a catalog key as they appear in Swift source: format
    specifiers become string interpolations there, and long strings may sit
    in a multi-line literal, so split on both."""
    parts = re.split(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f)|%%|\n", key)
    # Short pieces ("correct", "Level") match unrelated code, so skip them.
    return sorted((p.strip() for p in parts if len(p.strip()) >= 10), key=len, reverse=True)


def area_for(key, comment, sources):
    by_name = {name: (name, order, priority) for _, name, order, priority in AREAS}
    for pattern, name in COMMENT_AREAS:
        if comment and re.search(pattern, comment):
            return by_name[name]
    hits = [path for path, text in sources.items() if f'"{key}"' in text]
    for needle in fragments(key) if not hits else []:
        hits = [path for path, text in sources.items() if needle in text]
        if hits:
            break
    # The area most of the hits belong to; ties go to the earlier area.
    votes = {}
    for hit in hits:
        for pattern, name, order, priority in AREAS:
            if re.search(pattern, hit):
                votes[name] = votes.get(name, 0) + 1
                break
    if not votes:
        return OTHER
    best = max(votes, key=lambda name: (votes[name], -by_name[name][1]))
    return by_name[best]


def as_text(value):
    if isinstance(value, dict):
        return "\n".join(f"{form}: {text}" for form, text in value.items())
    return value


def header(ws, columns):
    for col, (title, width) in enumerate(columns, start=1):
        cell = ws.cell(row=1, column=col, value=title)
        cell.font, cell.fill, cell.alignment = HEAD, HEADER, Alignment(vertical="center", wrap_text=True)
        ws.column_dimensions[cell.column_letter].width = width
    ws.freeze_panes = "A2"
    ws.row_dimensions[1].height = 30


def status_list(ws, column, last_row):
    dv = DataValidation(type="list", formula1='"OK,Changed,Question"', allow_blank=True)
    ws.add_data_validation(dv)
    dv.add(f"{column}2:{column}{last_row}")


def style_row(ws, row, yellow_cols, key_col=None, must=False):
    for cell in ws[row]:
        cell.font, cell.alignment = BODY, WRAP
        if must and cell.column <= 3:
            cell.fill = MUST
    for col in yellow_cols:
        ws.cell(row=row, column=col).fill = YELLOW
    if key_col:
        ws.cell(row=row, column=key_col).font = GREY


def read_me(ws, counts):
    ws.column_dimensions["A"].width = 100
    lines = [
        ("Wingman: German review pack", Font(name="Arial", size=16, bold=True)),
        ("", BODY),
        ("Wingman is an iPhone app that coaches men, mostly 25 to 55, who are nervous about talking to women in person: short lessons, quizzes, practice scenarios and a log of real approaches. The tone is a calm, direct older brother: not a pickup artist, not a therapist.", BODY),
        ("All German here is a machine draft written by an AI (Claude). Your job is to proofread and edit it so it reads as if a German native wrote it, not to translate from scratch.", BOLD),
        ("", BODY),
        ("What's in this file", BOLD),
        (f"• Choices to check: {counts['choices']} translation decisions to confirm or change. Start here.", BODY),
        (f"• Interface: {counts['interface']} app strings, sorted by where they appear. Rows marked \"Must read\" (pink) carry money, legal weight or first impressions: paywall, sign-in, onboarding, notifications. Please read every one of those.", BODY),
        (f"• Lesson 1_1 and Lesson 6_1: two sample lessons ({counts['lessons']} paragraphs), read in order as a user would.", BODY),
        (f"• Daily quotes: {counts['quotes']} short quotes shown on the Home screen. Lower priority.", BODY),
        ("", BODY),
        ("How to fill it in", BOLD),
        *[(f"{i}. {rule}", BODY) for i, rule in enumerate(RULES, start=1)],
        ("", BODY),
        ("Example of a filled-in row (Interface sheet)", BOLD),
        ("English: \"Try again\"   German draft: \"Erneut versuchen\"   Your version: \"Nochmal versuchen\"   Status: Changed   Comment: \"Sounds more natural on a button.\"", BODY),
        ("", BODY),
        ("Context columns", BOLD),
        ("\"Where in app\" and \"Context\" say where a line appears. Some strings are short labels whose context isn't obvious; if a line is unclear, set Status to Question and ask in Comment.", BODY),
    ]
    for row, (text, font) in enumerate(lines, start=1):
        cell = ws.cell(row=row, column=1, value=text)
        cell.font, cell.alignment = font, Alignment(wrap_text=True, vertical="top")


def choices_sheet(wb):
    ws = wb.create_sheet("Choices to check")
    header(ws, [("#", 5), ("Topic", 22), ("What the draft does", 60), ("Where", 24), ("Question for you", 40), ("Your answer", 40)])
    for i, (topic, what, where, question) in enumerate(CHOICES, start=1):
        ws.append([i, topic, what, where, question, None])
        style_row(ws, i + 1, yellow_cols=[6])


def interface_sheet(wb, draft, sources):
    catalogs = {name: json.loads(path.read_text(encoding="utf-8"))["strings"] for name, path in CATALOG_FILES.items()}
    rows, quotes = [], []
    for name in ("Localizable", "Content"):
        for key, german in draft[name].items():
            entry = catalogs[name].get(key, {})
            context = entry.get("comment", "")
            limit = LENGTH_LIMITS.get(name, {}).get(key)
            if name == "Content":
                if context.startswith("Daily quote"):
                    quotes.append((key, german))
                    continue
                area = ("Onboarding", 3, "Must read") if context.startswith("Onboarding") else ("Courses, lessons & quiz", 7, "Read")
            else:
                area = area_for(key, context, sources)
            rows.append((area, key, as_text(german), context, limit, f"{name}::{key}"))
    rows.sort(key=lambda r: (r[0][1], r[1].lower()))

    ws = wb.create_sheet("Interface")
    header(ws, [("#", 5), ("Where in app", 20), ("Priority", 10), ("Context", 28), ("English", 45), ("German draft", 45),
                ("Your version", 45), ("Status", 11), ("Comment", 32), ("Max length", 8), ("Key (don't edit)", 18)])
    for i, (area, english, german, context, limit, key) in enumerate(rows, start=1):
        ws.append([i, area[0], area[2], context, english, german, None, None, None, limit, key])
        style_row(ws, i + 1, yellow_cols=[7, 8, 9], key_col=11, must=area[2] == "Must read")
        if limit:
            ws.cell(row=i + 1, column=10).comment = Comment(f"Hard limit: {limit} characters. Longer text is hidden on an iPhone SE.", "Wingman")
    status_list(ws, "H", len(rows) + 1)
    ws.auto_filter.ref = f"A1:K{len(rows) + 1}"
    return len(rows), quotes


def lesson_sheets(wb):
    english = lesson_overlays.english_by_course()
    total = 0
    for course_id, lesson_id in SAMPLE_LESSONS:
        german = json.loads(Path(f"Wingman/Courses/Lesson Overlays/lesson_overlay_{course_id}_de.json").read_text(encoding="utf-8"))
        prefix = lesson_id.replace("lesson_", "content_") + "_"
        keys = [f"{lesson_id}.title", f"{lesson_id}.summary"] + [k for k in english[course_id] if k.startswith(prefix)]
        ws = wb.create_sheet(lesson_id.replace("lesson_", "Lesson "))
        header(ws, [("#", 5), ("Part", 14), ("English", 60), ("German draft", 60), ("Your version", 60), ("Status", 11), ("Comment", 30), ("Key (don't edit)", 18)])
        for i, key in enumerate(keys, start=1):
            if key.endswith(".title"):
                part = "Lesson title"
            elif key.endswith(".summary"):
                part = "Lesson summary"
            else:
                part = f"Page {key[len(prefix):].split('_')[0]}"
            ws.append([i, part, english[course_id][key], german.get(key, ""), None, None, None, key])
            style_row(ws, i + 1, yellow_cols=[5, 6, 7], key_col=8)
        status_list(ws, "F", len(keys) + 1)
        total += len(keys)
    return total


def quotes_sheet(wb, quotes):
    ws = wb.create_sheet("Daily quotes")
    header(ws, [("#", 5), ("English", 60), ("German draft", 60), ("Your version", 60), ("Status", 11), ("Comment", 30), ("Key (don't edit)", 18)])
    for i, (english, german) in enumerate(sorted(quotes), start=1):
        ws.append([i, english, german, None, None, None, f"Content::{english}"])
        style_row(ws, i + 1, yellow_cols=[4, 5, 6], key_col=7)
    status_list(ws, "E", len(quotes) + 1)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    draft = json.loads(DRAFT.read_text(encoding="utf-8"))
    wb = Workbook()
    wb.remove(wb.active)
    counts = {"choices": len(CHOICES)}
    choices_sheet(wb)
    counts["interface"], quotes = interface_sheet(wb, draft, swift_sources())
    counts["lessons"] = lesson_sheets(wb)
    quotes_sheet(wb, quotes)
    counts["quotes"] = len(quotes)
    # Built last because it quotes the counts, but shown first.
    read_me(wb.create_sheet("Read me", 0), counts)
    wb.active = 0
    out.parent.mkdir(parents=True, exist_ok=True)
    wb.save(out)
    print(f"Wrote {out}: {counts['interface']} interface strings, {counts['lessons']} lesson items, {counts['quotes']} quotes, {counts['choices']} choices")


if __name__ == "__main__":
    main()
