# French: translator and reviewer brief (Release C)

One French: `fr`, written in **metropolitan French** (France as the reference). Canada, Belgium and Switzerland run the same `fr`; there is no `fr-CA`. A second French would make those phones look for `fr-ca` lessons and rows and fall back to English (see `L10n.contentLanguage`).

Everything in French is a machine draft (Claude), marked **needs review**. This brief is for the session that translates the lessons and database content, and for the native reviewer. It is modelled on the German brief ([localization-de-brief.md](localization-de-brief.md)); German's log ([localization-de-progress.md](localization-de-progress.md)) shows how the hard terms were handled.

Interface draft: [`localization/fr/catalogs.fr.json`](../localization/fr/catalogs.fr.json) (English key → French). After editing it, re-import and validate:

```bash
python3 scripts/import_catalog_translations.py fr localization/fr/catalogs.fr.json
```

```bash
python3 scripts/check_string_catalogs.py --languages de,es,fr --strict-lengths
```

Once a reviewer has signed a batch off, re-import with `--reviewed` to mark it "translated". Never do that for a machine draft.

## Who reads this

Men, mostly 25–55 (45+ is about a third of onboarding answers), who are nervous about talking to women in person. The tone is a calm, direct older brother: not a pickup artist (*pas un coach en séduction de YouTube*), not a therapist. Plain, warm, a little dry. No slang that dates (*de ouf*, *trop stylé*), no *verlan*, no anglicism where a normal French word exists. Loanwords that are normal French usage stay: *Wingman*, *XP*, *app*, *quiz*, *feedback* only where it reads better than *retour*.

**Adapt, don't translate word for word.** If an American phrase or image doesn't land in French, replace it with one that does:

- Baseball → football or rugby. "If you don't swing you'll never hit a home run" → *Si tu ne tires pas, tu ne marques pas.*
- US places → French ones: Portland → Lyon, Bordeaux or Nantes; "the brewery up 3rd street" → *la brasserie au coin de la rue*.
- Imperial units → metric: 18 inches → *45 cm*; three feet → *un mètre*; four feet → *un peu plus d'un mètre*.
- Well-known quotes use their established French version (Japanese proverb: *Tombe sept fois, relève-toi huit*; Laozi: *Un voyage de mille lieues commence par un premier pas*; Gretzky: rewrite rather than keep "100 %", see Numbers).
- Shops: French supermarkets are mostly closed on Sunday afternoons, so a Sunday-morning grocery scene is fine, a Sunday-evening one isn't.

## Fixed choices

