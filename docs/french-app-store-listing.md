# French App Store listing (Release C): draft

Drafted 2026-11-15 by Claude, modelled on [german-app-store-listing.md](german-app-store-listing.md). It has not been proofread by a native speaker yet. Send it to the proofreader with the review pack (`localization/fr/review/wingman-french-review-pack.xlsx`).

**Status:** draft only. Nothing has been entered in App Store Connect. Nothing has been rendered or uploaded.

**When it goes live:** with the Release C submission, not before. The name, subtitle, description, keywords, screenshots and "What's New" go live with a version. A French page for an English-only app draws *L’app n’est qu’en anglais* reviews. Promotional text can change at any time.

**Where to paste it:** App Store Connect → Wingman.
- **App Information** → the language menu, top right → add **French**. The name and subtitle go here. Add **French (Canada)** as well; see the Canada notes at the end.
- **The new version** → the language menu → French. The description, keywords, promotional text, What's New and screenshots go here.
- **Subscriptions** → the group → each subscription → Localization → French (and French (Canada)).

A script checked the character counts below. Apple's limits are:

| Field | Limit |
|---|---|
| Name | 30 |
| Subtitle | 30 |
| Keywords | 100 |
| Promotional text | 170 |
| Subscription display name | 30 |
| Subscription description | 55 |

**Tone:** the listing uses *tu*, like the app. Many French listings use *vous*. With *tu*, the store page reads like the app the buyer gets. The reviewer may prefer *vous* for the store only; that is a one-line choice (see "Choices to check" below).

**Typography:** French (France) puts a narrow no-break space (U+202F) before `: ; ! ?` and inside `« »`. The text blocks below already contain it. Copy them from this file and don't retype them.

---

## Name (30)

**Recommended:** `Wingman: Aborder une femme` (26)

**Alternative:** `Wingman: Séduction & Confiance` (30)

The English name is "Wingman: Dating & Confidence". In French, as in German, the name and subtitle carry the most search weight, so they should hold what French users type. I checked the French store with Apple's public search on 2026-11-15:
- **"aborder une femme":** one unrelated app (a men's dating app with 0 ratings). This is the plainest description of what Wingman teaches, and nobody owns it.
- **"draguer" / "drague":** many AI "rizz" and pick-up-line apps (Pecho, 760 ratings; Flirtpal; RizzMode…). Ranking there is harder, and the company is the pickup tone the brief rules out. So *draguer* goes in the keywords, not the name.
- **"séduction":** Doro: Coach Séduction IA (164 ratings) and story games.
- **"confiance en soi":** meditation and affirmation apps (Deep Belief, 809; Serenity, 2,241).
- **Another app is already called "Wingman : Coach Rencontres IA"** in the French store (1 rating). Our second half, *Aborder une femme*, keeps the two apart.

## Subtitle (30)

**Recommended:** `Confiance en soi et séduction` (29)

**Alternative:** `Gagne en assurance, ose parler` (30)

If the alternative name *Séduction & Confiance* is chosen, use the alternative subtitle so the words aren't repeated.

## Keywords (100)

```
draguer,drague,flirt,flirter,séduire,timide,rencontre,coach,charisme,conversation,célibataire,date
```

That is 98 characters.
- **Commas only, no spaces.** Words already in the recommended name or subtitle are left out, because Apple combines all three fields. Those words are wingman, aborder, une, femme, confiance, soi and séduction.
- **Both *draguer* and *drague*:** French has no reliable stemming in App Store search, so the verb and the noun both go in.
- **Left out on purpose:**
  - *pickup*, *PUA*, *technique de drague*, *pécho*: this is the pickup-artist tone the brief rules out.
  - *anxiété sociale*, *phobie sociale*: the results there are mental-health apps, and Wingman makes no health claims.
  - *rizz*: this is English slang, and the results are AI pick-up-line apps.
- **If the alternative name is chosen** (*Séduction & Confiance*), *aborder* and *femme* are free again and should replace *date* and *coach*.

## Promotional text (170)

```
Nouveau : Wingman en français. Plus de 100 leçons et scénarios pour t’aider à aborder les femmes avec assurance dans la vraie vie, étape par étape.
```

That is 147 characters. "Plus de 100" counts the 94 lessons and 15 scenarios together, as in the German listing.

## Description (4000)

```
Wingman est une app d’entraînement à la confiance sociale. Elle aide les hommes à aller vers les autres avec assurance dans la vraie vie, grâce à des leçons structurées, une pratique quotidienne et des scénarios à jouer. Tu travailles ton état d’esprit, ta façon de mener une conversation et ta capacité à lire les autres, de façon concrète et durable.

CE QUE TU APPRENDS
• Engager la conversation avec assurance
• Rester calme et présent en société
• Flirter naturellement et créer de l’attirance
• Lire les signaux et y répondre avec justesse

FONCTIONNALITÉS
• Des leçons structurées sur tous les sujets importants
• Des scénarios pour t’entraîner à des situations réelles
• Des exercices quotidiens pour ancrer ce que tu apprends
• Un système de progression pour t’aider à tenir dans la durée

Que tu veuilles plus d’assurance en rencontre, plus d’aisance en société ou simplement engager la conversation plus facilement, Wingman te donne un entraînement que tu peux appliquer tout de suite.

Avec un abonnement, tu as accès à toutes les leçons, tous les scénarios et tous les exercices quotidiens.

Remarque : supprimer l’app ne résilie pas ton abonnement.
Conditions d’utilisation : https://www.getwingman.app/terms
Politique de confidentialité : https://www.getwingman.app/privacy
```

- It follows the live English description and the German draft point for point. It adds no claims and doesn't mention a free trial (there isn't one any more).
- "Rencontre" is used for "dating" (*plus d’assurance en rencontre*). *Dating* stays out of the body text, though it is common in French marketing.

