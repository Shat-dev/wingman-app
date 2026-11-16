# Idiom audit: German, French, Spanish, Japanese (2026-11-16)

Trigger: a German native reviewer said the idioms were the worst part of the translation, with “Back on the market” as the example. This is a check of every English idiom and figurative phrase in the app against its four translations.

## Status

2026-11-16: every A-level fix below is applied in the repo (43 replacements across the four languages). In the A sections, “Now” shows the text before the fix and “Suggested” is what the files now say; where an entry gave options, the wording applied is the one in the files. B and C are open. Seed SQL and the bundled quiz copy were regenerated with `scripts/db_translations_sql.py`. Production Supabase rows are not updated: 13 regenerated files under `supabase/seed/content_translations_<lang>/` (5 de, 3 fr, 2 es, 3 ja) still need to be run for the scenario and quiz fixes to reach users. Lesson and UI fixes ship with the next build. The review-pack spreadsheets under `localization/<lang>/review/` were not regenerated.

## Result

| Language | A: reads wrong | B: translated image | C: polish |
|---|---|---|---|
| German | 11 | 17 | 7 |
| French | 4 | 4 | 5 |
| Spanish | 4 | 5 | 4 |
| Japanese | 6 | 7 | 5 |

Several entries cover more than one string; the string count is on the entry.

- **German is the weak one**, and one pattern is worse than “auf dem Markt”: `die Stimmung kippen lassen` is used for “shift the mood to flirty” in a whole lesson and four quiz questions, and in German it means the mood turns sour.
- **Classic idioms were mostly handled well in all four languages.** Home runs became goals in German, French and Spanish and stayed baseball in Japanese; “every cloud has a silver lining”, “fall flat”, “wrong foot” (FR/ES), “out of my league”, “playing hard to get”, “break the ice” all landed on real local idioms. “Back on the market” is fine in French, Spanish and Japanese and was already fixed in German.
- **What fails is coaching English, not proverbs**: “let the moment breathe”, “hold space”, “take up space”, “the room”, “gave you a thread”, “read the room”, “frame”, “show up”, “keeps the ground warm”. The same dozen images account for most findings in every language.
- **App Store listings and screenshot captions: nothing to change** in any language.

## What was checked, and how

| Content | Strings | Method |
|---|---|---|
| UI catalogs (onboarding, paywall, quotes, settings) | 586 | English read in full; every figurative string compared in all four languages |
| Scenarios (15) | 1,102 | English read in full; about 140 figurative strings compared |
| Lessons (25 courses) | 1,531 | English read in full; about 270 figurative sentences compared |
| Quiz questions | 4,364 | Not read in full. Searched for every calque found above in each language, plus an English idiom filter (87 hits, 16 compared) |
| App Store listings, screenshot captions | 4 files | Read in full |

Limits: strings with no figurative English were not compared, so a mistranslation of plain text would not show up here. Quiz coverage is by search, not by reading. I am not a native speaker of any of the four; A-level findings are ones I am confident about, the suggested wording is a draft for a native to confirm. Nothing in the app or database was changed.

Severity: **A** reads wrong, means something else, or means nothing. **B** is understandable but visibly a translated English image. **C** is polish.


## German

German has the most findings and the only pattern that actively says the opposite of what is meant (`kippen`). The onboarding fixes from the first review (commit 9539c53, including “wieder auf dem Markt” → “wieder Single”) are already in and are not repeated here.

### A — reads wrong or changes the meaning

**A · “kippen”** · 8 strings
- English: A single well-placed line can shift an interaction from polite to flirty.
- Now: Ein einziger gut platzierter Satz kann eine Begegnung von höflich zu flirty kippen lassen.
- Problem: “Die Stimmung kippt” means the mood turns sour. The whole lesson “One Line to Change the Dynamic” and four quiz strings tell the user how to make the mood go bad.
- Suggested: Use `drehen` / `verändern`: “…von höflich zu flirty drehen”, “ein Satz, der die Stimmung verändert”, “…kann alles verändern”, “um dem Moment eine neue Richtung zu geben”.
- Where: Lesson overlay course 19, `content_19_3_2_1` — also rows: Lesson overlay course 19, `lesson_19_3.summary`; Lesson overlay course 19, `content_19_3_4_1`; Lesson overlay course 19, `content_19_3_5_1`; Quiz `questions_04_flirting_chemistry_1`, `92141af3-4469-4cb2-aeca-c8b66beca062/question_text`; Quiz `questions_04_flirting_chemistry_1`, `d81d87c2-562a-4457-9339-626b9b62911d/question_text`; Quiz `questions_04_flirting_chemistry_1`, `de314e72-aecd-48e2-9e7e-904002814fcb/question_text`; Quiz `questions_04_flirting_chemistry_2`, `c23fa6ee-381a-4d27-bf59-41f86d51451f/question_text`

**A · “unters Volk zu mischen”**
- English: People start mingling.
- Now: Die Leute fangen an, sich unters Volk zu mischen.
- Problem: “Sich unters Volk mischen” is what a celebrity does among ordinary people; “die Leute mischen sich unters Volk” is circular.
- Suggested: Die Leute kommen miteinander ins Gespräch.
- Where: Scenario `scenario_12_performance_review`, `b1000004-0000-0000-0012-000000000004`

**A · “auf dem falschen Fuß”**
- English: The interaction starts on the wrong foot.
- Now: Die Begegnung startet auf dem falschen Fuß.
- Problem: German only has “jemanden auf dem falschen Fuß erwischen” (catch off guard). “Auf dem falschen Fuß starten” is the English idiom word for word.
- Suggested: Die Begegnung läuft von Anfang an schief.
- Where: Lesson overlay course 3, `content_3_3_5_1`

