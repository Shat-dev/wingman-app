# Getting paying users to actually use Wingman

Status: complete (2026-11-16). Analysis only; nothing in the app or the database was changed.

Sources: Wingman's Supabase database and PostHog (both read-only), seven session replays of paying users, and the app code on branch `Shat`.

## The short answer

People are not leaving because lessons lack animation. They leave for three reasons, in this order:

1. **The part they enjoy runs out in three minutes.** The one open scenario (Bar Window) is what they engage with. Every other scenario is locked behind reading.
2. **The first lesson is the weakest possible first lesson.** It is 379 words of abstract psychology ("Your mind produces around 60,000 thoughts a day"), revealed over 14 taps, with no picture, no example and nothing to do.
3. **Nothing calls them back.** Subscribers get no reminder unless they find a toggle in Settings.

Per-lesson video would cost the most and address none of the three. The recommended order is at the end.

## What the numbers say

108 real purchases since 1 September (93 trial starts, 50 actually charged).

| Measure | Result |
|---|---|
| Typical (median) payer | 1 lesson, 1 daily practice, 0 scenarios, 2 active days |
| Open any lesson | 80% |
| Finish any lesson | 59% |
| Lesson 1.1: opened / finished | 64 / 43 (67%) |
| Lessons after the first: finish rate | 80–100% |
| Complete anything 1+ days after buying | 30% (charged: 44%) |
| Complete anything 7+ days after buying | 11% (charged: 24%) |
| Complete anything 30+ days after buying | 3% (charged: 5%) |
| Lesson completions that happen on purchase day | 63% |
| Monthly renewers who did anything after renewing | 0 of 13 |
| Encounters logged, all time | 12, by 10 people |
| Payers who ever opened Settings | 13 of 108 |
| Notification permission granted (asked on loading screen since 9 Nov) | 30% (34 of 113) |

Two things stand out. Once someone is past the first lesson, lessons hold them (80–100% finish). And finishing two or more lessons on day one is the only first-day behaviour that predicts coming back (59% return, against 31% for exactly one lesson).

## What the replays show

Seven paying users who opened a first lesson and did not finish it.

| User | What happened |
|---|---|
| AU, 8 Nov | Rushed onboarding, bought the 50% offer, opened lesson 1.1, looked at one screen for about 3 seconds, left. |
| US, 8 Nov | Read lesson 1.1 slowly for 97 seconds, got to about 40%, left. |
| US, 26 Oct | Browsed Scenarios (all but one locked), opened lesson 1.1, backed out, came back, read 144 seconds to about 90%, left before the quiz. Finished it on a later visit. |
| US, 4 Nov | Finished daily practice, opened lesson 1.1, sat on the first page about 3 minutes, restarted, reached about 60% after 4.5 minutes, left. |
| GB, 4 Nov | Finished Bar Window, scrolled the locked scenario list, replayed Bar Window, scrolled the locked list again, opened lesson 1.1 and left at once. Opened lesson 1.1 six times in total and never finished it. |
| US, 24 Oct | Played Bar Window twice, opened lesson 1.1, read one paragraph, left. |
| US, 4 Nov | Swiped through all five modules, went to Flirting & Chemistry, hit "Complete all lessons in Compliments & Verbal Chemistry to unlock", opened the one open lesson, read 28 seconds, left. |

What this adds to the numbers:

- **They are reading, not bouncing.** Three of the seven spent 1.5 to 4.5 minutes in a "3 min" lesson and still did not reach the end.
- **They want more scenarios.** Two went looking for the next scenario, found padlocks, and only then tried a lesson.
- **They go looking for their own topic and hit locks.** A paying user sees mostly padlocks: lessons unlock one by one, courses unlock only after the previous course, scenarios unlock by lesson count (1, 2, 3, 5, 7, 10 … 40).
- Three recordings end just after the App Store rating request fired, right as the first lesson opened. This is unconfirmed, but the request may be landing on top of the first lesson.

## How the lessons are built today

- 94 lessons, all the same: plain paragraphs, nothing else. Median 353 words, 6 screens, 14 taps, then a short quiz.
- No image, no example to react to, no choice to make, no audio, no "try this today".
- Onboarding asks what the user wants to improve and then shows "Personalizing your lessons", but nothing is personalised. Everyone gets the same Home with Mindset & Foundations first.
- XP, levels and a streak already exist. They have not made people return, because nothing shows them to a user who has closed the app.

## Everything we could do

Effort: S = days, M = one to two weeks, L = a month or more.

### Quick wins

