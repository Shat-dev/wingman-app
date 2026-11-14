# French (Release C): progress log

Branch `localization-release-c-fr` (from `localization-release-c`). Rules and glossary: [localization-fr-brief.md](localization-fr-brief.md). Model: German, [localization-de-progress.md](localization-de-progress.md). Shared setup log (read-only here): [localization-release-c-progress.md](localization-release-c-progress.md). Everything here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

## Where it stands

Lesson overlays in progress (8 of 25 courses). Database content, checks, review pack and App Store listing not started.

## Summary

| Part | State |
|---|---|
| UI catalogs | Done by the setup session (585 strings, draft) |
| Lesson overlays | 8 of 25 courses, 530 of 1,531 items |
| Database content | Not started (15 scenarios, 765 quiz questions) |
| Checks and review pack | Not started |
| App Store listing (France, notes for Canada) | Not started |

Lesson order, as German: 1, 6, 12, 17, 22, then 2, 7, 13, 18, 23, then 3, 8, 14, 19, 24, then 4, 9, 15, 20, 25, then 5, 10, 16, 21, 11.

**Typography used throughout the lessons**, as in the French catalog: typographic apostrophe ’; narrow no-break space (U+202F) before ; : ! ? and inside « »; thousands and number–unit pairs with U+202F (*60 000*, *45 cm*); English "quotes" become « guillemets ». A small scratch script applies this after each draft (it is not in the repo); the check below confirms there is no straight apostrophe and no ordinary space before those signs.

## Log

- **2026-11-15. Branch.** Created `localization-release-c-fr` from `localization-release-c` (at `9b623ac`, which has "Release C: language-generic tooling and tests" and "Release C: French UI catalogs (draft)").
- **2026-11-15. Course 1, Beliefs & Reframes** (5 lessons, 80 items, 1,782 English words). `lesson_overlay_course_1_fr.json`; `lesson_overlays.py check fr` passes. For the reviewer: "growth mindset / fixed mindset" became *état d'esprit de développement / état d'esprit fixe*, with the English in brackets on first use (as German); "competence confidence loop" became *boucle compétence-confiance*; "reframe" became *recadrage*; "composure" became *sang-froid*; "overthinking" became *rumination*; "Perspective is authorship" is paraphrased (*Ton regard sur les choses fait de toi l'auteur*). In 1_2 the person who pulls back is a woman (*elle*), since the scene is an approach. "Failure into feedback" became *retour d'expérience*.
- **2026-11-15. Course 6, Approach Readiness** (4 lessons, 68 items, 1,503 English words). The check passes. For the reviewer: "You're always in the field" became *Tu es toujours sur le terrain*; "got a rep" became *une tentative de plus à son actif*, "volume" became *faire beaucoup / peu d'approches*; "agenda" became *objectif* (*La curiosité plutôt que l'objectif*); "self-aware opener" became *une accroche pleine d'autodérision*. The grocery scene stays on a Sunday morning (French supermarkets open then). The course title in the catalog, *Prêt à aborder*, fits the lessons.
- **2026-11-15. Course 12, Small Talk & Momentum** (4 lessons, 67 items, 1,396 English words). The check passes. For the reviewer: "threading" became *rebondir sur un fil* (*fils* for "threads"); "momentum" became *élan* (*Garder l'élan*); "small talk" became *conversation de surface* where the English means the shallow kind; "observations and statements" became *observations et affirmations*; "extractive / extracted" became *ne faire que prendre / extorqué*; "a broadcast" became *une émission de radio*. Canada and New York in 12_1 stay as they are: they are her background, not the reader's city.
- **2026-11-15. Course 17, Flirting Prerequisites** (4 lessons, 63 items, 1,369 English words). The check passes. **Consent wording in 17_3 is the brief's sentence, word for word and as strict as the English:** *Ne la touche jamais sans signes clairs qu'elle est à l'aise, et arrête immédiatement si elle se recule.* "Accept rejection without guilt trips or attitude" became *sans la culpabiliser ni lui faire la tête*. For the reviewer: "outcome independence" became *ne pas dépendre du résultat*; "calibration" became *calibrer* (17_4 is about the skill itself, as German's *Kalibrieren*); "the close" became *la façon de concrétiser*; green / yellow / red lights became *feu vert / orange / rouge* (French traffic lights are *orange*); "the best flirts" became *ceux qui flirtent le mieux* (not *dragueurs*, which reads pejorative); "boyfriend" is *copain*.
- **2026-11-15. Course 22, Upgrading Your Lifestyle** (4 lessons, 61 items, 1,447 English words). The check passes. The first course of every category is now done. For the reviewer: "social proof" became *preuve sociale*; "social circle" became *entourage*; "networking event" became *soirée de networking* (the usual French term); "playing games" became *jouer aux jeux vidéo*; "not a flex" became *il ne frime pas*; "resume" became *CV*; "The Interesting Man Advantage" became *L'atout de l'homme intéressant*. Bali / Australia kept (they are travel, not the reader's city).
- **2026-11-15. Course 2, Fear & Exposure** (4 lessons, 61 items, 1,344 English words). The check passes. For the reviewer: "screw it" became *allez, tant pis* (German chose the coarse *Scheiß drauf*; the French is milder on purpose, matching the "calm older brother" tone; *et merde* would match the English register if wanted); "grounding" became *ancrage* (*Points d'ancrage : garder les pieds sur terre*); "bottom-up regulation" became *régulation ascendante (bottom-up)*; "nerves" became *le trac*; "performing" became *jouer un rôle*; "self-monitoring" became *autosurveillance*. "That girl" (2_3_3_1) stays *cette fille*, casual as in the English.
- **2026-11-15. Course 7, The Physical Approach** (4 lessons, 67 items, 1,492 English words). The check passes. Distances are metric: eighteen inches became *45 cm*, three feet *un mètre*. For the reviewer: "the 3-second rule" became *la règle des 3 secondes*; "overthinking" became *réflexion excessive*; "analysis paralysis" became *paralysie de l'analyse*; "outdoor cafes" became *en terrasse*; "social calibration" became *tu sais lire la situation*; "approach angle / distance" became *angle / distance d'approche*. The lessons cover the 3-second rule, angle and distance, posture while walking up and eye contact, so the catalog title *Aller vers elle* fits (German changed its title for the same reason; no change needed here).
- **2026-11-15. Course 13, Listening & Attunement** (4 lessons, 63 items, 1,383 English words). The check passes. For the reviewer: "validating" became *reconnaître* / *la reconnaissance* (*valider* avoided, per the glossary); "validating follow-ups" became *une relance qui reconnaît ce qu'elle dit*; "attunement / attuned" became *être à l'écoute / en phase*; "subtext" became *sous-texte*; "non-verbal listening cues" became *signes d'écoute non verbaux*. The sister lives in Bordeaux rather than Portland (German used Hamburg). "I'm fine" became *Ça va*.

## Questions for Arthur

None yet.

## For the setup session

None yet.