**A · “nimm Platz ein”**
- English: Stand in a room, take up space, speak when you want to, and you will understand that the world is far less focused on you than your mind assumes.
- Now: Stell dich in einen Raum, nimm Platz ein, sag etwas, wenn dir danach ist – und du wirst merken, dass die Welt viel weniger auf dich achtet, als dein Kopf annimmt.
- Problem: Too close to “nimm Platz” (sit down). The German phrase for taking up space is “Raum einnehmen”, which lesson `content_8_4_4_2` already uses.
- Suggested: …nimm Raum ein, sag etwas, wenn dir danach ist…
- Where: Lesson overlay course 2, `content_2_2_4_1`

**A · “Haken”**
- English: We open our mouths expecting interest, yet offer no hook that invites it.
- Now: Wir machen den Mund auf und erwarten Interesse, bieten aber keinen Haken, der es weckt.
- Problem: “Haken” reads as a catch or snag (“die Sache hat einen Haken”). The hook of a conversation is an “Aufhänger”, which `content_11_2_2_2` already uses.
- Suggested: …bieten aber keinen Aufhänger, der es weckt.
- Where: Lesson overlay course 11, `content_11_1_1_2`

**A · “Der Raum bricht nicht zusammen”**
- English: The room doesn't fall apart.
- Now: Der Raum bricht nicht zusammen.
- Problem: Literal “the room doesn't fall apart”; in German a room collapsing is a building accident. The idiom is “die Welt geht nicht unter”.
- Suggested: Die Welt geht nicht unter.
- Where: Lesson overlay course 1, `content_1_4_3_3`

**A · “der Raum”** · 3 strings
- English: When you later ask if she's finished with the kettlebells, she responds warmly because the room already vouched for you.
- Now: Als du sie später fragst, ob sie mit den Kettlebells fertig ist, reagiert sie herzlich, weil der Raum schon für dich gebürgt hat.
- Problem: English “the room” meaning the people in it does not carry over; “der Raum hat für dich gebürgt / ist sich einig / reagiert auf dich” reads as the furniture doing it.
- Suggested: “…weil die Leute dort schon für dich gebürgt haben”; “…worüber sich die Anwesenden schon einig sind”; “Status ist, wie die Leute im Raum auf dich reagieren.”
- Where: Lesson overlay course 23, `content_23_3_4_2` — also rows: Lesson overlay course 22, `content_22_1_1_2`; Quiz `questions_05_mastery_integration`, `afe9db16-1b83-4292-ba6f-e10ecbe6ac93/explanation`

**A · “Raum”** · 2 strings
- English: Hold the space and let her think
- Now: Den Raum halten und sie nachdenken lassen
- Problem: “Den Raum halten” (holding space) is English therapy jargon and means nothing in German.
- Suggested: Quiz option: “Die Stille aushalten und sie nachdenken lassen”. Lesson: “Wenn du diese Stille entspannt aushalten kannst, …”.
- Where: Quiz `questions_03_conversational_skills_1`, `f100da89-837b-4ce4-89f0-13a05418c184/options[3]` — also rows: Lesson overlay course 12, `content_12_4_1_2`

**A · “hält den Boden warm”**
- English: A single conversation this week keeps the ground warm for the next one.
- Now: Ein einziges Gespräch diese Woche hält den Boden warm für das nächste.
- Problem: Literal “keeps the ground warm”; no such image in German.
- Suggested: Ein einziges Gespräch diese Woche hält dich in Übung für das nächste.
- Where: Lesson overlay course 24, `content_24_2_7_2`

**A · “spinnt”**
- English: Every moment you pause long enough to notice the story your mind is spinning, you reclaim control.
- Now: Jedes Mal, wenn du lange genug innehältst, um die Geschichte zu bemerken, die dein Kopf spinnt, holst du dir die Kontrolle zurück.
- Problem: “Dein Kopf spinnt” means your head is being crazy; the reader stumbles before reaching “Geschichte”.
- Suggested: …die Geschichte zu bemerken, die sich dein Kopf zusammenreimt…
- Where: Lesson overlay course 1, `content_1_1_6_1`

**A · “wird beides kosten”**
- English: A man who fears pain more than failure will taste both
- Now: Wer den Schmerz mehr fürchtet als das Scheitern, wird beides kosten
- Problem: “Kosten” reads as “cost” first, so the quote says he “will cost both”.
- Suggested: Wer den Schmerz mehr fürchtet als das Scheitern, bekommt beides zu spüren.
- Where: UI catalog (Content.xcstrings), key “A man who fears pain more than failure will taste both”

### B — understandable, but clearly a translated English image

**B · “keinen Funken”** · 2 strings
- English: The conversation continues, but there's no spark because it's all friendly and informational.
- Now: Das Gespräch geht weiter, aber es gibt keinen Funken, weil alles nur freundlich und informativ ist.
- Problem: German has its own idiom here and the draft walks past it: “der Funke springt (nicht) über”.
- Suggested: “…aber der Funke springt nicht über, weil alles nur freundlich und informativ ist.” / “…springt kein Funke über.”
- Where: Lesson overlay course 18, `content_18_1_3_2` — also rows: Lesson overlay course 18, `content_18_1_5_1`

