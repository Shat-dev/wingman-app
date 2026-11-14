# Spanish (Release C): progress log

Branch `localization-release-c-es` (from `localization-release-c`). Rules and glossary: [localization-es-brief.md](localization-es-brief.md). Model: German, see [localization-de-progress.md](localization-de-progress.md). Shared setup log (read-only here): [localization-release-c-progress.md](localization-release-c-progress.md). Everything here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

## Where it stands

Lessons in progress (see Summary). Not yet started: database content, checks, App Store listing.

## Summary

| Part | State |
|---|---|
| UI catalogs | 585 of 585 strings drafted (setup session, 2026-11-15) |
| Lesson overlays | 5 of 25 courses (339 of 1,531 items) |
| Database content | Not started (15 scenarios, 765 questions) |
| Checks and review pack | Not started |
| App Store listing | Not started |

Lesson order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11.

## Log

- **2026-11-15. Branch.** The worktree started on `claude/agitated-mayer-551a2b` (at `Shat`, without the setup commits), so `localization-release-c-es` was created from `localization-release-c` (`9b623ac`), which has "Release C: language-generic tooling and tests" and "Release C: Spanish UI catalogs (draft)".
- **2026-11-15. Course 1, Beliefs & Reframes** (5 lessons, 80 items, 1,782 English words). `lesson_overlay_course_1_es.json`. The check passes. For the reviewer: "growth mindset / fixed mindset" became *mentalidad de crecimiento / mentalidad fija*, with the English in brackets on first use (as German); "competence confidence loop" became *el ciclo entre competencia y seguridad*; "confidence" is *seguridad* (and *seguridad en ti mismo* in the course summary); "composure" became *aplomo*; "overthinking" became *sobrerreflexión* (check: *darle demasiadas vueltas* is plainer). "60,000 thoughts" is written in words (*sesenta mil*) to avoid the thousands separator, which differs between Mexico (60,000), Spain (60 000 / 60.000) and elsewhere.
- **2026-11-15. Course 6, Approach Readiness** (4 lessons, 68 items, 1,503 English words). The check passes. For the reviewer: "You're always in the field" became *Siempre estás en la cancha* (football, and it echoes the catalog's *Entra a la cancha* quote); "got a rep" / "volume" became *sumó un intento más* / *muchos intentos*; "agenda" became *intención (oculta)*, and the title "Curiosity Beats Agenda" *La curiosidad le gana a las intenciones*; "frame" became *el tono ya está marcado*; "pickup lines" became *frases de ligue*. The train became the *metro* and the grocery store the *supermercado* on a Sunday morning (fine in Latin America). Mexico-only words were swapped for neutral ones (*conversar* not *platicar*, *camiseta* not *playera*, *afeitar* not *rasurar*); *laptop* and *calcomanías* are Latin American (Spain: *portátil*, *pegatinas*).
- **2026-11-15. Course 12, Small Talk & Momentum** (4 lessons, 67 items, 1,396 English words). The check passes. For the reviewer: "threading" became *retomar hilos* (*hilos* for "threads"); "momentum" became *ritmo* (*Mantén el ritmo*); "small talk" became *charla casual*; "statements" became *comentarios* ("Observations and Statements" → *observaciones y comentarios*); "you earned your drink" became *este trago te lo ganaste* (*trago* is Latin American; Spain would say *copa*); "composure" is *aplomo*, as in course 1. Her background (Canada, New York) is kept: it's her story, not a US setting.
- **2026-11-15. Course 17, Flirting Prerequisites** (4 lessons, 63 items, 1,369 English words). The check passes. **Consent wording (17_3)** is the brief's line, as strict as the English: *Nunca la toques sin señales claras de que está cómoda, y detente de inmediato si se aparta.* "Guilt trips or attitude" became *sin hacerla sentir culpable y sin mala actitud*; "baseline" became *lo mínimo*. Other choices for the reviewer: "outcome independence" became *no depender del resultado* (as the brief); "calibration" became *calibrar: leer la situación y ajustarte* (17_4); "the close" became *concretar*; "vibe" became *vibra* (common across Latin America; Spain would say *rollo*); "pass/fail" became *un examen de todo o nada*; "green / yellow / red lights" kept as *luz verde / amarilla / roja*; "bartender" became *barman*.
- **2026-11-15. Course 22, Upgrading Your Lifestyle** (4 lessons, 61 items, 1,447 English words). The check passes. The first course of every category is now done. For the reviewer: "social proof" became *prueba social (social proof)*, English in brackets on first use; "social circle" became *círculo social*; "social capital" became *capital social*; "networking event" keeps *networking* (common in Latin American and Spanish business talk); "playing games" became *juegan videojuegos*; "pacing" (of mystery) became *saber dosificar*; "resume" became *currículum*. "You are the average of the five people…" is the usual Spanish form of the saying (*Eres el promedio de las cinco personas…*).

## For the setup session

(Catalog mistakes, better course titles, script bugs. Nothing edited from here.)

## Questions for Arthur

(None yet.)
