# Spanish: translator and reviewer brief (Release C)

One Spanish for every Spanish-speaking market: `es`, written in **neutral Latin American Spanish** that a Spaniard also reads naturally. There is no `es-419`, `es-MX` or `es-ES`: with only `es`, every Spanish phone (Mexico, Colombia, Argentina, the US, Spain…) runs `es` and finds its lessons, quiz and scenario rows. A second Spanish would make those phones fall back to English (see `L10n.contentLanguage`).

Everything in Spanish is a machine draft (Claude), marked **needs review**. This brief is for the session that translates the lessons and database content, and for the native reviewer. It is modelled on the German brief ([localization-de-brief.md](localization-de-brief.md)); German's log ([localization-de-progress.md](localization-de-progress.md)) shows how the hard terms were handled.

Interface draft: [`localization/es/catalogs.es.json`](../localization/es/catalogs.es.json) (English key → Spanish). After editing it, re-import and validate:

```bash
python3 scripts/import_catalog_translations.py es localization/es/catalogs.es.json
```

```bash
python3 scripts/check_string_catalogs.py --languages de,es,fr --strict-lengths
```

Once a reviewer has signed a batch off, re-import with `--reviewed` to mark it "translated". Never do that for a machine draft.

## Who reads this

Men, mostly 25–55 (45+ is about a third of onboarding answers), who are nervous about talking to women in person. The tone is a calm, direct older brother: not a pickup artist, not a therapist, not a motivational poster. Plain, warm, a little dry. No slang that dates or belongs to one country, no anglicism where a normal Spanish word exists. Loanwords that are normal Spanish usage stay: *Wingman*, *XP*, *app*, *feedback* only where it really reads better than *comentarios*.

**Adapt, don't translate word for word.** If an American phrase or image doesn't land in Spanish, replace it with one that does:

- Baseball → football. "If you don't swing you'll never hit a home run" → *El que no patea al arco, no mete gol* (or another football line that sounds said, not written).
- US places → a Latin American or Spanish one: Portland → Guadalajara, Medellín or Valencia; "the brewery up 3rd street" → *la cervecería de la esquina*.
- Imperial units → metric: 18 inches → *45 cm*; three feet → *un metro*; four feet → *poco más de un metro*.
- Well-known quotes use their established Spanish version (Japanese proverb: *Cáete siete veces, levántate ocho*; Laozi: *Un viaje de mil millas comienza con un solo paso*; Gretzky: rewrite rather than keep "100 %", see Numbers).
- Weekday habits are fine as in English (Mexican supermarkets open on Sundays, unlike German ones).

## Fixed choices

| Topic | Rule |
|---|---|
| Address | **tú**, everywhere, including errors, notifications and the paywall. Plural **ustedes**, never *vosotros* (no *-áis*, *-éis*, no *os* as an object pronoun). Never *vos* (no *tenés*, *querés*). Short imperatives: *elige*, *prueba*, *toca*, *sigue*, *intenta de nuevo*. |
| Regional words | Neutral Latin American: *celular* (not *móvil*), *computadora* (not *ordenador*), *manejar* (not *conducir* where both work, use *ir en carro / en auto* sparingly), *carro/auto* (not *coche*), *jugo* (not *zumo*), *departamento* (not *piso*). **Avoid:** *coger* (vulgar in much of Latin America: use *tomar*, *agarrar*), *vale* (use *está bien*, *de acuerdo*, *listo*), *guay*, *chévere*, *padre*, *chido*, *bacán*, *chamba*, *pana*, *tío* (as "guy"). *Ligar* is fine and understood everywhere. |
| Never translate | **Wingman**, **XP** (the validator checks both). |
| Category names | Translated, as German does (`Content.xcstrings`; analytics keeps the English): *Mentalidad y bases*, *Acercarse en la práctica*, *Fluidez en la conversación*, *Coqueteo y química*, *Día a día y maestría*. |
| Level | **Nivel** for both the XP level and the four approach levels (one Swift string, "Level %lld", serves both): *Nivel %lld*. |
| Approach (noun) | **acercamiento** for the act and for one logged approach; verb **acercarte (a ella)**; *registrar* for "to log". "Log Approach" → *Registrar acercamiento*. Not *abordaje* (reads as pickup jargon or boarding a ship). |
| Opener | **frase de apertura** (short: *apertura*). Not *opener*. |
| Subscription | **suscripción** (*mensual*, *anual*, *Gestionar suscripción*, plural *Gestionar suscripciones*). |
| Free trial | **gratis** on a badge (*3 días gratis*), **prueba gratuita** in sentences. (Wingman has no free trial today, but the strings exist.) |
| Terms / Privacy | Footer links: **Términos** / **Privacidad**. Full names: **Términos de uso** / **Política de privacidad**. The pages themselves stay English for now (decision D6). |
| iOS settings | **Configuración** ("App Store settings" → *la configuración del App Store*). That is the Latin American iOS word; Spain's iOS says *Ajustes*, and Spaniards still understand it. |
| Numbers | **`45 %`** with a no-break space (U+00A0) between number and sign, the RAE/ASALE norm; in format strings `%lld %%` (no-break space). Decimal comma is not needed (whole numbers only). Ranges: *de 18 a 24 años* in sentences, `18–24` (en dash) in labels. See the validator workaround below. |
| Punctuation | Opening **¿** and **¡** always, also inside a sentence (*Si te mira, ¿qué haces?*). Quotation marks: curly **“…”** (common in Latin American print and screens; «…» is not wrong but reads Spanish-from-Spain on a phone). Ellipsis: the single character **…** with no space before it: *Cargando…* |
| Capitals | Sentence case for titles and buttons (*Registrar acercamiento*, not *Registrar Acercamiento*). Days and months in lower case. |
| Plurals | Fill **one** and **other**. Add **many** only if Xcode or the validator asks for it (CLDR gives Spanish a *many* form for exact millions; Wingman never shows one). |
| Women | **mujer** by default; *chica* is fine in casual dialogue lines where an English speaker would say "girl" about an adult. Never *niña*. |
| Gender agreement | The reader is a man (*Estás listo*, *Bienvenido*). Women in examples are female (*una clienta habitual del gimnasio*, *la compañera de viaje*), as the English implies. |