**B · “Funken mit”**
- English: If they are lively, bring a little more spark.
- Now: Wenn sie aufgedreht sind, bring etwas mehr Funken mit.
- Problem: “Funken mitbringen” is not said.
- Suggested: Wenn sie aufgedreht sind, bring etwas mehr Schwung mit.
- Where: Lesson overlay course 17, `content_17_4_5_1`

**B · “Funke”**
- English: Playfulness & Spark
- Now: Verspieltheit & Funke
- Problem: As a course title “Funke” on its own is bare; “Knistern” is the word for romantic spark in the air.
- Suggested: Verspieltheit & Knistern
- Where: UI catalog (Content.xcstrings), key “Playfulness & Spark”

**B · “auseinanderfallen”** · 2 strings
- English: It's not a general weakness; it's the exact moment where things fall apart repeatedly.
- Now: Keine allgemeine Schwäche, sondern genau der Moment, in dem die Dinge immer wieder auseinanderfallen.
- Problem: “Things fall apart” word for word.
- Suggested: “…genau der Moment, an dem es immer wieder schiefgeht.” / “Muster anschauen, wo es regelmäßig hakt”.
- Where: Lesson overlay course 25, `content_25_3_1_2` — also rows: Quiz `questions_05_mastery_integration`, `b31c3930-629e-4aab-974a-035d198918d4/options[2]`

**B · “Faden gegeben”** · 3 strings
- English: She gave you a thread, you ignored it.
- Now: Sie hat dir einen Faden gegeben, und du hast ihn ignoriert.
- Problem: “She gave you a thread” word for word, and “es um dich gedreht” (5 scenario strings) is not German either.
- Suggested: Du hast das Gespräch auf dich gelenkt. Sie hat dir einen Anknüpfungspunkt geliefert, und du bist nicht darauf eingegangen.
- Where: Scenario `scenario_02_coffee_connections`, `b1000112-0000-0000-0002-000000000112` — also rows: Scenario `scenario_02_coffee_connections`, `b1000114-0000-0000-0002-000000000114`; Scenario `scenario_02_coffee_connections`, `b1000162-0000-0000-0002-000000000162`

**B · “Lies die Stimmung”**
- English: Read the room and lighten it.
- Now: Lies die Stimmung und mach sie leichter.
- Problem: “Read the room” word for word.
- Suggested: Achte auf die Stimmung und lockere sie auf.
- Where: Scenario `scenario_02_coffee_connections`, `b1000164-0000-0000-0002-000000000164`

**B · “Rampenlicht”**
- English: Keep the spotlight on her, not yourself.
- Now: Lass das Rampenlicht bei ihr, nicht bei dir.
- Problem: “Sich über etwas öffnen” and “das Rampenlicht bei ihr lassen” are both English constructions.
- Suggested: Sie hat gerade von ihrer Leidenschaft erzählt. Lass sie im Mittelpunkt stehen, nicht dich.
- Where: Scenario `scenario_04_read_between_lines`, `b1000124-0000-0000-0004-000000000124`

**B · “inneren Boden”**
- English: What feels like rejection is almost always someone protecting their own internal ground.
- Now: Was sich wie Zurückweisung anfühlt, ist fast immer jemand, der seinen eigenen inneren Boden schützt.
- Problem: “Internal ground” word for word.
- Suggested: …jemand, der sein eigenes inneres Gleichgewicht schützt.
- Where: Lesson overlay course 1, `content_1_2_3_2`

**B · “ganz zu bleiben”**
- English: That is where confidence lives, not in being wanted, but in staying whole when you are not.
- Now: Genau dort wohnt Selbstvertrauen: nicht darin, gewollt zu werden, sondern darin, ganz zu bleiben, wenn du es nicht wirst.
- Problem: “Staying whole” word for word.
- Suggested: …sondern darin, bei dir zu bleiben, wenn du es nicht wirst.
- Where: Lesson overlay course 1, `content_1_2_5_2`

**B · “den Kontakt nicht überlebt”**
- English: It never survived contact.
- Now: Sie hat den Kontakt nicht überlebt.
- Problem: Echo of “no plan survives contact”, which German readers will not hear.
- Suggested: Sie hat die Begegnung mit der Wirklichkeit nicht überlebt.
- Where: Lesson overlay course 2, `content_2_1_4_2`

**B · “das Gespräch trägt”**
- English: You don't sit back waiting for her to carry the conversation or give perfect signals.
- Now: Du lehnst dich nicht zurück und wartest, dass sie das Gespräch trägt oder perfekte Signale sendet.
- Problem: “Carry the conversation” word for word.
- Suggested: …und wartest, dass sie das Gespräch am Laufen hält…
- Where: Lesson overlay course 8, `content_8_3_5_1`

**B · “gehst du sauber”**
- English: If not, you walk away clean.
- Now: Wenn nicht, gehst du sauber.
- Problem: “Walk away clean”. Related: “sich sauber verabschieden” appears in 24 strings; “sauberer Abgang” is fine, “sauber verabschieden” is borderline.
- Suggested: “Wenn nicht, gehst du einfach, ohne dass es unangenehm wird.” For the 24: “kurz und freundlich verabschieden”.
- Where: Lesson overlay course 11, `content_11_4_6_3`

**B · “Mit Verbindung enden, nicht mit Glück”**
- English: End on Connection, Not Luck
- Now: Mit Verbindung enden, nicht mit Glück
- Problem: Lesson title; neither half works as German.
- Suggested: Mit einem Anknüpfungspunkt gehen, nicht auf gut Glück
- Where: Lesson overlay course 15, `lesson_15_2.title`

