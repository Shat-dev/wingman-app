# Spanish (Release C): progress log

Branch `localization-release-c-es` (from `localization-release-c`). Rules and glossary: [localization-es-brief.md](localization-es-brief.md). Model: German, see [localization-de-progress.md](localization-de-progress.md). Shared setup log (read-only here): [localization-release-c-progress.md](localization-release-c-progress.md). Everything here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

## Where it stands

Lessons in progress (see Summary). Not yet started: database content, checks, App Store listing.

## Summary

| Part | State |
|---|---|
| UI catalogs | 585 of 585 strings drafted (setup session, 2026-11-15) |
| Lesson overlays | 2 of 25 courses (148 of 1,531 items) |
| Database content | Not started (15 scenarios, 765 questions) |
| Checks and review pack | Not started |
| App Store listing | Not started |

Lesson order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11.

## Log

- **2026-11-15. Branch.** The worktree started on `claude/agitated-mayer-551a2b` (at `Shat`, without the setup commits), so `localization-release-c-es` was created from `localization-release-c` (`9b623ac`), which has "Release C: language-generic tooling and tests" and "Release C: Spanish UI catalogs (draft)".
- **2026-11-15. Course 1, Beliefs & Reframes** (5 lessons, 80 items, 1,782 English words). `lesson_overlay_course_1_es.json`. The check passes. For the reviewer: "growth mindset / fixed mindset" became *mentalidad de crecimiento / mentalidad fija*, with the English in brackets on first use (as German); "competence confidence loop" became *el ciclo entre competencia y seguridad*; "confidence" is *seguridad* (and *seguridad en ti mismo* in the course summary); "composure" became *aplomo*; "overthinking" became *sobrerreflexión* (check: *darle demasiadas vueltas* is plainer). "60,000 thoughts" is written in words (*sesenta mil*) to avoid the thousands separator, which differs between Mexico (60,000), Spain (60 000 / 60.000) and elsewhere.
- **2026-11-15. Course 6, Approach Readiness** (4 lessons, 68 items, 1,503 English words). The check passes. For the reviewer: "You're always in the field" became *Siempre estás en la cancha* (football, and it echoes the catalog's *Entra a la cancha* quote); "got a rep" / "volume" became *sumó un intento más* / *muchos intentos*; "agenda" became *intención (oculta)*, and the title "Curiosity Beats Agenda" *La curiosidad le gana a las intenciones*; "frame" became *el tono ya está marcado*; "pickup lines" became *frases de ligue*. The train became the *metro* and the grocery store the *supermercado* on a Sunday morning (fine in Latin America). Mexico-only words were swapped for neutral ones (*conversar* not *platicar*, *camiseta* not *playera*, *afeitar* not *rasurar*); *laptop* and *calcomanías* are Latin American (Spain: *portátil*, *pegatinas*).

## For the setup session

(Catalog mistakes, better course titles, script bugs. Nothing edited from here.)

## Questions for Arthur

(None yet.)