## Validator workaround: `% d`, `% s`, `% u`

`scripts/check_string_catalogs.py` reads `%` + optional flags (a space is a flag) + `d`, `s`, `u`, `f`, `@` or `l…` as a placeholder. So in a string with **no** placeholders, a literal percent sign followed by a space and one of those letters fails as "placeholder added": `45 % de los hombres`, `45% de`, `el 77 % son`, `100 % una`. German dodged this with *45 % aller* instead of *45 % der*. Spanish options, in order of preference:

1. **Reorder so the percent is followed by a safe word:** *De los hombres de 18 a 24 años, el 45 % nunca se ha acercado a una mujer* (`% n` passes). *El 77 % quiere…* passes; *el 63 % se arrepiente…* fails, because *se* starts with **s**. Safe next letters: anything except **d, s, u, f, @**, and **l** only when followed by d, f or l. Checked against the regex on 2026-11-15.
2. **Say it in words:** *45 de cada 100 hombres de 18 a 24 años nunca se han acercado a una mujer*, *Casi la mitad de los hombres…*. Natural in Spanish and often the better line.
3. Quotes: *Fallas todos los tiros que no intentas* instead of *el 100 % de los tiros*.

Never put a no-break or zero-width space after the `%` to fool the check: the reviewer can't see it and a later edit breaks it.

In strings that do have placeholders (`%lld %%`), `%%` is the literal sign and is safe before *de*: `Obtén %lld %% de descuento` passes.

## Hard limits

- **Paywall ticks: 36 characters at most.** A longer tick wraps on an iPhone SE and pushes the last tick under the plan cards. Rewrite, don't truncate. The validator enforces it with `--strict-lengths`.
- **Placeholders must survive exactly.** `%@`, `%lld`, and the positional forms `%1$@`, `%2$lld` may move within the sentence but not change type or count. Use positional forms when you reorder.
- **Link targets stay as they are.** In "[Términos](terms)" the word in brackets is translated, `(terms)` never is.
- **Prices come from the App Store** as one formatted string (`%@`): `MX$199.00`, `COP 39.900`, `ARS 4.999`, `CLP 3.990`, `29,99 €`, `CA$12.99`, `CHF 12.00`. Never write a currency word or symbol around a price placeholder, and never make a verb agree with it: *Hoy pagas %1$@*, not *Hoy se te cobran %1$@*.

## Glossary for lessons and database content

Keep these consistent across all 25 courses, the quiz and the scenarios. First use of a technical term may add the English in parentheses, as German did, then never again.

