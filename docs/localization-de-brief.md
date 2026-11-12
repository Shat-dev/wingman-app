# German: translator and reviewer brief (Release B, G1)

The app's interface strings (both String Catalogs, 574 strings) have a first German draft. It was machine-written (Claude), not by a native speaker. Every string is marked **needs review** in Xcode. This brief is for whoever reviews that draft and translates the rest.

Source of truth for the draft: [`localization/de/catalogs.de.json`](../localization/de/catalogs.de.json) (English key → German). After editing it, re-import and validate:

```bash
python3 scripts/import_catalog_translations.py de localization/de/catalogs.de.json
```

```bash
python3 scripts/check_string_catalogs.py --languages de --strict-lengths
```

Once a reviewer has signed a batch off, re-import with `--reviewed` to mark it "translated".

## Who reads this

Men, mostly 25–55 (45+ is about a third of onboarding answers), who are nervous about talking to women in person. The tone is a calm, direct older brother: not a pickup-artist, not a therapist. No slang that will date, no Denglisch where a normal German word exists. Some loanwords are the normal German usage and stay: *Smalltalk*, *Opener*, *Date*, *Feedback*, *Level*, *Mindset*, *Lifestyle*.

**Adapt, don't translate word for word.** If an American phrase or image does not land in German, replace it with one that does. For example, the baseball quote "If you don't swing you'll never hit a home run" became a football line: "Wer nicht schießt, kann kein Tor schießen." Well-known quotes use their established German version where one exists (the Japanese proverb "Fall siebenmal hin und steh achtmal auf"; Laozi: "Auch eine Reise von tausend Meilen beginnt mit einem Schritt").

## Fixed choices

| Topic | Rule |
|---|---|
| Address | **du**, everywhere, including errors and the paywall. Imperatives in the short form: *versuch*, *wähl*, *prüf*. |
| Never translate | **Wingman**, **XP** (the validator checks both). |
| Category names | Translated since 2026-11-13 (they were English-only before): *Mindset & Grundlagen*, *Ansprechen in der Praxis*, *Gesprächsfluss*, *Flirten & Anziehung*, *Alltag & Meisterschaft*. In `Content.xcstrings`; analytics keeps the English names. |
| Level | **Level** for both the XP level and the four approach levels (one Swift string, "Level %lld", serves both). |
| Approach (noun) | **das Ansprechen** for the act; **Ansprache** for one logged approach; *erfassen* for "to log". |
| Subscription | **Abo** in the UI (*Monatsabo*, *Jahresabo*, *Abo verwalten*). |
| Free trial | **gratis** on the badge (*3 Tage gratis*), **Testzeitraum** in sentences. |
| Terms / Privacy | Footer links: **AGB** / **Datenschutz**. Full names: **Nutzungsbedingungen** / **Datenschutzerklärung**. The pages themselves stay English (decision D6). |
| Numbers | Space between a number and %: `45 %` (a no-break space in `%lld %%`). En dash in ranges: `18–24`. Write "45 % aller …", never "45 % der …": `% d` reads as a format specifier and the validator rejects it. |
| Quotation marks | „…“ |
| Ellipsis | "Wird geladen …" (space, then the single character …) |

## Hard limits

- **Paywall ticks: 36 characters at most.** A longer tick wraps on an iPhone SE and pushes the last tick out of sight under the plan cards. The validator enforces this with `--strict-lengths`.
- **Placeholders must survive exactly.** `%@`, `%lld`, and the positional forms `%1$@`, `%2$lld` may move within the sentence but not change type or count.
- **Link targets stay as they are.** In "[AGB](terms)" the word in brackets is translated, `(terms)` never is.
- **Plurals:** German needs only *one* and *other*.

## Look at these first

These carry money, law or first impressions. A native speaker should read every one.

1. **Paywall and one-time offer**: the "Heute werden %1$@ … berechnet, danach …" sentences, "Sofortige Abrechnung …", "Jetzt keine Zahlung …", "nur %@ pro Woche", "Für %@ testen", the ticks, and "EINMALIGES ANGEBOT".
2. **Sign-in legal line**: "Indem du fortfährst, stimmst du unseren [AGB](terms) und der [Datenschutzerklärung](privacy) zu".
3. **Onboarding**: the questions, answer options, the four statistic screens, the commitment pledge ("Ich, %@, werde zu einem Mann, der handelt.") and the growth chart labels.
4. **Notifications**: "Zeit für deine tägliche Lektüre! …" and the tips-and-offers permission text.
5. **Course titles**. Several were guesses without the lesson text in front of the translator: *Die Annäherung* (The Physical Approach, changed from *Der körperliche Ansatz*), *Das Pflichtprogramm* (Non-negotiables, changed from *Nicht verhandelbar*), *Der Abschluss* (Closing), *Bereit zum Ansprechen* (Approach Readiness). Check each against its lessons.

## Known open points in the draft

- The Nora Ephron quote "be the heroine of your life" was changed to *der Held deines Lebens*, since the readers are men. Keep or restore.
- "Good Morning," → *Guten Morgen,* is shown at any time of day, as in English.
- "Stammkundin im Fitnessstudio" and "Mitreisende im Zug" assume the other person is a woman, as the English examples imply.

## Still to translate (not in this draft)

| Part | Size | Where |
|---|---|---|
| Lesson overlays (G3) | ~36,800 words, 25 files | `scripts/lesson_overlays.py` exports and checks them |
| Database content (G4) | ~42,300 words: 765 quiz questions, 15 scenarios | Translation tables; the migration is written but **not applied** |
| App Store listing and subscription display names (G9) | | App Store Connect |
| Auth email templates (G10) | | Supabase dashboard |

Until G3 and G4 are done, a German build shows a German interface with English lessons, quizzes and scenarios. Do not ship it in that state (plan risk table: "Mixed-language experience").