**B · “der es einfach macht”**
- English: Day 1 of becoming the guy who goes for it
- Now: Tag 1 auf dem Weg zum Typen, der es einfach macht
- Problem: Ambiguous: “who makes it easy” or “who just does it”. This is the commitment screen.
- Suggested: Tag 1 auf dem Weg zum Typen, der sich einfach traut
- Where: UI catalog (Localizable.xcstrings), key “Day 1 of becoming the guy who goes for it”

**B · “Verbindung”**
- English: Can you put a price on connection?
- Now: Kann man Verbindung mit Geld aufwiegen?
- Problem: “Verbindung” alone reads as a phone or train connection. It is used 176 times for “connection”; most are fine in context, the bare ones are not.
- Suggested: Kann man echte Nähe mit Geld aufwiegen?
- Where: UI catalog (Localizable.xcstrings), key “Can you put a price on connection?”

**B · “Rahmen”** · 3 strings
- English: When you bring a stronger frame, your opener becomes more compelling than whatever they were doing before you arrived.
- Now: Wenn du einen stärkeren Rahmen mitbringst, wird dein Opener fesselnder als alles, was sie vorher gemacht hat.
- Problem: “Frame” as pickup jargon. “Den Rahmen setzen” is passable; “ein stärkerer Rahmen”, “der Rahmen hat sich verschoben”, “zerstört deinen Rahmen” are not German. 52 strings use the term. French and Spanish avoided it with “donner le ton” / “marcar el tono”.
- Suggested: Use the “den Ton angeben” family: “Wenn du selbstbewusst den Ton angibst…”, “…aber die Stimmung hat sich so oder so verändert”, “Was nimmt dir schon im Opener die Führung?”
- Where: Lesson overlay course 8, `content_8_3_1_1` — also rows: Lesson overlay course 19, `content_19_3_4_2`; Quiz `questions_02_approach_mechanics_3`, `d61d2413-5ee2-43c8-8cce-8d6030c1879e/question_text`

**B · “total lässig”**
- English: I thought I was being smooth.
- Now: Ich dachte, ich wär total lässig.
- Problem: “Smooth” here means subtle, not cool.
- Suggested: Ich dachte, das wäre unauffällig gewesen. Brauch wohl noch Übung.
- Where: Scenario `scenario_11_trail_talk`, `b1000025-0000-0000-0011-000000000025`

### C — minor polish

**C · “ich mache es meistens”**
- English: No, I usually go for it
- Now: Nein, ich mache es meistens
- Problem: Flat; “go for it” is about daring.
- Suggested: Nein, ich traue mich meistens
- Where: UI catalog (Content.xcstrings), key “No, I usually go for it”

**C · “Momentum”**
- English: Small talk & Momentum
- Now: Smalltalk & Momentum
- Problem: Business English.
- Suggested: Smalltalk & Gesprächsfluss
- Where: UI catalog (Content.xcstrings), key “Small talk & Momentum”

**C · “in deinem eigenen Kopf”**
- English: If you spend most days in your own head, approaching someone will always feel like a jump instead of a step.
- Now: Wenn du die meisten Tage in deinem eigenen Kopf verbringst, wird sich Ansprechen immer wie ein Sprung anfühlen statt wie ein Schritt.
- Problem: “In your own head”; 6 lesson strings.
- Suggested: …die meisten Tage nur in deinen Gedanken verbringst…
- Where: Lesson overlay course 6, `content_6_4_1_1`

**C · “Platz zum Atmen”**
- English: She has space to breathe and move if she wants.
- Now: Sie hat Platz zum Atmen und kann sich bewegen, wenn sie will.
- Problem: The set phrase is “Luft zum Atmen”.
- Suggested: Sie hat Luft zum Atmen und kann sich bewegen, wenn sie will.
- Where: Lesson overlay course 7, `content_7_2_4_1`

**C · “Fenster geöffnet”**
- English: She was opening a window to talk about feeling unsettled.
- Now: Sie hat ein Fenster geöffnet, um darüber zu reden, dass sie sich noch nicht angekommen fühlt.
- Problem: German opens a door, not a window, to a topic.
- Suggested: Sie hat eine Tür geöffnet, um darüber zu reden…
- Where: Lesson overlay course 13, `content_13_2_4_2`

**C · “kippen zu einer Person”**
- English: Most early conversations tilt toward one person without anyone noticing.
- Now: Die meisten frühen Gespräche kippen zu einer Person, ohne dass es jemand merkt.
- Problem: Same verb problem as above, milder.
- Suggested: Die meisten frühen Gespräche neigen sich zu einer Seite…
- Where: Lesson overlay course 14, `content_14_4_1_1`

**C · “im Autopiloten”**
- English: This matters because most openers are low-investment. "How are you?" requires minimal engagement. She can answer on autopilot. But "You seem like you're not from here originally" requires actual engagement.
- Now: Sie kann im Autopiloten antworten.
- Problem: Set phrase is “auf Autopilot”.
- Suggested: Sie kann auf Autopilot antworten.
- Where: Lesson overlay course 11, `content_11_2_2_1`


## French

French is in good shape: most English idioms were replaced with real French ones (“tomber à plat”, “faire mouche”, “à quelque chose malheur est bon”, “partir du mauvais pied”). What is left is a short list of literal images.

### A — reads wrong or changes the meaning

