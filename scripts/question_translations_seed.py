#!/usr/bin/env python3
"""Write the quiz-question translations that ship inside the app.

    python3 scripts/question_translations_seed.py de
        Reads every localization/de/db/questions_*.json and writes
        Wingman/Content/question_translations_seed.de.json.

    python3 scripts/question_translations_seed.py de --check
        Writes nothing. Exits non-zero if the bundled file differs from what
        the JSON would produce, i.e. the app and the database SQL have drifted.

Why it exists: lesson quizzes read translations from an on-device cache that
is filled by a background download once a guest or account session exists.
On a fresh install that download races the first quiz, and a quiz opened
before it finishes stays English. The bundled copy means a translated app
has its quiz questions from the first launch, even offline; the download
then only brings in edits made in the database since this build.

The same JSON files produce the SQL in supabase/seed/content_translations_<lang>/
(scripts/db_translations_sql.py, which also runs this script), so the bundled
rows and the database rows come from one source.

The output matches QuestionTranslation's Codable shape: question_id,
question_text, options, explanation. One row per line, sorted by id, so a
diff shows exactly which questions changed.
"""

import json
import sys
from pathlib import Path


def rows_for(locale):
    rows = {}
    for path in sorted(Path(f"localization/{locale}/db").glob("questions_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for qid, fields in data.get("questions", {}).items():
            explanation = fields.get("explanation")
            rows[qid] = {
                "question_id": qid,
                "question_text": fields["question_text"][locale],
                "options": fields["options"][locale],
                "explanation": explanation[locale] if explanation else None,
            }
    return [rows[k] for k in sorted(rows)]


def render(rows):
    lines = [json.dumps(r, ensure_ascii=False, sort_keys=True) for r in rows]
    return "[\n" + ",\n".join(lines) + "\n]\n"


def target(locale):
    return Path(f"Wingman/Content/question_translations_seed.{locale}.json")


def main(argv):
    if len(argv) not in (2, 3) or (len(argv) == 3 and argv[2] != "--check"):
        print(__doc__)
        return 2
    locale = argv[1]
    rows = rows_for(locale)
    if not rows:
        print(f"No question translations found under localization/{locale}/db/")
        return 1
    text = render(rows)
    path = target(locale)

    if len(argv) == 3:
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current != text:
            print(f"DRIFT: {path} does not match localization/{locale}/db/. "
                  f"Run: python3 scripts/question_translations_seed.py {locale}")
            return 1
        print(f"OK: {path} matches ({len(rows)} questions)")
        return 0

    path.write_text(text, encoding="utf-8")
    print(f"{path}: {len(rows)} questions")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
