#!/usr/bin/env python3
"""Write a language's translations into Wingman's String Catalogs.

    python3 scripts/import_catalog_translations.py de localization/de/catalogs.de.json

The JSON file has one object per catalog ("Localizable", "Content"), each
mapping the English key to its translation. A translation is a string, or for
a plural entry an object of plural forms ({"one": ..., "other": ...}).

Every imported string is marked "needs_review" so Xcode shows it as unchecked
until a native speaker has signed it off. Pass --reviewed to mark them
"translated" instead. Keys that are not in the catalog, or are marked
do-not-translate, are reported and skipped. Existing translations for the
language are replaced. Run scripts/check_string_catalogs.py afterwards.
"""

import argparse
import json
import re
import sys
from pathlib import Path

CATALOGS = {
    "Localizable": Path("Wingman/Resources/Localizable.xcstrings"),
    "Content": Path("Wingman/Resources/Content.xcstrings"),
}


def xcode_json(catalog):
    """Serialise the way Xcode does, so an untouched entry produces no diff:
    two-space indent, " : " separators, sorted keys, an empty object written
    over two lines, no newline at the end of the file."""
    text = json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))
    return re.sub(r"^( *)(.*) : \{\}", lambda m: f"{m.group(1)}{m.group(2)} : {{\n\n{m.group(1)}}}", text, flags=re.M)


def unit(value, state):
    return {"stringUnit": {"state": state, "value": value}}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("language")
    parser.add_argument("translations", type=Path)
    parser.add_argument("--reviewed", action="store_true", help='mark strings "translated" instead of "needs_review"')
    args = parser.parse_args()
    state = "translated" if args.reviewed else "needs_review"

    source = json.loads(args.translations.read_text(encoding="utf-8"))
    problems = 0
    for name, path in CATALOGS.items():
        translations = source.get(name, {})
        catalog = json.loads(path.read_text(encoding="utf-8"))
        strings = catalog["strings"]
        written = 0
        for key, value in translations.items():
            entry = strings.get(key)
            if entry is None:
                print(f"{name}: not in the catalog, skipped: {key!r}", file=sys.stderr)
                problems += 1
                continue
            if entry.get("shouldTranslate", True) is False:
                print(f"{name}: do-not-translate, skipped: {key!r}", file=sys.stderr)
                problems += 1
                continue
            if isinstance(value, dict):
                localization = {"variations": {"plural": {form: unit(text, state) for form, text in value.items()}}}
            else:
                localization = unit(value, state)
            entry.setdefault("localizations", {})[args.language] = localization
            written += 1
        # Xcode's own formatting: two-space indent, " : " separators, keys sorted.
        path.write_text(xcode_json(catalog), encoding="utf-8")
        print(f"{name}: {written} {args.language} strings written ({state})")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