**Open point for the adviser (legal, not guessed):**
- The terms and privacy pages are English only (decision D6). Whether a French listing needs French versions, or a note that the pages are in English, is the same legal question German left open.
- French consumer law (Code de la consommation) and the Loi Toubon on the French language may apply to a paid service sold in France. The reviewer or adviser should say whether the English-only terms are acceptable.

## What's New (this version)

```
Wingman est désormais disponible en français : toutes les leçons, tous les quiz et tous les scénarios. Tu peux changer de langue à tout moment dans les réglages.
```

- *Quiz* is invariable in French, so the plural is *les quiz*.
- *Réglages* matches iOS. The in-app menu is reached from Settings → Language, which the French app shows as *Langue*.

## Subscriptions

| Product | Display name (30) | Description (55) |
|---|---|---|
| Monthly | `Formule mensuelle` (17) | `Accès complet à toutes les leçons et scénarios` (46) |
| Yearly | `Formule annuelle` (16) | `Un an d’accès complet à tous les contenus` (41) |
| `wingman_yearly_discount` | `Formule annuelle` (16) | `Un an d’accès complet à tous les contenus` (41) |

- **Group name:** keep "Wingman Premium" (a brand name, as in German).
- **The display names match the paywall.** The French catalog says *Formule mensuelle* / *Formule annuelle*.
- **The discount product** is still entitlement-mapped and has purchasers. Give it a French name too, but change nothing else about it.

---

## Choices to check

These are also worth a line in the review pack.

- **tu or vous** on the store page. The draft uses *tu*, like the app.
- **Name:** *Aborder une femme* is the plainest search phrase and is uncontested. The reviewer should say whether it reads naturally as an app name or sounds clumsy. The alternative is *Séduction & Confiance*.
- **"draguer" in the keywords.** It is the word French men type, but it leans casual or pickup. Keywords are not shown to users, so it is kept.
- **"date" in the keywords:** it's an anglicism, but it is used in France on dating apps. Swap it for *rendez-vous* if the reviewer prefers.

---

## Screenshots: French text

The German listing worked from the five flat Figma PNGs in `Wingman Automation/Assets/Base #1/`. The same frames need French text. Below is the French for every line, laid out the way the design reads. Images 3 and 4 form one wide picture split in two.

### 1. Dark hero

| English | French |
|---|---|
| Stop overthinking, start connecting (hand-lettered) | Moins réfléchir, plus parler |
| Miss / 100% / of the shots / you don't take | Tu rates / 100 % / des occasions / que tu ne saisis pas |
| Win more shots with wingman | Saisis plus d’occasions avec Wingman |
| Wingman [wing-man] noun | Wingman [wing-man] nom masculin |
| Real world confidence training | L’entraînement à la confiance, dans la vraie vie |

- **The Gretzky line:** the literal *…des tirs que tu ne tentes pas* exists, but *occasions* reads naturally. It also carries into the next line (*plus d’occasions*) the way "shots" does in English, as German did with *Chancen*.
- **100 %:** French puts a narrow no-break space before %, as the app does.
- ***nom masculin*** is how a French dictionary entry is labelled (German used *Substantiv*). The plain *nom* also works.

### 2. Learn

| English | French |
|---|---|
| Learn | Apprends |
| what was never taught | ce qu’on ne t’a jamais appris |
| 100+ structured lessons for real situations and social confidence | Plus de 100 leçons et scénarios pour les situations réelles et la confiance en société |

- **"100+":** the app has 94 lessons and 15 scenarios, so *leçons et scénarios* is the true version, as in German.
- **In the phone**, as the French app shows them:

| English | French |
|---|---|
| Courses | Cours |
| Mindset & Foundations | État d’esprit et bases |
| Approach Mechanics | L’approche en pratique |
| Beliefs & Reframes | Croyances et recadrages |
| Fear & Exposure | Peur et exposition |
| Approach Readiness | Prêt à aborder |
| The Physical Approach | Aller vers elle |

Unlike German, the French category names are translated in the catalog.

### 3 + 4. Practice (wide pair)

