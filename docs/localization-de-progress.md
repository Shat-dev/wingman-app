# German (Release B): progress log

Branch `localization-release-b`. Rules and glossary: [localization-de-brief.md](localization-de-brief.md). Plan: section 7 of [localization-implementation-plan.md](localization-implementation-plan.md). Everything here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

## Summary

| Part | State |
|---|---|
| UI catalogs (G2) | 574 of 574 strings drafted (2026-11-10) |
| Lesson overlays (G3) | 6 of 25 courses (400 of 1,531 items): 1, 2, 6, 12, 17, 22 |
| Database content (G4) | Not started |
| German sweep (G7) | Onboarding and tabs on SE, 2026-11-11: no clipping. Lessons not yet seen in German |

Lesson order followed: the first course of each category before the second (1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, …), the order the app's file names give.

## Log

- **2026-11-11. UI catalogs, German sweep.** Committed `8f86f07`. Sweep on the SE in German: 26 screens, no clipped or overlapping text.
- **2026-11-11. Course 1, Beliefs & Reframes** (5 lessons, 80 items, 1,782 English words). `lesson_overlay_course_1_de.json`. The check passes. Test change: `testTheAppBundleShipsNoOverlays` was a Release A guard ("no overlay files at all"). It now allows German, rejects other languages and checks every bundled German file loads. 298 tests pass. For the reviewer: "growth mindset / fixed mindset" became *Wachstumsdenken / starres Denken*, with the English terms in brackets on first use; "competence confidence loop" became *Kompetenz-Selbstvertrauen-Kreislauf*.
- **2026-11-11. Course 6, Approach Readiness** (4 lessons, 68 items, 1,503 English words). The check passes. For the reviewer: "You're always in the field" became *Du bist immer im Spiel*; "got a rep" / "volume" became *ein weiterer Versuch* / *viele Versuche*. The man in the grocery store is there on a Saturday morning rather than Sunday, since German supermarkets are closed on Sundays.
- **2026-11-11. Course 12, Small Talk & Momentum** (4 lessons, 67 items, 1,396 English words). The check passes. For the reviewer: "threading" became *Anknüpfen* (with *Fäden* for "threads"); "momentum" became *Schwung*.
- **2026-11-11. Course 17, Flirting Prerequisites** (4 lessons, 63 items, 1,369 English words). The check passes. For the reviewer: the Respect lesson (17_3) carries consent wording ("Never touch without clear signs she's comfortable…"). It's kept as strict as the English: *Fass sie niemals an ohne klare Zeichen, dass es für sie in Ordnung ist*. "Outcome independence" became *nicht vom Ergebnis abhängig sein*; "calibration" became *Kalibrieren*.
- **2026-11-11. Course 22, Upgrading Your Lifestyle** (4 lessons, 61 items, 1,447 English words). The check passes. The first course of every category is now done. For the reviewer: "social proof" became *sozialer Beweis (Social Proof)*; "social circle" became *Freundeskreis*; "playing games" became *zocken*.
- **2026-11-11. Course 2, Fear & Exposure** (4 lessons, 61 items, 1,344 English words). The check passes. For the reviewer: "screw it" became *Scheiß drauf*. That matches the English register, but it's the coarsest word in the lessons so far, so soften it to *Egal* if the app should stay clean. "Grounding" became *Erdung*; "bottom-up regulation" became *Bottom-up-Regulation*.

## Questions for Arthur

- Course 7's title, "The Physical Approach", was drafted as *Der körperliche Ansatz*. Its first lesson is "The 3-Second Rule", so the course is about the act of walking up, not touch. *Das Ansprechen in der Praxis* or *Der Weg zu ihr* may fit better. To decide with the reviewer when course 7 is done.
- **English source error, lesson 12_3 ("Maintain Momentum").** Its summary reads "Learn why inaction guarantees regret while action always creates possibility", a copy of lesson 6_1's summary that doesn't match the lesson. The German follows the English for now. Suggested fix in both languages: "Learn to keep a conversation balanced: neither silence nor monologue" / *Lerne, ein Gespräch im Gleichgewicht zu halten – ohne Schweigen und ohne Monolog.* Fixing the English is a content change for you to make.