**A · “tendu un fil”** · 4 strings
- English: She gave you a thread, you ignored it.
- Now: Elle t’a tendu un fil, tu l’as ignoré.
- Problem: The French idiom is “tendre une perche”. “Tendre un fil” is the English thread, word for word.
- Suggested: Elle t’a tendu une perche, tu l’as ignorée.
- Where: Scenario `scenario_02_coffee_connections`, `b1000112-0000-0000-0002-000000000112` — also rows: Scenario `scenario_02_coffee_connections`, `b1000114-0000-0000-0002-000000000114`; Scenario `scenario_02_coffee_connections`, `b1000162-0000-0000-0002-000000000162`; Scenario `scenario_14_dressed_to_impress`, `b1000132-0000-0000-0014-000000000132`

**A · “se mélanger”**
- English: People start mingling.
- Now: Les gens commencent à se mélanger.
- Problem: “Se mélanger” is for ingredients or social classes, not guests at an event.
- Suggested: Les gens commencent à discuter entre eux.
- Where: Scenario `scenario_12_performance_review`, `b1000004-0000-0000-0012-000000000004`

**A · “garde le terrain chaud”**
- English: A single conversation this week keeps the ground warm for the next one.
- Now: Une seule conversation cette semaine garde le terrain chaud pour la suivante.
- Problem: Literal “keeps the ground warm”.
- Suggested: Une seule conversation cette semaine te garde dans le rythme pour la suivante.
- Where: Lesson overlay course 24, `content_24_2_7_2`

**A · “tenir cet espace”**
- English: When you are comfortable holding that space, the interaction slows down in a way that feels intentional rather than awkward.
- Now: Quand tu es à l’aise pour tenir cet espace, l’échange ralentit d’une façon qui paraît voulue plutôt que gênante.
- Problem: “Holding space” is English therapy jargon.
- Suggested: Quand tu es à l’aise avec ce silence, l’échange ralentit…
- Where: Lesson overlay course 12, `content_12_4_1_2`

### B — understandable, but clearly a translated English image

**B · “va loin”**
- English: Attraction starts with presentation, and discipline in basic upkeep goes a long way.
- Now: L’attirance commence par la présentation, et la discipline dans l’entretien de base va loin.
- Problem: “Goes a long way” word for word.
- Suggested: …et la discipline dans l’entretien de base fait une vraie différence.
- Where: Lesson overlay course 5, `content_5_2_5_2`

**B · “concentration de laser”**
- English: The successful warrior is the average man, with laser-like focus.
- Now: Le guerrier qui réussit est un homme ordinaire doté d’une concentration de laser.
- Problem: “Laser-like focus” word for word.
- Suggested: …un homme ordinaire doté d’une concentration sans faille.
- Where: UI catalog (Content.xcstrings), key “The successful warrior is the average man, with laser-like f”

**B · “proprement”** · 8 strings
- English: Cold—disengaged; exit cleanly without pushing further
- Now: Froideur : elle n’est pas dans l’échange ; pars proprement sans insister
- Problem: “Exit cleanly”. “Partir proprement” suggests tidiness; 12 strings.
- Suggested: “pars simplement, sans insister” / “Réponse claire, sortie nette.”
- Where: Quiz `questions_02_approach_mechanics_1`, `e069eb31-5232-4ac9-b7e0-bd4b26b8bd92/options[2]` — also rows: Quiz `questions_02_approach_mechanics_2`, `2ada2eb4-7e4e-4ea9-b9d1-7cde29ea6304/explanation`; Quiz `questions_02_approach_mechanics_2`, `611e32cc-c038-42d3-a1ce-086d78cbcd68/options[2]`; Quiz `questions_02_approach_mechanics_2`, `611e32cc-c038-42d3-a1ce-086d78cbcd68/explanation`; Quiz `questions_02_approach_mechanics_2`, `6ead40bd-0dee-4b4c-935e-8cf034256a37/options[2]`; Quiz `questions_02_approach_mechanics_3`, `96cd2c07-1109-4ded-b869-cec66cf863b9/options[3]`; Lesson overlay course 9, `content_9_1_3_2`; Lesson overlay course 11, `content_11_4_6_3`

**B · “Lis la situation”**
- English: Read the room and lighten it.
- Now: Lis la situation et allège l’ambiance.
- Problem: “Read the room” word for word.
- Suggested: Sens l’ambiance et détends-la.
- Where: Scenario `scenario_02_coffee_connections`, `b1000164-0000-0000-0002-000000000164`

### C — minor polish

**C · “volée à elles”**
- English: I hope they won't be annoyed that I've stolen you away from them then.
- Now: J’espère qu’elles ne m’en voudront pas de t’avoir volée à elles, alors.
- Problem: Clumsy construction.
- Suggested: J’espère qu’elles ne m’en voudront pas de t’avoir enlevée à tes amies, alors.
- Where: Scenario `scenario_01_bar_window`, `b1000014-0000-0000-0000-000000000014`

**C · “à l’aise dans ta peau”**
- English: When you dress well, your appearance becomes a quiet advantage, making you more receptive to others and more confident in your own skin.
- Now: Quand tu es bien habillé, ton apparence devient un avantage discret, qui te rend plus ouvert aux autres et plus à l’aise dans ta peau.
- Problem: The set phrase is “bien dans ta peau”.
- Suggested: …plus ouvert aux autres et mieux dans ta peau.
- Where: Lesson overlay course 5, `content_5_4_4_1`

**C · “Ton futur toi”**
- English: Your future self is counting on you.
- Now: Ton futur toi compte sur toi.
- Problem: Calque of “your future self”.
- Suggested: Ton toi de demain compte sur toi.
- Where: UI catalog (Localizable.xcstrings), key “Don't join that statistic. Your future self is counting on y”

