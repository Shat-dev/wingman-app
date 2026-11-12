# German App Store listing (G9): draft

Drafted 2026-11-12 by Claude. Not proofread by a native speaker yet. Send it to the proofreader together with the review pack (checklist step 1).

**When it goes live:** with the Release B submission, not before. Name, subtitle, description, keywords, screenshots and "What's New" go live with a version. A German page for an English-only app draws "App ist nur auf Englisch" reviews. Promotional text can change at any time.

**Where to paste it:** App Store Connect → Wingman.
- **App Information** → the language menu, top right → add **German**. This is where the name and subtitle go.
- **The new version** → the language menu → German. This is where the description, keywords, promotional text, What's New and screenshots go.
- **Subscriptions** → the group → each subscription → Localization → German.

Character counts below were checked with a script. Apple's limits: name 30, subtitle 30, keywords 100, promotional text 170, subscription display name 30, subscription description 55.

---

## Name (30)

**Recommended:** `Wingman: Frauen ansprechen` (26)

Alternative: `Wingman: Flirten & Mut` (22)

The English name is "Wingman: Dating & Confidence". In German, the name and subtitle carry the most search weight, so they should hold what Germans type.
- **"Frauen ansprechen"** is the plainest description of what the app teaches. In the German store, only two tiny apps show up for it (3 and 1 ratings), so Wingman could rank for it.
- **"Flirten lernen"** and **"Flirt"** are owned by dating apps like LOVOO, Tinder and Jaumo. That's why "flirten" sits in the subtitle and not the name.
- **Another app is already called "Wingman: AI Dating Coach"** in the German store (3 ratings). A different second half keeps the two apart.

## Subtitle (30)

**Recommended:** `Selbstbewusst flirten lernen` (28)

Alternative: `Mehr Selbstvertrauen im Alltag` (30)

## Keywords (100)

```
dating,coach,selbstvertrauen,schüchtern,smalltalk,kennenlernen,date,charisma,ausstrahlung,männer
```

95 characters.
- **Commas only, no spaces.** Words already in the name or subtitle (wingman, frauen, ansprechen, selbstbewusst, flirten, lernen) are left out, because Apple combines all three fields.
- **Left out on purpose:**
  - "verführen", "aufreißen", "pickup": these are the pickup-artist tone the brief rules out.
  - "angst", "soziale angst": the results there are mental-health apps, and Wingman makes no health claims.

## Promotional text (170)

```
Neu: Wingman auf Deutsch. Über 100 Lektionen und Szenarien, die dir helfen, Frauen im echten Leben selbstbewusst anzusprechen – Schritt für Schritt.
```

148 characters. "Über 100" counts the 94 lessons and 15 scenarios together (see the screenshot note below).

## Description (4000)

```
Wingman ist eine Trainings-App für soziales Selbstvertrauen. Sie hilft Männern, im echten Leben souverän auf andere zuzugehen: mit strukturierten Lektionen, täglichem Üben und Szenarien zum Durchspielen. Du arbeitest an deinem Mindset, deiner Gesprächsführung und deinem Gespür für andere – praktisch und so, dass es sitzt.

DAS LERNST DU
• Gespräche selbstbewusst beginnen
• In sozialen Situationen ruhig und präsent bleiben
• Natürlich flirten und Anziehung aufbauen
• Signale lesen und passend reagieren

FUNKTIONEN
• Strukturierte Lektionen zu allen wichtigen Themen
• Szenarien, in denen du echte Situationen übst
• Tägliche Übungen, damit das Gelernte bleibt
• Ein Fortschrittssystem, das dir hilft dranzubleiben

Ob du beim Dating selbstbewusster werden, sozial sicherer auftreten oder einfach leichter ins Gespräch kommen willst: Wingman gibt dir ein Training, das du sofort anwenden kannst.

Mit einem Abo bekommst du vollen Zugang zu allen Lektionen, Szenarien und täglichen Übungen.

Hinweis: Wenn du die App löschst, wird dein Abo nicht gekündigt.
Nutzungsbedingungen: https://www.getwingman.app/terms
Datenschutzerklärung: https://www.getwingman.app/privacy
```

This follows the live English description point for point. It adds no claims, and it doesn't mention a free trial, since there isn't one any more.

**Open point for the adviser (checklist step 2):** the terms and privacy pages are English only (decision D6). Whether a German listing needs German versions of them, or a note that they're in English, is a legal question. I haven't guessed at it.

## What's New (this version)

```
Wingman gibt es jetzt auf Deutsch: alle Lektionen, Quizze und Szenarien. Die Sprache kannst du jederzeit in den Einstellungen ändern.
```

## Subscriptions

| Product | Display name (30) | Description (55) |
|---|---|---|
| Monthly | `Monatsabo` | `Voller Zugang zu allen Lektionen und Szenarien` (46) |
| Yearly | `Jahresabo` | `Ein Jahr voller Zugang zu allen Inhalten` (40) |
| `wingman_yearly_discount` | `Jahresabo` | `Ein Jahr voller Zugang zu allen Inhalten` (40) |

- The names match the paywall ("Monatsabo", "Jahresabo").
- The discount product is still entitlement-mapped and has purchasers. Give it a German name too, but don't change anything else about it.

---

## Screenshots: German text