| # | Change | Why | Effort |
|---|---|---|---|
| 1 | **Reminders for subscribers, on by default.** A daily nudge at the hour they usually open the app, a "streak ends tonight" nudge, and day 2 / 3 / 7 win-back messages for people who have gone quiet. | Today a subscriber gets nothing. This is the only channel that reaches someone who has left. | S |
| 2 | **Ask for notification permission at a better moment.** After the first completed activity ("Want a nudge tomorrow to keep your streak?") instead of on the loading screen. | Only 30% say yes on the loading screen, before they have seen any value. | S |
| 3 | **Open more scenarios to payers.** For example the first three open at once, then one more per lesson. The unlock numbers live in the database (`scenarios.required_lessons_completed`), so this needs no app release. | Scenarios are what people enjoy and replay. Locking 14 of 15 hides the best part of the product from people who paid for it. | S |
| 4 | **Start with a different first lesson.** Lead with something concrete (an opener, a real situation) and move "You are not your thoughts" later, or rewrite its first screen around a scene instead of a statistic. | 67% finish lesson 1.1 against 80–100% for later lessons. | S |
| 5 | **Start each user in the module they asked for.** Use the onboarding answer to decide which module is first on Home and which lesson "Continue" points to. | Onboarding promises personalised lessons and delivers none. | S |
| 6 | **Hand off from lesson to scenario.** The lesson-complete screen should offer the scenario that lesson just unlocked, and the scenario-complete screen should offer the next lesson. | Getting to two completions on day one is the one behaviour linked to returning. | S |
| 7 | **Move the rating request** so it cannot fire just before a first lesson. | It interrupts at the exact point where people drop. | S |
| 8 | **Record lesson progress.** Add an event per lesson screen and when the app goes to the background. | Today there is no way to see where in a lesson people stop without watching replays. | S |

### Medium

| # | Change | Why | Effort |
|---|---|---|---|
| 9 | **Make lessons interactive instead of animated.** Every two or three paragraphs, a "what would you do?" choice with feedback, reusing the scenario and quiz components. One line-art illustration per lesson, a key-takeaway card, and a "try it today" action at the end. Cut each lesson to about 200 words. | Gives the lesson the same back-and-forth as the scenario people like, at a fraction of the cost of video. | M (build once, then rewrite lessons course by course) |
| 10 | **Audio narration.** A listen button on every lesson, generated from the existing text. | Onboarding already sells "lessons you can do on your commute". Much cheaper than video and covers all 94 lessons at once. | M |
| 11 | **A daily plan instead of a catalogue.** Home shows "Today: one lesson, one scenario or practice, one real-world mission, about 5 minutes" as a single path, rather than five modules of padlocked courses. | Removes the choice and the locks; gives a clear finish line each day. | M |
| 12 | **Real-world missions.** A small dare each day or week ("say hi to one stranger") that ends in the encounter log and pays XP. | The product promise is real approaches, yet the log has 12 entries ever. This is also the only content that never runs out. | M |
| 13 | **Streak that forgives.** A weekly goal (3 days a week), a streak freeze, and milestones that unlock a scenario. | A daily streak breaks on day two for most people and then stops mattering. | M |
| 14 | **A new scenario every week,** announced by notification. | Gives lapsed subscribers a specific reason to open the app. Fifteen scenarios is a small library. | M (ongoing content) |
| 15 | **Home-screen widget** showing streak and today's task. | A reminder that does not depend on notification permission. | M |

### Large bets

| # | Change | Why | Effort |
|---|---|---|---|
| 16 | **Open-ended role-play.** Chat (later voice) with a character in a scenario, with coaching feedback afterwards. | The scenario format taken to its conclusion; practice that never repeats. Running cost per conversation and content safety both need care. | L |
| 17 | **Video or animation for every lesson.** | See below. | L |

### On video and animation

Not recommended now. It is 94 productions, it would need redoing in German, Spanish and French, and the data does not point at it: lessons after the first already finish at 80–100%, so lesson format is not what stops people who get going. The losses are at the first lesson and overnight. If you want to test the idea cheaply, make one 30–45 second animated intro for the first lesson of each of the five modules and compare first-lesson completion before and after.

### Things to skip for now

- Leaderboards and friend features: with about 100 payers they would look empty.
- More XP, badges or levels on their own: these already exist and are invisible to anyone who has closed the app.

## Recommended order

1. **First release:** items 1–8. Small, and aimed at the two measured drops (first lesson, next day). Item 3 can go live the same day as a database change.
2. **Second release:** interactive lessons for the first course only (five lessons) plus audio, compared against the current format. Daily plan on Home.
3. **Third release:** missions and the forgiving streak.
4. **Later:** weekly scenarios, widget, then role-play if the earlier steps show that more practice content is what holds people.

## What to measure

| Measure | Now | Aim |
|---|---|---|
| Finish lesson 1 among those who open it | 67% | 85% |
| Two or more completions on purchase day | 37% | 50% |
| Complete anything 1+ days after buying | 30% | 45% |
| Complete anything 7+ days after buying | 11% | 20% |
| Renewers active after renewal | 0 of 13 | more than half |
| Notification permission granted | 30% | 50% |

## Limits of this analysis

- Small samples: 108 payers, seven replays. Treat percentages as rough.
- Most of these payers started on a free trial, which was removed on 10 November. Direct purchasers return more (40% seen a week later, 4 of 10), so new cohorts may look somewhat better without any change.
- Test accounts were not filtered out of the database counts.
- Reading time for people who quit a lesson is only known from the replays; the app does not record it yet (item 8).
