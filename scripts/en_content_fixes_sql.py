#!/usr/bin/env python3
"""Turn an English content-fix list into guarded SQL updates (never runs them).

    python3 scripts/en_content_fixes_sql.py supabase/seed/content_fixes_en/2026-11-11_content_fixes.json

Writes the .sql next to the .json. The JSON lists, per id, [old, new] text for
scenario screens, screen options, and question fields/options. Each update only
applies when the row still holds the exact old text, so it is safe to run twice
and leaves rows someone has since edited alone. Answer indexes are never touched.
"""
import json
import sys
from pathlib import Path


def lit(text):
    return "'" + text.replace("'", "''") + "'"


def main(path):
    path = Path(path)
    fixes = json.loads(path.read_text(encoding="utf-8"))
    out = [
        f"-- English content fixes. Generated from {path.name} by scripts/en_content_fixes_sql.py.",
        "-- NOT RUN. Each update applies only if the row still has the exact old text, so it is safe to run twice",
        "-- and does nothing to a row someone has already edited. Run on a branch first. Answer indexes are unchanged.",
        "begin;",
    ]
    for row_id, (old, new) in fixes.get("screens", {}).items():
        out.append(f"update public.scenario_screens set text = {lit(new)} where id = {lit(row_id)} and text = {lit(old)};")
    for row_id, (old, new) in fixes.get("options", {}).items():
        out.append(f"update public.screen_options set text = {lit(new)} where id = {lit(row_id)} and text = {lit(old)};")
    for row_id, fields in fixes.get("questions", {}).items():
        for column in ("question_text", "explanation"):
            if column in fields:
                old, new = fields[column]
                out.append(f"update public.questions set {column} = {lit(new)} where id = {lit(row_id)} and {column} = {lit(old)};")
        for index, (old, new) in fields.get("options", {}).items():
            out.append(
                f"update public.questions set options = jsonb_set(options, '{{{index}}}', to_jsonb({lit(new)}::text)) "
                f"where id = {lit(row_id)} and options->>{index} = {lit(old)};"
            )
    out.append("commit;")
    path.with_suffix(".sql").write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"{path.with_suffix('.sql')}: {len(out) - 5} updates")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