| Topic | Rule |
|---|---|
| Address | **tu**, everywhere, including errors, notifications and the paywall. Imperatives: *choisis*, *essaie*, *touche*, *continue*, *réessaie*. Never *vous* for the reader (a plural *vous* about two people in a scene is fine). |
| Register | Metropolitan French. **No Québec-only terms**: *portable* / *téléphone* (not *cellulaire*), *faire les magasins* (not *magasiner*), *voiture* (not *char*), *copine* (not *blonde*), *e-mail* (not *courriel*, which France understands but rarely uses in apps). No *écriture inclusive* (no point médian). |
| Never translate | **Wingman**, **XP** (the validator checks both). |
| Category names | Translated, as German does (`Content.xcstrings`; analytics keeps the English): *État d'esprit et bases*, *L'approche en pratique*, *Fluidité de la conversation*, *Séduction et alchimie*, *Au quotidien et maîtrise*. |
| Level | **Niveau** for both the XP level and the four approach levels (one Swift string, "Level %lld", serves both): *Niveau %lld*. |
| Approach (noun) | verb **aborder** (*aborder une femme*, the normal French phrase); noun **une approche** for the act and for one logged approach; *noter* for "to log". "Log Approach" → *Noter une approche*. Not *abordage* (sounds like pirates). |
| Opener | **phrase d'accroche** (short: *accroche*). |
| Subscription | **abonnement** (*mensuel*, *annuel*, *Gérer l'abonnement*, plural *Gérer les abonnements*). |
| Free trial | **gratuit(s)** on a badge (*3 jours gratuits*), **essai gratuit** in sentences. (Wingman has no free trial today, but the strings exist.) |
| Terms / Privacy | Footer links: **CGU** / **Confidentialité**. Full names: **Conditions d'utilisation** / **Politique de confidentialité**. The pages themselves stay English for now (decision D6). |
| iOS settings | **Réglages** ("App Store settings" → *les réglages de l'App Store*), as French iOS says. |
| Numbers | **`45 %`** with a **narrow no-break space** (U+202F) between number and sign; in format strings `%lld %%` with U+202F. Thousands also take U+202F (*1 000*). Ranges: *de 18 à 24 ans* in sentences, `18–24` (en dash) in labels. See the validator workaround below. |
| Punctuation | **Narrow no-break space (U+202F) before `;` `:` `!` `?`** and **inside « »**: `« Salut »`, `Prêt ?`, `Attention :`. Never a normal space there (it lets the sign wrap onto its own line). Ellipsis: the single character **…** with no space before it: *Chargement…* |
| Capitals | Sentence case for titles and buttons (*Noter une approche*). Days and months in lower case. Accents on capitals: *État*, *À propos*. |
| Plurals | **0 and 1 are both singular**: *0 leçon*, *1 leçon*, *2 leçons*. iOS puts 0 in the *one* form for French, so the *one* form must read right for 0 too (*%lld leçon terminée* works for 0 and 1). Fill **one**, **other**, and **many** if Xcode or the validator asks (CLDR's *many* is for exact millions; Wingman never shows one). |
| Women | **femme** by default; *fille* is fine in casual dialogue where an English speaker would say "girl" about an adult. |
| Gender agreement | The reader is a man (*Tu es prêt*, *Content de te revoir*). Women in examples are female (*une habituée de la salle*, *ta voisine de train*), as the English implies. |

## Validator workaround: `% d`, `% s`, `% u`

`scripts/check_string_catalogs.py` reads `%` + optional flags (a space is a flag) + `d`, `s`, `u`, `f`, `@`, `ld`, `lld`, `lf` or `llu` as a placeholder. A narrow no-break space is not a flag, but it sits *before* the sign; what counts is what comes *after*. So in a string with **no** placeholders, these all fail as "placeholder added": `45 % des hommes`, `77 % sont`, `10 % sur`, `100 % du temps`. German dodged it with *45 % aller* instead of *45 % der*. French options, in order of preference:

1. **Reorder so the percent is followed by a safe word:** *Parmi les hommes de 18 à 24 ans, 45 % n'ont jamais abordé une femme* (`% n` passes), *77 % veulent…*, *63 % regrettent…*, *45 % les…* all pass. Safe next letters: anything except **d, s, u, f, @**, and **l** only when followed by d, f or l. Checked against the regex on 2026-11-15.
2. **Say it in words:** *Près d'un homme sur deux…*, *45 hommes sur 100…*. Natural in French and often the better line.
3. Quotes: *Tous les tirs que tu ne tentes pas sont ratés d'avance* instead of *100 % des tirs*.

Never put an invisible character after the `%` to fool the check: the reviewer can't see it and a later edit breaks it.

In strings that do have placeholders (`%lld %%`), `%%` is the literal sign and is safe before *de*: `Profite de %lld %% de réduction` passes.

## Hard limits

- **Paywall ticks: 36 characters at most.** A longer tick wraps on an iPhone SE and pushes the last tick under the plan cards. Rewrite, don't truncate; French runs ~15–20 % longer than English, so most ticks need rewriting. The validator enforces it with `--strict-lengths`.
- **Placeholders must survive exactly.** `%@`, `%lld`, and the positional forms `%1$@`, `%2$lld` may move within the sentence but not change type or count. Use positional forms when you reorder.
- **Link targets stay as they are.** In "[CGU](terms)" the word in brackets is translated, `(terms)` never is.
- **Prices come from the App Store** as one formatted string (`%@`): `29,99 €`, `CHF 12.00`, `12,99 $ CA`. Never write a currency word or symbol around a price placeholder, and never make a word agree with it: *Aujourd'hui, tu paies %1$@*, not *%1$@ facturés aujourd'hui*.

## Glossary for lessons and database content

Keep these consistent across all 25 courses, the quiz and the scenarios. First use of a technical term may add the English in parentheses, as German did, then never again.

| English | French | Notes |
|---|---|---|
| approach (act / one approach) | **aborder** / **une approche** | *l'aborder*, *ta première approche* |
| opener | **phrase d'accroche**, *accroche* | example openers rewritten as natural spoken French |
| close / closing | **concrétiser** | ask for the number or the next step (*concrétiser par un rendez-vous*). Course 15 title "Closing" → *Concrétiser*. **Never *conclure***: in French dating talk it means sleeping together. "Assumed close" → *proposer la suite comme une évidence*. |
| calibration / calibrated | **lire la situation**, *s'ajuster*; *calibrer* when the lesson is about the skill itself | German used *Kalibrieren* in 17_4 and *Gespür* in 25; choose per context and log it |
| outcome independence | **ne pas dépendre du résultat** | consistent in courses 4 and 17 and the quiz |
| social proof | **preuve sociale** | established term |
| frame / frame control | **posture**; **donner le ton** | |
| rep / reps / volume | **tentative(s)**, **beaucoup d'approches** | *répétitions* only in a gym metaphor |
| banter | **échanges taquins**, *répartie* | |
| teasing / cheeky | **taquiner** / **culotté**, *taquin* | |
| flirting / flirty | **flirter**, *le flirt* / **charmeur** | *draguer* for "to pick up"; it's common but a little crude, keep it for the reader's own words |
| small talk | **conversation légère**, *papoter* | not *small talk* |
| momentum | **élan**, *garder l'élan* | |
| threading / threads | **fils**, *rebondir sur un fil* | |
| validating | **reconnaître**, *valider* sparingly | |
| attunement | **être à l'écoute**, *être en phase* | |
| sticking point | **point de blocage** | |
| growth / fixed mindset | **état d'esprit de développement / état d'esprit fixe** | established terms (Dweck in French) |
| confidence | **confiance en soi**, *assurance* | |
| date | **rendez-vous** (*rencard* in casual dialogue only) | not *date* |
| streak | **série** | |
| daily practice | **entraînement du jour** | |
| scenario | **scénario** (*mise en situation* where it reads better) | |
| quiz | **quiz** | |
| log (the journal) | **journal** | |
| sexual tension | **tension** (*tension sexuelle* where the English is explicit) | |
| disqualification (21_1) | rewrite by meaning, as German did (*ne pas être impressionné d'emblée*) | PUA term with no neutral French |
| consent wording (17_3) | as strict as the English: *Ne la touche jamais sans signes clairs qu'elle est à l'aise, et arrête immédiatement si elle se recule.* | do not soften |

## Look at these first

These carry money, law or first impressions. A native speaker should read every one.

1. **Paywall and one-time offer**: the "*Aujourd'hui, tu paies %1$@ … puis %2$@ par mois*" sentences, "*Prélevé immédiatement…*", "*Rien à payer maintenant…*", "*seulement %@ par semaine*", the ticks, and "*OFFRE UNIQUE*". Read them with the prices above. French consumer law expects price and renewal terms to be clear in French; flag anything ambiguous.
2. **Sign-in legal line**: "*En continuant, tu acceptes nos [CGU](terms) et notre [Politique de confidentialité](privacy)*".
3. **Onboarding**: the questions, answers, the four statistic screens (see the validator workaround), the commitment pledge ("*Moi, %@, je deviens un homme qui passe à l'action.*") and the growth chart labels.
4. **Notifications**: the daily reading reminder and the tips-and-offers permission text.
5. **Course titles**: translated in the catalog before the lessons were read; the lesson session may suggest better ones (logged, not edited).

## Open points

- *CGU* is the usual French footer abbreviation; a reviewer may prefer the full *Conditions* on such a short line.
- *Scénarios* vs *Mises en situation* for the Scenarios tab. Draft uses *Scénarios*.
- The Nora Ephron quote "be the heroine of your life": German made it *der Held deines Lebens* since the readers are men. French draft: *sois le héros de ta vie*. Keep or restore.
- Course titles marked uncertain in the setup log (Phase 2).
- Canada: the same `fr` shows there. Nothing in the draft should read as France-only slang; *Réglages* matches iOS in both.

## Still to translate (not in the catalog draft)

| Part | Size | Who |
|---|---|---|
| Lesson overlays | ~34,400 English words, 25 files | French session: `python3 scripts/lesson_overlays.py export fr <folder>` / `check fr` |
| Database content | 765 quiz questions, 15 scenarios (796 text screens, 276 options) | French session: `localization/fr/db/*.json` → `python3 scripts/db_translations_sql.py fr` (never run the SQL) |
| Review pack | | `python3 scripts/review_pack.py fr` (choices in `localization/fr/review/choices.json`) |
| App Store listing, subscription display names | | French session drafts `docs/french-app-store-listing.md`; Arthur enters it in App Store Connect |

Until those are done, a French build shows a French interface with English lessons, quizzes and scenarios. Don't ship it in that state.