**C · “variable inconnue”**
- English: When you're a stranger in a space, you're an unknown variable.
- Now: Quand tu es un inconnu dans un lieu, tu es une variable inconnue.
- Problem: French says “une inconnue”.
- Suggested: …tu es une inconnue.
- Where: Lesson overlay course 23, `content_23_3_2_1`

**C · “se mettait juste en route”**
- English: She was just warming up.
- Now: Elle se mettait juste en route.
- Problem: “Warming up” became “setting off”.
- Suggested: Elle s’échauffait à peine.
- Where: Lesson overlay course 14, `content_14_1_4_2`


## Spanish

Spanish is also clean on classic idioms (“empezar con el pie izquierdo/derecho”, “no hay mal que por bien no venga”, “hacerse la difícil”). The one real trap is “show up”, which came out as “introduce yourself”.

### A — reads wrong or changes the meaning

**A · “present”** · 3 strings
- English: You only need to show up and enjoy the moment you're already in.
- Now: Solo necesitas presentarte y disfrutar del momento en el que ya estás.
- Problem: “Show up” was translated as “presentarte”, which reads as “introduce yourself”. In scenarios the same word is used correctly for introductions, which makes these three more confusing.
- Suggested: “Solo necesitas estar ahí y disfrutar del momento…”; “Primero cambia tu estado y luego acércate.”; “…pequeñas decisiones repetidas de salir y estar presente.”
- Where: Lesson overlay course 17, `content_17_1_6_2` — also rows: Lesson overlay course 17, `content_17_4_6_2`; Quiz `questions_05_mastery_integration`, `5b78be7b-c378-4416-a5d7-3266ab3c3dfc/explanation`

**A · “los bordes se afilan”**
- English: Each time you revisit it, the edges sharpen until it feels like the truth.
- Now: Cada vez que vuelves a ella, los bordes se afilan hasta que parece la verdad.
- Problem: “The edges sharpen” word for word; in Spanish that is a knife.
- Suggested: …los contornos se vuelven más nítidos hasta que parece la verdad.
- Where: Lesson overlay course 1, `content_1_3_1_2`

**A · “mezclarse”**
- English: People start mingling.
- Now: La gente empieza a mezclarse.
- Problem: Same calque as French and German for “mingling”.
- Suggested: La gente empieza a conversar entre sí.
- Where: Scenario `scenario_12_performance_review`, `b1000004-0000-0000-0012-000000000004`

**A · “sosteniendo ese espacio”**
- English: When you are comfortable holding that space, the interaction slows down in a way that feels intentional rather than awkward.
- Now: Cuando te sientes cómodo sosteniendo ese espacio, la interacción se vuelve más pausada de una forma que se siente intencional y no incómoda.
- Problem: “Holding space” is English therapy jargon. The quiz already says “sostener el silencio”, which works.
- Suggested: Cuando te sientes cómodo sosteniendo ese silencio…
- Where: Lesson overlay course 12, `content_12_4_1_2`

### B — understandable, but clearly a translated English image

**B · “dio un hilo”** · 4 strings
- English: She gave you a thread, you ignored it.
- Now: Ella te dio un hilo y lo ignoraste.
- Problem: “Gave you a thread”. “Tirar del hilo” exists, “dar un hilo” does not.
- Suggested: Ella te dio pie para seguir y lo ignoraste.
- Where: Scenario `scenario_02_coffee_connections`, `b1000112-0000-0000-0002-000000000112` — also rows: Scenario `scenario_02_coffee_connections`, `b1000114-0000-0000-0002-000000000114`; Scenario `scenario_02_coffee_connections`, `b1000162-0000-0000-0002-000000000162`; Scenario `scenario_14_dressed_to_impress`, `b1000132-0000-0000-0014-000000000132`

**B · “terreno interior”**
- English: What feels like rejection is almost always someone protecting their own internal ground.
- Now: Lo que se siente como rechazo casi siempre es alguien cuidando su propio terreno interior.
- Problem: “Internal ground” word for word.
- Suggested: …alguien cuidando su propio equilibrio interior.
- Where: Lesson overlay course 1, `content_1_2_3_2`

**B · “sin comida”**
- English: Action starved it.
- Now: La acción lo dejó sin comida.
- Problem: “Starved it” became “left it without food”, which is unintentionally comic.
- Suggested: La duda lo alimentaba. La acción lo mató de hambre.
- Where: Lesson overlay course 2, `content_2_1_4_2`

**B · “cruzaste al otro lado”**
- English: That's when you know you've crossed over.
- Now: Ahí sabes que cruzaste al otro lado.
- Problem: “Crossed over”; in Spanish this leans toward dying or crossing a border.
- Suggested: Ahí sabes que diste el salto.
- Where: Lesson overlay course 24, `content_24_3_7_2`

**B · “tuviera que contar”**
- English: After three months, nothing has changed because every approach feels like it has to count.
- Now: Después de tres meses, nada ha cambiado, porque cada acercamiento se siente como si tuviera que contar.
- Problem: “Has to count”; “contar” reads as “tell” first.
- Suggested: …porque cada acercamiento se siente como si tuviera que salir bien.
- Where: Lesson overlay course 23, `content_23_2_3_2`

### C — minor polish

**C · “El hielo está roto”**
- English: Ice broken.
- Now: El hielo está roto.
- Problem: The idiom is verbal.
- Suggested: Un saludo natural. Se rompió el hielo.
- Where: Scenario `scenario_10_progressive_overload`, `b1000008-0000-0000-0010-000000000008`

