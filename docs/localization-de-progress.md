# German (Release B): progress log

Branch `localization-release-b`. Rules and glossary: [localization-de-brief.md](localization-de-brief.md). Plan: section 7 of [localization-implementation-plan.md](localization-implementation-plan.md). Everything here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

## Summary

| Part | State |
|---|---|
| UI catalogs (G2) | 574 of 574 strings drafted (2026-11-10) |
| Lesson overlays (G3) | 1 of 25 courses (80 of 1,531 items) |
| Database content (G4) | Not started |
| German sweep (G7) | Onboarding and tabs on SE, 2026-11-11: no clipping. Lessons not yet seen in German |

Lesson order followed: the first course of each category before the second (1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, …), the order the app's file names give.

## Log

- **2026-11-11. UI catalogs, German sweep.** Committed `8f86f07`. Sweep on the SE in German: 26 screens, no clipped or overlapping text.
- **2026-11-11. Course 1, Beliefs & Reframes** (5 lessons, 80 items, 1,782 English words). `lesson_overlay_course_1_de.json`. The check passes. Test change: `testTheAppBundleShipsNoOverlays` was a Release A guard ("no overlay files at all"). It now allows German, rejects other languages and checks every bundled German file loads. 298 tests pass. For the reviewer: "growth mindset / fixed mindset" became *Wachstumsdenken / starres Denken*, with the English terms in brackets on first use; "competence confidence loop" became *Kompetenz-Selbstvertrauen-Kreislauf*.

## Questions for Arthur

- Course 7's title, "The Physical Approach", was drafted as *Der körperliche Ansatz*. Its first lesson is "The 3-Second Rule", so the course is about the act of walking up, not touch. *Das Ansprechen in der Praxis* or *Der Weg zu ihr* may fit better. To decide with the reviewer when course 7 is done.
