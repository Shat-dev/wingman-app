#!/usr/bin/env python3
"""Validate Wingman's String Catalogs.

Run from the repo root before every build that adds or changes translations:

    python3 scripts/check_string_catalogs.py                 # Release A: English only
    python3 scripts/check_string_catalogs.py --languages de  # once German exists

Exits non-zero if anything is wrong. Checks:

  * both catalogs parse and have English as the source language;
  * no language is present that was not asked for (so a language cannot ship
    by accident);
  * every translation keeps exactly the placeholders of its English string
    (%@, %lld, ...), in any order;
  * plural variants always include "other", and each variant keeps the
    placeholders;
  * no translation is empty or whitespace;
  * entries marked do-not-translate have no translation;
  * every translation keeps exactly the link targets of its English string
    ("[Terms](terms)" may become "[AGB](terms)", never "[AGB](agb)");
  * brand terms (Wingman, XP) survive in every translation of a string that
    contains them;
  * Content.xcstrings entries are all marked manual, so Xcode will not remove
    them as stale.

With --languages it also reports how many strings each language still lacks.
A missing translation is not an error: the app falls back to English.
"""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

CATALOGS = {
    "Localizable": Path("Wingman/Resources/Localizable.xcstrings"),
    "Content": Path("Wingman/Resources/Content.xcstrings"),
}
SOURCE_LANGUAGE = "en"
BRAND_TERMS = ["Wingman", "XP"]
NOT_TRANSLATED = "(do-not-translate)"

# printf-style specifiers as Foundation writes them: %@, %lld, %1$@, %2$lld, %d, %f, %%.
SPECIFIER = re.compile(r"%(?:(\d+)\$)?(?:[-+ 0#]*\d*(?:\.\d+)?)(lld|ld|d|@|f|lf|u|llu|s|%)")


def placeholders(text):
    """Multiset of placeholder types in `text`, ignoring position numbers and literal %%."""
    found = Counter()
    for match in SPECIFIER.finditer(text):
        kind = match.group(2)
        if kind != "%":
            found[kind] += 1
    return found


# Markdown link targets: the "terms" in "[Terms](terms)".
LINK_TARGET = re.compile(r"\]\(([^)\s]*)\)")


def link_targets(text):
    """Multiset of Markdown link targets in `text`."""
    return Counter(LINK_TARGET.findall(text))


def string_units(localization):
    """Yield (label, value) for every string a localization can produce."""
    if "stringUnit" in localization:
        yield "", localization["stringUnit"].get("value", "")
    for kind, variants in localization.get("variations", {}).items():
        for name, variant in variants.items():
            for label, value in string_units(variant):
                yield f"{kind}.{name}{('.' + label) if label else ''}", value


def check_catalog(name, path, allowed, errors, missing):
    try:
        catalog = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as problem:
        errors.append(f"{name}: cannot read {path}: {problem}")
        return 0

    if catalog.get("sourceLanguage") != SOURCE_LANGUAGE:
        errors.append(f"{name}: sourceLanguage is {catalog.get('sourceLanguage')!r}, expected {SOURCE_LANGUAGE!r}")

    strings = catalog.get("strings", {})
    for key, entry in strings.items():
        shown = key if len(key) <= 60 else key[:57] + "..."
        where = f"{name}: \"{shown}\""
        localizations = entry.get("localizations", {})
        translate = entry.get("shouldTranslate", True)

        if name == "Content" and entry.get("extractionState") != "manual":
            errors.append(f"{where}: Content entries must have extractionState \"manual\"")

        for language in localizations:
            if language != SOURCE_LANGUAGE and language not in allowed:
                errors.append(f"{where}: has a {language!r} translation, which is not an allowed language")

        if not translate:
            extra = [language for language in localizations if language != SOURCE_LANGUAGE]
            if extra:
                errors.append(f"{where}: marked do-not-translate but translated into {', '.join(extra)}")
            missing[NOT_TRANSLATED] += 1
            continue

        expected = placeholders(key)
        expected_links = link_targets(key)
        for language, localization in localizations.items():
            plural = localization.get("variations", {}).get("plural")
            if plural is not None and "other" not in plural:
                errors.append(f"{where} [{language}]: plural variants have no \"other\" form")

            for label, value in string_units(localization):
                tag = f"{where} [{language}{(' ' + label) if label else ''}]"
                if not value.strip():
                    errors.append(f"{tag}: empty translation")
                    continue
                if placeholders(value) != expected:
                    errors.append(
                        f"{tag}: placeholders {dict(placeholders(value))} do not match the English {dict(expected)}"
                    )
                if link_targets(value) != expected_links:
                    errors.append(
                        f"{tag}: link targets {sorted(link_targets(value).elements())} do not match "
                        f"the English {sorted(expected_links.elements())}"
                    )
                if language != SOURCE_LANGUAGE:
                    for term in BRAND_TERMS:
                        if re.search(rf"\b{re.escape(term)}\b", key) and not re.search(rf"\b{re.escape(term)}\b", value):
                            errors.append(f"{tag}: brand term \"{term}\" is missing from the translation")

        for language in allowed:
            if language not in localizations:
                missing[language] += 1

    return len(strings)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--languages",
        default="",
        help="comma-separated languages that are allowed to have translations (default: none, English only)",
    )
    arguments = parser.parse_args()
    allowed = [language.strip() for language in arguments.languages.split(",") if language.strip()]

    errors = []
    for name, path in CATALOGS.items():
        missing = Counter()
        count = check_catalog(name, path, allowed, errors, missing)
        fixed = missing[NOT_TRANSLATED]
        print(f"{name}: {count} strings" + (f" ({fixed} marked do-not-translate)" if fixed else ""))
        for language in allowed:
            translated = count - fixed - missing[language]
            print(f"  {language}: {translated} translated, {missing[language]} fall back to English")

    if errors:
        print(f"\n{len(errors)} problem(s):")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("\nOK: no problems found." + ("" if allowed else " English only, as Release A requires."))
    return 0


if __name__ == "__main__":
    sys.exit(main())