**C · “Deja que llegue”**
- English: Let it land.
- Now: Deja que llegue.
- Problem: “Let it land” left vague.
- Suggested: Deja que cale.
- Where: Lesson overlay course 12, `content_12_4_6_1`

**C · “abriendo una ventana”**
- English: She was opening a window to talk about feeling unsettled.
- Now: Estaba abriendo una ventana para hablar de que se siente un poco perdida.
- Problem: Spanish opens a door to a topic.
- Suggested: Estaba abriendo una puerta para hablar de que se siente un poco perdida.
- Where: Lesson overlay course 13, `content_13_2_4_2`

**C · “el lugar ya respondió por ti”**
- English: When you later ask if she's finished with the kettlebells, she responds warmly because the room already vouched for you.
- Now: Cuando más tarde le preguntas si ya terminó con las pesas rusas, te responde con calidez, porque el lugar ya respondió por ti.
- Problem: “The room vouched for you”; a place cannot vouch.
- Suggested: …porque la gente del lugar ya respondió por ti.
- Where: Lesson overlay course 23, `content_23_3_4_2`


## Japanese

Japanese handles set idioms well (七転び八起き, 高嶺の花, じゃんけん, 糸口). The problems are English metaphors carried over image for image. The fixes below are drafts; Japanese has had no native review yet.

### A — reads wrong or changes the meaning

**A · “呼吸を与え”** · 4 strings
- English: Hold the eye contact and let the moment breathe
- Now: 目を合わせたまま、その瞬間にひと呼吸を与える
- Problem: “Let the moment breathe” word for word. A moment cannot be given a breath in Japanese. The quiz already uses 余白 for the same idea.
- Suggested: 「その瞬間に余白を残す」 / 「間を味わう」 — e.g. 目を合わせたまま、間を味わう
- Where: Scenario `scenario_03_fetch_and_flirt`, `c1000010-0000-0000-0003-000000000010` — also rows: Lesson overlay course 4, `content_4_4_6_2`; Lesson overlay course 12, `content_12_4_1_1`; Lesson overlay course 19, `content_19_2_3_1`

**A · “抵抗の少ない道”** · 3 strings
- English: While this can work, keep the ask light so yes is the path of least resistance.
- Now: そうすれば、「はい」が一番抵抗の少ない道になります。
- Problem: “Path of least resistance” word for word.
- Suggested: そうすれば、彼女も気軽に「はい」と言えます。
- Where: Scenario `scenario_15_study_buddy`, `b1000184-0000-0000-0015-000000000184` — also rows: Lesson overlay course 15, `content_15_3_6_2`; Quiz `questions_03_conversational_skills_1`, `1a509b2e-e316-4bf7-a46a-0c9212bf889f/options[0]`

**A · “仕事の半分”**
- English: His life does half the work for him.
- Now: 人生が、仕事の半分を引き受けてくれるからです。
- Problem: Reads as “his life takes over half of his job”.
- Suggested: 魅力の半分は、その生き方が語ってくれます。
- Where: Lesson overlay course 22, `content_22_2_6_2`

**A · “すべてを傾ける”**
- English: When the conversation finds a calm pocket, or she shows a little extra investment, that's when a simple, well-timed line can tilt everything.
- Now: そんなときに、タイミングのいいシンプルなひと言が、すべてを傾けることがあります。
- Problem: 傾ける suggests tipping something over or ruining it (家を傾ける).
- Suggested: …タイミングのいいシンプルなひと言が、流れを一変させることがあります。
- Where: Lesson overlay course 19, `content_19_3_5_1`

**A · “頭の中にいないとき”**
- English: When you're not in your head, you're available to the moment.
- Now: 頭の中にいないとき、人は今この瞬間に開かれています。
- Problem: “Not in your head” word for word.
- Suggested: 頭の中で考え込んでいなければ、目の前の瞬間に向き合えます。
- Where: Lesson overlay course 2, `content_2_4_6_1`

**A · “場所を取”** · 2 strings
- English: Practise being visible. Stand in a room, take up space, speak when you want to, and you will understand that the world is far less focused on you than your mind assumes.
- Now: 部屋の中に立ち、堂々と場所を取り、話したいときに話してみてください。
- Problem: 場所を取る means being bulky or in the way, the opposite of the intended confidence.
- Suggested: 「堂々とその場にいて」 / 「堂々と存在感を示すことに抵抗がない」
- Where: Lesson overlay course 2, `content_2_2_4_1` — also rows: Lesson overlay course 8, `content_8_4_4_2`

### B — understandable, but clearly a translated English image

**B · “出口”** · 3 strings
- English: You gave her an out she didn't ask for.
- Now: 彼女が求めてもいない出口を、差し出してしまいました。
- Problem: “An out” as 出口 (a physical exit). The natural word is 逃げ道, which the quiz already uses for the same idea (“give her an easy out” → 断りやすい逃げ道).
- Suggested: 「彼女が求めてもいない逃げ道を…」「断りやすい逃げ道」
- Where: Scenario `scenario_03_fetch_and_flirt`, `b1000164-0000-0000-0003-000000000164` — also rows: Scenario `scenario_11_trail_talk`, `b1000274-0000-0000-0011-000000000274`; Lesson overlay course 9, `content_9_2_3_2`

**B · “窓を開けていた”**
- English: She was opening a window to talk about feeling unsettled.
- Now: 落ち着かない気持ちについて話すための、窓を開けていたのです。
- Problem: “Opening a window” to a topic is not a Japanese image.
- Suggested: 落ち着かない気持ちについて話す、きっかけを差し出していたのです。
- Where: Lesson overlay course 13, `content_13_2_4_2`