| English | Spanish | Notes |
|---|---|---|
| approach (act / one approach) | **acercarte** / **un acercamiento** | *acercarte a ella*, *tu primer acercamiento*. Not *abordaje*. |
| opener | **frase de apertura**, *apertura* | example openers are rewritten as natural spoken Spanish, not translated |
| close / closing | **concretar** | *concretar*: ask for the number or the next step (*concretar una cita*). Course 15 title "Closing" → *Concretar*. Not *cerrar* alone (sounds like ending the talk). "Assumed close" → *dar por hecho el siguiente paso*. |
| calibration / calibrated | **leer la situación**, *ajustar(te)*; *calibrar* when the lesson is about the skill itself | German used *Kalibrieren* in 17_4 and *Gespür* in 25; choose per context and log it |
| outcome independence | **no depender del resultado** | consistent in courses 4 and 17 and the quiz |
| social proof | **prueba social** (social proof) | established marketing term |
| frame / frame control | **actitud**; **marcar el tono** | |
| rep / reps / volume | **intento(s)**, **muchos intentos** | *repeticiones* only in a gym metaphor |
| banter | **ida y vuelta con humor**, *bromear* | not *cotorreo* (Mexico only) |
| teasing / cheeky | **tomarle el pelo**, *bromear con ella* / **atrevido**, *pícaro* | not *vacilar* (means different things in Mexico and Spain) |
| flirting / flirty | **coquetear**, *coqueteo* / **coqueto** | *ligar* for "to pick up / hook up" |
| small talk | **charla casual**, *conversación ligera* | *plática* is Mexican, fine in a Mexican scene only |
| momentum | **ritmo**, *mantener el ritmo* | |
| threading / threads | **hilos**, *retomar un hilo* | |
| validating | **reconocer**, *validar* sparingly | |
| attunement | **sintonía**, *estar en sintonía* | |
| sticking point | **punto de estancamiento** | |
| growth / fixed mindset | **mentalidad de crecimiento / mentalidad fija** | established terms |
| confidence | **seguridad en ti mismo**, *confianza* | |
| date | **cita** | |
| streak | **racha** | |
| daily practice | **práctica diaria** | |
| scenario | **escenario** | RAE accepts it in this sense; see open points |
| quiz | **cuestionario**, *preguntas* | |
| log (the journal) | **registro** | |
| sexual tension | **tensión** (*tensión sexual* where the English is explicit) | |
| disqualification (21_1) | rewrite by meaning, as German did (*no impresionarte de inmediato*) | PUA term with no neutral Spanish |
| consent wording (17_3) | as strict as the English: *Nunca la toques sin señales claras de que está cómoda, y detente de inmediato si se aparta.* | do not soften |

## Look at these first

These carry money, law or first impressions. A native speaker should read every one; for Spanish, ideally a Mexican reviewer plus a Spaniard's pass on the paywall and onboarding.

1. **Paywall and one-time offer**: the "*Hoy pagas %1$@ … después, %2$@ al mes*" sentences, "*Se cobra de inmediato…*", "*Hoy no pagas nada…*", "*solo %@ a la semana*", the ticks, and "*OFERTA ÚNICA*". Read them with the prices above.
2. **Sign-in legal line**: "*Al continuar, aceptas nuestros [Términos](terms) y la [Política de privacidad](privacy)*".
3. **Onboarding**: the questions, answers, the four statistic screens (see the validator workaround), the commitment pledge ("*Yo, %@, me convierto en un hombre que actúa.*") and the growth chart labels.
4. **Notifications**: the daily reading reminder and the tips-and-offers permission text.
5. **Course titles**: translated in the catalog before the lessons were read; the lesson session may suggest better ones (logged, not edited).

## Open points

- **Escenarios** vs *Situaciones* for the Scenarios tab. *Escenario* is correct but can read "stage"; *Situaciones* is plainer. Draft uses *Escenarios*.
- *Configuración* vs *Ajustes* (see Fixed choices): one word for both regions; Spain's reviewer should confirm it doesn't jar.
- The Nora Ephron quote "be the heroine of your life": German made it *der Held deines Lebens* since the readers are men. Spanish draft: *sé el protagonista de tu vida*. Keep or restore.
- Course titles marked uncertain in the setup log (Phase 2).

## Still to translate (not in the catalog draft)

| Part | Size | Who |
|---|---|---|
| Lesson overlays | ~34,400 English words, 25 files | Spanish session: `python3 scripts/lesson_overlays.py export es <folder>` / `check es` |
| Database content | 765 quiz questions, 15 scenarios (796 text screens, 276 options) | Spanish session: `localization/es/db/*.json` → `python3 scripts/db_translations_sql.py es` (never run the SQL) |
| Review pack | | `python3 scripts/review_pack.py es` (choices in `localization/es/review/choices.json`) |
| App Store listing, subscription display names | | Spanish session drafts `docs/spanish-app-store-listing.md`; Arthur enters it in App Store Connect |

Until those are done, a Spanish build shows a Spanish interface with English lessons, quizzes and scenarios. Don't ship it in that state.
