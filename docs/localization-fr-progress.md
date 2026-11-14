# French (Release C): progress log

Branch `localization-release-c-fr` (from `localization-release-c`). Rules and glossary: [localization-fr-brief.md](localization-fr-brief.md). Model: German, [localization-de-progress.md](localization-de-progress.md). Shared setup log (read-only here): [localization-release-c-progress.md](localization-release-c-progress.md). Everything here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

## Where it stands

Lesson overlays in progress (3 of 25 courses). Database content, checks, review pack and App Store listing not started.

## Summary

| Part | State |
|---|---|
| UI catalogs | Done by the setup session (585 strings, draft) |
| Lesson overlays | 3 of 25 courses, 215 of 1,531 items |
| Database content | Not started (15 scenarios, 765 quiz questions) |
| Checks and review pack | Not started |
| App Store listing (France, notes for Canada) | Not started |

Lesson order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11.

**Typography used throughout the lessons**, as in the French catalog: typographic apostrophe ’; narrow no-break space (U+202F) before ; : ! ? and inside « »; thousands with U+202F (*60 000*); English "quotes" become « guillemets ». A small scratch script applies this after each draft (it is not in the repo); the check below confirms there is no straight apostrophe and no ordinary space before those signs.

## Log

- **2026-11-15. Branch.** Created `localization-release-c-fr` from `localization-release-c` (at `9b623ac`, which has "Release C: language-generic tooling and tests" and "Release C: French UI catalogs (draft)").
- **2026-11-15. Course 1, Beliefs & Reframes** (5 lessons, 80 items, 1,782 English words). `lesson_overlay_course_1_fr.json`; `lesson_overlays.py check fr` passes. For the reviewer: "growth mindset / fixed mindset" became *état d'esprit de développement / état d'esprit fixe*, with the English in brackets on first use (as German); "competence confidence loop" became *boucle compétence-confiance*; "reframe" became *recadrage*; "composure" became *sang-froid*; "overthinking" became *rumination*; "Perspective is authorship" is paraphrased (*Ton regard sur les choses fait de toi l'auteur*). In 1_2 the person who pulls back is a woman (*elle*), since the scene is an approach. "Failure into feedback" became *retour d'expérience*.
- **2026-11-15. Course 6, Approach Readiness** (4 lessons, 68 items, 1,503 English words). The check passes. For the reviewer: "You're always in the field" became *Tu es toujours sur le terrain*; "got a rep" became *une tentative de plus à son actif*, "volume" became *faire beaucoup / peu d'approches*; "agenda" became *objectif* (*La curiosité plutôt que l'objectif*); "self-aware opener" became *une accroche pleine d'autodérision*. The grocery scene stays on a Sunday morning (French supermarkets open then). The course title in the catalog, *Prêt à aborder*, fits the lessons.
- **2026-11-15. Course 12, Small Talk & Momentum** (4 lessons, 67 items, 1,396 English words). The check passes. For the reviewer: "threading" became *rebondir sur un fil* (*fils* for "threads"); "momentum" became *élan* (*Garder l'élan*); "small talk" became *conversation de surface* where the English means the shallow kind; "observations and statements" became *observations et affirmations*; "extractive / extracted" became *ne faire que prendre / extorqué*; "a broadcast" became *une émission de radio*. Canada and New York in 12_1 stay as they are: they are her background, not the reader's city.

## Questions for Arthur

None yet.

## For the setup session

None yet.