The five images in `Wingman Automation/Assets/Base #1/` are flat PNGs (1284 × 2778). Below is the German for every line, laid out the way the design reads. Images 3 and 4 form one wide picture split in two.

### 1. Dark hero

| English | German |
|---|---|
| Stop overthinking, start connecting (hand-lettered) | Weniger grübeln, mehr reden |
| Miss / 100% / of the shots / you don't take | Du verpasst / 100 % / der Chancen, die / du nicht nutzt |
| Win more shots with wingman | Nutze mehr Chancen mit Wingman |
| Wingman [wing-man] noun | Wingman [wing-man] Substantiv |
| Real world confidence training | Selbstvertrauen trainieren – im echten Leben |

- **The Gretzky line:** the literal "…der Schüsse, die du nicht abgibst" exists in German, but "Chancen" reads naturally. It also carries over into the next line ("mehr Chancen") the way "shots" does in English. The huge "100 %" stays the visual anchor. German puts a space before %, as in the app.
- **Capital W:** "Wingman" is capitalised, since German capitalises nouns and the brand.

### 2. Learn

| English | German |
|---|---|
| Learn | Lerne |
| what was never taught | was dir nie jemand beigebracht hat |
| 100+ structured lessons for real situations and social confidence | 100+ Lektionen und Szenarien für echte Situationen und mehr Selbstvertrauen |

- **Check the "100+" claim:** by my count the app has **94 lessons** (25 courses, from the lesson files) plus **15 scenarios**. "100+ lessons" isn't quite true; "100+ Lektionen und Szenarien" is. The English screenshot has the same issue.
- **In the phone:**

| English | German |
|---|---|
| Courses | Kurse |
| Mindset & Foundations, Approach Mechanics | stay English: category names are never translated |
| Beliefs & Reframes | Überzeugungen & neue Perspektiven |
| Fear & Exposure | Angst & Konfrontation |
| Approach Readiness | Bereit zum Ansprechen |
| The Physical Approach | Die Annäherung |

### 3 + 4. Practice (wide pair)

| English | German |
|---|---|
| Practice | Übe |
| real scenarios | echte Situationen |
| Sharpen Social Awareness | Schärf dein Gespür für andere |
| Built through repetition | Gefestigt durch Wiederholung |
| Turn knowledge into instinct | Aus Wissen wird Instinkt |

**In the phone**, as the German app shows them:

| English | German |
|---|---|
| Coffee Connections | Kaffee und Regen |
| Fetch & Flirt | Hund & Flirt |
| Read Between the Lines | Zwischen den Zeilen |
| 2 / 3 / 5 Lessons Required | 2 / 3 / 5 Lektionen erforderlich |

The scenario summaries in the mockup ("Great views, calm energy…") are older than the app's current text. The German app shows: „Mieses Wetter, warmer Kaffee, ein Tisch für zwei. …“, „Lachen, Blickkontakt und zwei Hunde, die sich jagen. …“, „Bücher, Stille und ein Grund zu reden. …“

### 5. Quiz

| English | German |
|---|---|
| Quiz | Quiz |
| 1. How do you know whether to keep flirting? | 1. Woran erkennst du, ob du weiterflirten solltest? |
| Trust your gut feeling about the interaction's vibe | Deinem Bauchgefühl zur Stimmung vertrauen |
| **Watch how she responds, not how you feel** (highlighted) | **Darauf achten, wie sie reagiert, nicht wie du dich fühlst** |
| Look for explicit verbal statements of interest | Auf ausdrückliche Worte achten, dass sie Interesse hat |
| Assess if the conversation has been going long enough | Einschätzen, ob ihr schon lange genug redet |
| Daily reps. Lasting confidence | Täglich üben. Dauerhaft selbstbewusst. |

The quiz lines are exactly what the German app shows for this question, so the screenshot matches the app.

## Screenshots: how to make the German set

The PNGs were exported from **Figma** (the files carry `Software: Figma`). That makes the job simple:

1. **Copy the frames.** In Figma, duplicate the five frames and name the copies "DE 1" to "DE 5".
2. **Change the words.** Replace each text layer with the German above. Keep the fonts and the layout. German runs about 30 % longer, so expect to shrink a size or move a line break in the headlines (images 1 and 2 most of all).
3. **Redo the hand-lettering.** "Stop overthinking, start connecting" is hand-lettered. Re-letter it, set it in a handwriting font, or drop it from the German set.
4. **Change the phone contents.**
   - **If the phone screens are text layers** (they look redrawn: clean 9:41 bar, crisp text), type the German from the tables above.
   - **If they're pasted images**, Claude can take fresh German captures on the iPhone 17 Pro simulator, with the status bar fixed at 9:41.
   - **Only the app's language changes.** Language is set inside the app (Settings → language, or a launch argument), so the simulator's iOS stays English. iOS itself shows no words in these screens anyway, only "9:41" and icons.
   - **Each capture run creates a guest user in production**, so it needs your OK.
5. **Export and upload.** Export at the same size (1284 × 2778). Upload them in App Store Connect under the German localization of the version.

**If you skip step 4:** the German page can go live with German captions over English phone screens. That's acceptable for a first launch. The captions are what people read in search results.

**If you upload no German screenshots at all:** the German page falls back to the English ones.