| English | French |
|---|---|
| Practice | Entraîne-toi |
| real scenarios | sur des situations réelles |
| Sharpen Social Awareness | Affine ta lecture des autres |
| Built through repetition | Ancré par la répétition |
| Turn knowledge into instinct | Le savoir devient instinct |

**In the phone**, as the French app shows them:

| English | French |
|---|---|
| Coffee Connections | Café et pluie |
| Fetch & Flirt | Chiens et flirt |
| Read Between the Lines | Entre les lignes |
| 2 / 3 / 5 Lessons Required | 2 / 3 / 5 leçons requises |

The French summaries are:
- *Sale temps, café chaud, une table à partager. Un moment tout simple devient une occasion.*
- *Des rires, des regards et deux chiens qui se courent après. Ici, tout se joue dans le choix du moment.*
- *Des livres, du silence et une raison de parler. Mène avec douceur et laisse l’intérêt grandir.*

The card shows three lines. Check on the simulator whether the second summary fits; German's "Kaffee und Regen" summary did not.

### 5. Quiz

| English | French |
|---|---|
| Quiz | Quiz |
| 1. How do you know whether to keep flirting? | 1. Comment savoir s’il faut continuer à flirter ? |
| Trust your gut feeling about the interaction's vibe | Te fier à ton intuition sur l’ambiance de l’échange |
| **Watch how she responds, not how you feel** (highlighted) | **Observer comment elle réagit, pas ce que tu ressens** |
| Look for explicit verbal statements of interest | Attendre qu’elle dise clairement qu’elle est intéressée |
| Assess if the conversation has been going long enough | Évaluer si la conversation dure depuis assez longtemps |
| Daily reps. Lasting confidence | Pratique quotidienne. Confiance durable. |

The quiz lines are exactly what the French app shows for this question (`90e66462…`), so the screenshot matches the app.

## Screenshots: how to make the French set

These are the same steps as German:
1. **Duplicate the five Figma frames** as "FR 1" to "FR 5".
2. **Replace the text layers** with the French above. French runs about 15–20 % longer than English, so headlines 1 and 2 may need a smaller size or a new line break.
3. **Re-letter or drop the hand-lettered line.**
4. **Change the phone contents.**
   - Type the French from the tables above if the phone screens are text layers.
   - Otherwise take fresh French captures on the simulator. Each capture run creates a guest user in production, so it needs Arthur's OK.
5. **Export at 1284 × 2778 and upload** under the French localization.

If you skip step 4, the French page can launch with French captions over English phone screens.

### Header and search banners (HTML)

`marketing/app-store-assets/` holds four HTML banners: `header-a`, `header-b`, `search-a` and `search-b`. French copies sit next to them, with the same layout, styles and art. **They have not been rendered or uploaded.**
- `header-a-fr.html` and `search-a-fr.html`:
  - The headline is *Fini de bloquer. **Ose parler.*** ("Stop freezing. Start talking.").
  - The line under it is *Moins de trac, des conversations plus simples, de vrais liens.*
  - The labels are *Dans ta tête* and *Dans la conversation*.
- `header-b-fr.html` and `search-b-fr.html`:
  - The headline is *Sois celui qui **va lui parler.*** ("Be the guy who walks over.").
  - The line under it is *Prends confiance pour engager la conversation, où que tu sois.*
- The phone images (`src/app-choice.png`, `src/app-courses.png`) are English app captures. A French set needs French captures (same guest-user caveat).
- The headlines are about the same length as the English (28 and 29 characters against 29 and 26), so the sizes are unchanged. Render with `./render.sh` (it renders every `.html` listed in it; add the `-fr` names) and check that nothing wraps badly before uploading.

---

## French (Canada)

App Store Connect treats **French (Canada)** as its own localization. Without it, the Canadian store shows the app's primary language (English) to French-speaking Canadians, even when a French (France) page exists. The app itself has a single French that is shown in Canada too, so the French-Canada page should describe the same app.

**Recommendation:** copy the France text into French (Canada), with these changes.
- **Typography:** Québec style (OQLF) uses a no-break space before `:` and `»`/after `«`, but none before `; ! ?`. The France text with narrow spaces before `; ! ?` is still readable. A Canadian reviewer may want them removed in the store text. (The app keeps the France style, as decided for the catalogs.)
- **Keywords (99):**
  ```
  draguer,cruiser,flirt,flirter,séduire,timide,rencontre,coach,charisme,conversation,célibataire,date
  ```
  - *Cruiser* is the everyday Québec word for chatting someone up; it replaces *drague*.
  - *Date* is very common in Québec French (*une date*).
- **Name and subtitle:** the same works. *Aborder une femme* is understood everywhere.
- **Description and What's New:** no changes needed. The Québec reader sees *réglages* in iOS too.
- **Subscriptions:** the same display names. Prices come from the App Store in the local format (`12,99 $ CA`).
- **Not checked:** competition in the Canadian store. Run the same search with `country=ca` before choosing.

Belgium and Switzerland use the France localization; nothing extra is needed.