**B · “土を温め”**
- English: A single conversation this week keeps the ground warm for the next one.
- Now: 今週のたったひとつの会話が、次の会話のための土を温めておいてくれます。
- Problem: “Keeps the ground warm” word for word.
- Suggested: 今週のたったひとつの会話が、次の会話への勢いを保ってくれます。
- Where: Lesson overlay course 24, `content_24_2_7_2`

**B · “四方の壁”**
- English: You see the same streets, the same co-workers, the same friends, and the same four walls.
- Now: 同じ道、同じ同僚、同じ友人、同じ四方の壁。
- Problem: “The same four walls” word for word.
- Suggested: 同じ道、同じ同僚、同じ友人、同じ部屋。
- Where: Lesson overlay course 23, `content_23_1_1_1`

**B · “向こう側へ渡った”**
- English: That's when you know you've crossed over.
- Now: それが、向こう側へ渡ったとわかる瞬間です。
- Problem: Can evoke crossing to the other world.
- Suggested: それが、壁を越えたとわかる瞬間です。
- Where: Lesson overlay course 24, `content_24_3_7_2`

**B · “重い章”**
- English: There's time for the heavier chapters once the foundation is strong enough to hold them.
- Now: 重い章を話す時間は、それを支えられるくらい土台がしっかりしてから、ちゃんとあります。
- Problem: “Heavier chapters” word for word.
- Suggested: 重い話をする時間は、土台がしっかりしてから、ちゃんとあります。
- Where: Lesson overlay course 14, `content_14_2_7_2`

**B · “場の空気をあまり引き寄せません”**
- English: This opener doesn't hold the strongest frame.
- Now: この最初のひと言は、場の空気をあまり引き寄せません。
- Problem: “Doesn't hold the strongest frame” turned into an image that does not exist.
- Suggested: この最初のひと言は、あまり強い入り方ではありません。
- Where: Scenario `scenario_14_dressed_to_impress`, `b1000042-0000-0000-0014-000000000042`

### C — minor polish

**C · “橋”** · 6 strings
- English: The second man's story was a bridge to her.
- Now: 二人目の男性のエピソードは、彼女への橋でした。
- Problem: Bare 橋 for a figurative bridge; 架け橋 / 橋渡し is the natural form.
- Suggested: 「彼女への架け橋でした」「次への架け橋に変える」
- Where: Lesson overlay course 14, `content_14_4_4_3` — also rows: Quiz `questions_03_conversational_skills_1`, `d6f93781-4c91-4d3e-835b-28dd4c18773b/explanation`; Lesson overlay course 15, `lesson_15_2.summary`; Lesson overlay course 15, `content_15_2_5_2`; Lesson overlay course 23, `content_23_1_7_1`; Lesson overlay course 2, `content_2_4_5_2`

**C · “ふるいにかけ”**
- English: When you choose the part that mattered, you give her something she can feel rather than something she has to sift through.
- Now: 大事だった部分を選べば、彼女がふるいにかけなければならないものではなく、感じ取れるものを渡せます。
- Problem: “Sift through” word for word.
- Suggested: …彼女が自分で探さなければならないものではなく、感じ取れるものを渡せます。
- Where: Lesson overlay course 14, `content_14_3_5_2`

**C · “内側の足場”**
- English: What feels like rejection is almost always someone protecting their own internal ground.
- Now: 断られたように感じる出来事のほとんどは、誰かが自分の内側の足場を守っているだけです。
- Problem: “Internal ground” word for word.
- Suggested: …誰かが自分の心の安定を守っているだけです。
- Where: Lesson overlay course 1, `content_1_2_3_2`

**C · “中に住む”**
- English: It feels natural because it now lives in your self-image rather than your memory.
- Now: 自然に感じられるのは、それが記憶の中ではなく、自己イメージの中に住むようになったからです。
- Problem: “Lives in your self-image” word for word.
- Suggested: …自己イメージの一部になったからです。
- Where: Lesson overlay course 24, `content_24_3_1_1`

**C · “仕事の半分”**
- English: Recognizing engagement, politeness, and disinterest is only half the job. Now comes the practical part: turning those signals into decisions.
- Now: 乗り気なのか、礼儀なのか、関心がないのかを見分けることは、仕事の半分にすぎません。
- Problem: “Only half the job”.
- Suggested: …見分けることは、まだ道半ばです。
- Where: Lesson overlay course 9, `content_9_2_1_1`


## Same English image, all four languages

One English sentence is a mixed metaphor at source and came out literal everywhere: “avoid crossing any lines she hasn't opened” (`content_9_1_2_2`). Lines are crossed, doors are opened. Suggest rewriting the English to “avoid going further than she has invited”, then retranslating.

“Let the moment breathe” is literal in French (“laisser le moment respirer”, 5 strings) and Spanish (“dejar que el momento respire”, 6 strings) as well. Both are understandable and used in film and music writing, so they are left out of the lists above; a native reviewer may still prefer “laisser un silence” / “dejar una pausa”.

## Applying the fixes

Each string lives in up to five places: `localization/<lang>/catalogs.<lang>.json` and the two `.xcstrings` catalogs for UI; `Wingman/Courses/Lesson Overlays/` for lessons; `localization/<lang>/db/*.json`, `Wingman/Content/question_translations_seed.<lang>.json` and the production Supabase rows for questions and scenarios. Scenario and quiz fixes only reach users once the production rows are updated.
