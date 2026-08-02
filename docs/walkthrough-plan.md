# First-Run Walkthrough — Implementation Plan

**Supersedes §3, §4, §6 and §7 of `demo-then-wall-plan.md`.** Phases 1-3 of that
document are built and unchanged; this plan is what fills the gap its phasing
table calls "4, 6, 7". Read `anonymous-auth-plan.md` first — guest sessions are a
prerequisite, and they changed what the walkthrough can assume.

Verified against branch `Shat`, 2026-08-01. Line numbers from state at time of
writing.

---

## The flow

```
Landing → Skip for now → guest session
  → onboarding quiz → RatingPromptView → Paywall #1 (dismissible)
      → purchased → post-purchase account ask → full app
      → dismissed → MainTabView, branch 4b          ← WALKTHROUGH STARTS HERE
          1. mascot: welcome + what Wingman is for
          2. scenario 1 — required, interactive, no skip
          3. mascot: congratulations → walks them to Courses, they browse
          4. mascot: what they get if they stay
          5. markFreeDemoCompleted()
      → post-demo paywall (branch 4c, dismissible)
          → purchased → full app
          → dismissed → branch 4d: gated app + ONE free lesson waiting
```

**The one design constraint, unchanged:** the walkthrough ends *with the ask*.
Peak intent is the moment the demo finishes, not whenever the user later happens
to tap something.

---

## 0. What changed from the original plan, and why

Five corrections. Each one is load-bearing.

### 0.1 The demo is a script, not a mode — so Phase 4 mostly disappears

The original Phase 4 specified a persistent "demo mode": scenario locking in
`PracticeService`, a `.demoMode` case on `CourseLockReason`, forced lesson locks
in `CourseDetailSheet`, and a disabled treatment on daily practice. That design
followed from the demo being *a state the user lives in* while they spend one
scenario and one lesson at their own pace, across launches.

Under the revised intent the walkthrough is a single linear ~90-second script.
The user is never wandering the app "in demo mode" — they are being walked
through one thing at a time. So what is needed is **interception during the
script**, not a second lock language across three surfaces.

Concretely: no `.demoMode` case, no changes to `CoursesViewModel`, no changes to
`PracticeService.fetchPractices`. Off-script taps route to a mascot line instead
of a paywall or a lock icon. This is the single biggest scope reduction in this
plan, and it removes the risk the original plan flagged at review — "if it drifts
into pointing at tab-bar chrome it becomes a generic coach-mark tour."

### 0.2 Scenario 1 is permanently free — no state required

The original plan gated the demo scenario on demo mode being active. That needs a
flag, and it breaks for a user who force-quits mid-walkthrough and comes back.

Simpler rule: **`order_index == 1` is free for everyone, forever.** One condition,
no persistence, no resume logic, and an abandoner can always pick up where they
left off.

Cost of being generous here is zero. `scenarios`, `scenario_screens` and
`screen_options` are already readable with the publishable key hardcoded at
`SupabaseManager.swift:22` (verified against `pg_policies`) — the gate is a
monetisation construct, not a data boundary.

Consequence worth stating: after the walkthrough, replaying scenario 1 stays free
rather than becoming a paywall trigger. That is the deliberate trade for deleting
a flag and a resume path.

### 0.3 The free lesson moves after the walkthrough, and is claimed per-lesson

The original demo spent one scenario **and** one lesson. The revised intent keeps
lessons browse-only during the walkthrough and hands out one free lesson
afterwards.

Placement decision — **the free lesson sits on the far side of the post-demo
paywall**, not before it:

- Peak intent is the end of the walkthrough. Branch 4c is already built to catch
  it, so this needs zero routing changes.
- If the free lesson came first, a user who never opens a lesson never sees the
  ask at all.
- As a consolation after dismissal the free lesson does more work: it keeps a
  non-buyer in the app, and finishing it is a natural second paywall trigger
  through the existing feature gate.

Mechanism — **claimed, not counted.** A `freeLessonId` records which lesson the
user spent it on. First lesson opened claims it; that lesson stays open forever
after. A plain "spend on open" counter punishes someone who opens a lesson and
immediately backs out; a "spend on completion" counter lets them read every lesson
in the app without finishing one.

### 0.4 Existing users must not be dropped into a welcome tour

`hasCompletedFreeDemo` defaults `false` for the entire pre-update install base, so
without a suppression rule every existing non-paying user gets "Welcome to
Wingman! Let's do your first scenario" on first launch after the update —
possibly a scenario they finished weeks ago.

Two layers, both cheap:

1. **At flag load.** In `checkUserFreeDemoStatus`, if
   `LessonDataService.shared.totalLessonsCompleted() > 0`, mark the demo spent
   silently (in-memory and per-user key; no `user_metadata` write, so it stays a
   local repair rather than a claim about the account). This is synchronous and
   local — no extra network hop on the launch path.
2. **At the coordinator.** If scenario 1 already reads `isCompleted` from
   `user_scenario_progress`, skip step 2 and jump to step 3. This catches the
   scenario-only user that layer 1 misses, and it doubles as the abandonment
   resume path.

Deliberately progress-based, not date-based. A user who signed up months ago and
never engaged *should* get the walkthrough; a `createdAt` cutoff would deny it to
exactly the cohort it would help most.

### 0.5 The mascot overlay must not draw over the scenario

The overlay belongs in `MainTabView`'s `ZStack` ([MainTabView.swift:26](../Wingman/Home/MainTabView.swift)),
which sits above the `TabView`. `PracticeGame` and `LessonView` are pushed
*inside* that `TabView`'s navigation stacks, so an unguarded overlay renders on
top of them.

`TabBarVisibilityManager` already tracks exactly this: both screens call
`hideTabBar()` on appear. **Render the overlay only when
`tabBarVisibility.isVisible`** — it is the existing, already-correct signal for
"the user is on a tab surface, not inside content."

---

## 1. Access rules

The three gates today are a binary `hasActiveSubscription` check:

| Surface | Site | Today |
|---|---|---|
| Scenario tap | `PracticeView.swift:137` | subscription or paywall |
| Lesson tap | `CourseDetailSheet.swift:125` | subscription or paywall |
| Daily practice | `HomeView.swift:138` | subscription or paywall |

They become:

| Surface | Rule |
|---|---|
| Scenario, `orderIndex == 1` | **always open** |
| Scenario, any other | subscription, else paywall (unchanged) |
| Lesson | subscription **or** free-lesson credit, else paywall |
| Daily practice | subscription, else paywall (unchanged) |
| Approach logging | free (unchanged) |

Plus one rule that applies only while the script is running:

| Condition | Behaviour |
|---|---|
| Walkthrough active, tap is off-script | mascot nudge — **never** a paywall, never a lock icon |

The off-script rule is presentation-level and lives in the tap handlers next to
the existing gate checks. Nothing enters `PracticeService`, `CoursesViewModel` or
`CourseLockReason`.

### Why the gate checks read from `AuthManager`

`AuthManager` is a single `@StateObject` in `WingmanApp` injected as an
environment object — there is no `AuthManager.shared`. `PracticeViewModel` and
`CoursesViewModel` therefore cannot read it, which is the second reason the lock
logic stays in the views rather than the view models.

All three gate sites already hold `@EnvironmentObject var authManager`. The new
conditions go on `AuthManager` as computed properties, next to the existing
`effectivePaywallFlowCompleted` / `hasSession` / `shouldShowPostPurchaseAccountAsk`
(`AuthManager.swift:282-297, 451-453`):

```swift
/// Scenario 1 is free for everyone, forever — see §0.2.
func canOpenScenario(orderIndex: Int) -> Bool {
    hasActiveSubscription || orderIndex == 1
}

/// One lesson, claimed by id on first open — see §0.3.
func canOpenLesson(id: String) -> Bool {
    if hasActiveSubscription { return true }
    guard hasCompletedFreeDemo else { return false }   // credit is post-walkthrough
    return freeLessonId == nil || freeLessonId == id
}
```

---

## 2. State

One new persisted value. Same shape as `hasCompletedFreeDemo` —
per-user `UserDefaults` as the device source of truth, best-effort
`user_metadata` mirror so a reinstall or new device doesn't hand out a second
one, loaded on every session path, reset on sign-out and account deletion.

> **Correction, found while implementing W1.** This section originally said
> "all three session paths (`.signedIn`, `.initialSession`,
> `restoreSessionGracefully`)", inherited from `demo-then-wall-plan.md`. There
> are **five**: those three plus `loadGuestUserState(userId:)` and
> `promoteGuestToPermanent(session:)`, both added by the anonymous-auth work.
> Missing either would have been silent and cohort-specific — guests (the
> majority path) would read `nil` on every launch and could re-claim the credit
> indefinitely, and a guest who linked an account would lose their claim at the
> moment of linking. All five are wired.

| Value | Type | Meaning |
|---|---|---|
| `freeLessonId` | `String?` | Lesson that claimed the free credit. `nil` = unclaimed. |

Mirror key: `free_lesson_id`. Setter: `claimFreeLesson(id:)`, mirroring
`markFreeDemoCompleted()` (`AuthManager.swift:1884`) exactly.

**`hasCompletedFreeDemo` keeps its name and its persistence, but its meaning
narrows.** It now records "walkthrough finished" — one scenario, no lesson. The
doc comment at `AuthManager.swift:86` and `:1876` says "1 scenario + 1 lesson"
and must be corrected in the same commit, or the next reader will infer a lesson
credit that lives somewhere else entirely.

No `hasSpentFreeLesson` boolean: `freeLessonId != nil` answers it, and the id is
what makes re-entry work.

---

## 3. The coordinator

`Walkthrough/WalkthroughCoordinator.swift` — `ObservableObject`, `@StateObject` in
`MainTabView` beside `coursesRouter` / `tabBarVisibility`
([MainTabView.swift:20-22](../Wingman/Home/MainTabView.swift)), injected via
`.environmentObject` into all four tabs so state survives tab switches and
navigation pushes.

### Steps

```
welcome
  → scenarioPrompt        mascot points at Scenarios; tab switch is driven, tap is the user's
  → scenarioRunning       overlay hidden (tab bar hidden)
  → scenarioDone          congratulations
  → lessonsTour           driven tab switch to Courses; user scrolls freely
  → benefits              the pitch
  → finished              → markFreeDemoCompleted() → RootView routes to 4c
```

`welcome` is entered on first appearance when
`!authManager.hasCompletedFreeDemo && !authManager.hasActiveSubscription`.
Otherwise the coordinator initialises straight to `finished` and never renders.

### Advancement

Hooks existing completion points rather than new ones:

- `scenarioRunning → scenarioDone`: `PracticeGame` already sets
  `viewModel.gameCompleted` and captures `practice_scenario_completed`
  (`PracticeGame.swift:307-320`). The coordinator observes the same transition.
  Its `GameCompleteView` dismiss (`:322-325`) returns the user to `PracticeView`,
  which is where the mascot reappears.
- `lessonsTour`: advanced by the user tapping the mascot's Continue, not by any
  lesson action. Browsing is explicitly not instrumented as a step — the user is
  told to look, not to do.

### Driving navigation

`selectedTab` is private `@State` in `MainTabView` ([MainTabView.swift:20](../Wingman/Home/MainTabView.swift)).
Bind it through the coordinator (`@Published var requestedTab: Int?`) rather than
adding a second notification name — `NavigateToHomeView` (`:57`) is a one-way
"go home" signal and does not generalise.

For the lessons beat, `CoursesRouter.open(categoryId:courseId:)`
([CoursesRouter.swift](../Wingman/Home/CoursesRouter.swift)) already exists for
deep-linking into a category and scrolling to a course. Reuse it; do not
reimplement scrolling.

### Off-script interception

While the coordinator is not `finished`, these taps call
`coordinator.nudge(_:)` instead of their normal action:

| Tap | Nudge |
|---|---|
| Lesson card | "Lessons come next — your first one's on me." |
| Daily practice | "One thing at a time. Finish the scenario first." |
| Any scenario other than #1 | "This one's locked until you've got the basics." |

A nudge shows a mascot line and nothing else. **No paywall may be presented while
the walkthrough is running** — an interrupting purchase screen during the sell is
the single worst thing this feature could do.

### Abandonment

Force-quit mid-walkthrough leaves `hasCompletedFreeDemo == false`, so the user
re-enters at branch 4b and the coordinator restarts at `welcome`. Restarting is
deliberate (the welcome is 15 seconds and the user has seen nothing else), with
one exception: §0.4 layer 2 skips step 2 when scenario 1 is already complete, so
nobody is ever asked to replay a scenario they finished.

---

## 4. The mascot overlay

`Walkthrough/MascotOverlayView.swift`, layered into the `ZStack` at
`MainTabView.swift:26` **above** the tab bar.

- Dimmed scrim over the app at reduced opacity, mascot + speech bubble above it.
  The app stays visible behind — the point is to show them the thing they're
  buying, not to cover it.
- Tap-to-advance on the bubble. No skip control on steps 1-4 (`scenarioPrompt`
  requires the real tap; the rest are read-and-continue).
- **Rendered only when `tabBarVisibility.isVisible`** — see §0.5.
- Respect `.appDynamicTypeCeiling()`, as every other full-screen surface in the
  app does.

### Art — precondition, not a detail

The only candidate asset in the project is
`Assets.xcassets/ScenariosScreen/scenario_user.imageset`, which is scenario
game art, not a mascot. **Confirm the mascot art before this phase starts.**
Building the overlay against a placeholder is fine; shipping it against
`scenario_user` is not.

---

## 5. Copy

Drafts, in the voice already established by `AppStrings.Onboarding` — plain,
outcome-first, no jargon.

**1. Welcome** (2 beats, tap through)

> "Hey — I'm your wingman. Most guys don't freeze because they're bad with women.
> They freeze because they've never practised."
>
> "So that's what this is. Real conversations you can get wrong safely, until
> getting them right stops feeling like luck. Let me show you."

**2. Scenario prompt**

> "Start here. She's at the bar, you've got an opening. Play it out — there's no
> wrong answer you can't take back."

**3. Congratulations**

> "That's it. That's the whole skill — read the moment, pick your line, adjust.
> You just did it once. Do it fifteen more times and it's who you are."

**4. Lessons tour**

> "The scenarios get easier because of these. Mindset, opening, flirting,
> escalation — short lessons, each one feeding the next. Have a scroll."

**5. Benefits, before the ask**

> "Here's what's waiting: 15 scenarios, 40+ lessons, daily practice to keep you
> sharp, and a log of every real approach you make so you can watch yourself get
> better. Your first lesson is on me either way."

That last line is doing specific work: it pre-frames the paywall that lands one
beat later as an *offer* rather than a wall, and it makes the free lesson a
promise the user has already been given rather than a consolation prize
discovered after a dismissal.

---

## 6. Routing — what changes

**Nothing structural.** Branches 4a-4d in `RootView`
([WingmanApp.swift:258-308](../Wingman/WingmanApp.swift)) are already correct:

- 4a catches subscribers before 4b, so a paywall-#1 buyer never sees the
  walkthrough.
- 3b catches the guest subscriber for the account ask before either.
- 4b is the walkthrough's home and is reached by guests (it keys off
  `hasSession`, not `isAuthenticated`).
- `markFreeDemoCompleted()` — which today has **zero call sites**, making 4c
  unreachable in production — gets its one caller at `finished`.

### Known behaviour, accepted

4b and 4d both render `MainTabView()` in different `if/else` arms, so SwiftUI
gives them separate identities and rebuilds the whole tab view when the demo
completes and again when the post-demo paywall is dismissed. This is the same
identity trap documented for `LandingView` at `WingmanApp.swift:164-192`.

Accepted, not fixed: it happens exactly once per user, and landing back on Home
after the walkthrough is a reasonable place to land. If it reads badly in
testing, the fix is to hoist `MainTabView` into a single branch and present the
post-demo paywall as a non-dismissible `fullScreenCover` over it — but that trades
a route for a presentation, which is what the original plan deliberately avoided.
Do not do it speculatively.

---

## 7. Analytics

Add to `Analytics.Event` ([Analytics.swift:23](../Wingman/Util/Analytics.swift)):

```
walkthrough_started
walkthrough_step_viewed      { step: welcome | scenarioPrompt | scenarioDone | lessonsTour | benefits }
walkthrough_nudge_shown      { surface: lesson | dailyPractice | lockedScenario }
walkthrough_abandoned        { step, duration_seconds }
walkthrough_completed        { duration_seconds }
walkthrough_suppressed       { reason: existingProgress | scenarioAlreadyComplete }
free_lesson_claimed          { lesson_id, course_id }
free_lesson_completed        { lesson_id, course_id }
```

`practice_scenario_started` / `practice_scenario_completed` already fire from
`PracticeGame` and need no walkthrough-specific duplicate — add a
`during_walkthrough: true` property instead so one event serves both funnels.

`PaywallSource.postDemo` already exists. `walkthrough_suppressed` is not
housekeeping: without it, §0.4 makes a silent decision for a chunk of the install
base and the funnel denominator is wrong with no way to tell.

### The funnel

```
paywall#1_dismissed → walkthrough_started → walkthrough_step_viewed(scenarioDone)
                    → walkthrough_completed
                    → paywall_viewed(source=postDemo) → purchased
                    → dismissed → free_lesson_claimed → free_lesson_completed
```

Two numbers decide whether this worked:

1. **`walkthrough_started → walkthrough_completed`.** Below ~70% the script is
   too long or the scenario is too hard, and the fix is copy, not code.
2. **Purchase rate at `source=postDemo` vs `source=onboarding`.** This is what
   decides whether `post_demo_wall_hard` ever gets flipped. Judge on revenue per
   install, not activation rate.

---

## 8. Phasing

| Phase | Work | Blocked by | Status |
|---|---|---|---|
| **W0** | Mascot art confirmed / produced | — | ⛔ precondition |
| **W1** | `freeLessonId` state + `claimFreeLesson` + loads/resets; `canOpenScenario` / `canOpenLesson`; correct the stale `hasCompletedFreeDemo` doc comments | — | ✅ done |
| **W2** | Gate changes at the tap sites (**two**, not three — see below) | W1 | ✅ done |
| **W3** | Existing-user suppression, **layer 1 only** (layer 2 needs the coordinator — moved to W4) | W1 | ✅ done |
| **W4** | `WalkthroughCoordinator` + tab driving + **suppression layer 2** (skip the scenario beat when scenario 1 is already complete) | W1 | ✅ done |
| **W5** | `MascotOverlayView` + copy + **script activation** + **off-script tap interception** (moved from W4) | W0, W4 | ✅ done — **must ship with W6** |
| **W6** | `markFreeDemoCompleted()` wired to `finished` | W4 | ✅ done — **the feature is now live** |
| **W7** | Analytics | W4, W6 | ✅ done |

W1-W3 are independently shippable and behaviourally inert without W4-W6: the
walkthrough never starts, so `canOpenLesson` never returns true on the credit
path (it requires `hasCompletedFreeDemo`, which nothing sets). The one live change
is scenario 1 becoming free — which is worth shipping alone regardless.

**W6 is the switch that makes any of this visible to users.** Until it lands,
every free user stays in branch 4b exactly as they do today.

### Verification state after W1

**Behaviourally inert, by construction and by grep.** `canOpenScenario`,
`canOpenLesson` and `claimFreeLesson` have zero call sites outside
`AuthManager` — W2 is what introduces them — so the three gate sites still run
the bare `hasActiveSubscription` check they ran before. The only live change is
one extra `UserDefaults` read per session-load path, which resolves `nil` for
every user: the local key is new, and the `free_lesson_id` metadata mirror is
written only by `claimFreeLesson`, which nothing calls.

This holds a step longer than the credit itself needs it to.
`canOpenLesson(id:)` is additionally gated on `hasCompletedFreeDemo`, which is
provably `false` for every production user — `free_demo_completed` is written
only inside `markFreeDemoCompleted()`, and that has no callers until W6. So even
once W2 wires the gates, the lesson credit stays shut until the walkthrough
exists to release it. **W2's only user-visible effect will be scenario 1
becoming free.**

Debug/Release both build clean with no new warnings. Not yet exercised at
runtime — see the manual checks in §9, tests 1 and 4.

### Verification state after W2

**Two sites changed, not three.** The phasing row said "three tap sites",
inherited from the count of gates in §1's table — but that table also says daily
practice is *unchanged*. `HomeView.swift:138` is deliberately still a bare
`hasActiveSubscription` check and is now the only one left in the app.

**Correction to W1, forced by this step.** `claimFreeLesson(id:)` would have
burned a subscriber's credit on the first lesson they ever opened, leaving them
nothing if the subscription later lapsed. It now no-ops when
`hasActiveSubscription`. Enforced inside the method rather than at the call site,
so a future second entry point cannot reintroduce it.

**Checked, not assumed: there is no second way into a lesson.**
`LessonCompleteView`'s next-lesson block is display-only — its Continue button
calls `onContinue()` and dismisses, with no navigation — and `LessonView` is
constructed in exactly one place (`CourseDetailSheet.swift:147`, plus a
`#Preview`). Had it pushed the next lesson, a free user could have claimed lesson
1 and then walked the whole course.

Behaviour matrix — only one cell moves:

| User | Action | Before | After |
|---|---|---|---|
| Subscriber | any scenario / lesson | opens | opens |
| Free | **scenario 1** | paywall | **opens** ← the only change |
| Free | scenario 2+ | paywall | paywall |
| Free, pre-walkthrough | any lesson | paywall | paywall |
| Free, post-walkthrough | first lesson opened | — | opens, claims credit |
| Free, post-walkthrough | a second lesson | — | paywall |
| Anyone | daily practice | subscription | subscription |

The post-walkthrough rows are unreachable until W6 sets `hasCompletedFreeDemo`.

**Consequence for dashboards, worth knowing before the release lands.**
`practice_scenario_started` / `practice_scenario_completed` now fire for
non-subscribers on scenario 1. Until now only subscribers could generate them, so
volume on both events will rise and any funnel using them as a proxy for
subscriber engagement will shift. This is the intended behaviour, not a leak —
but the baseline breaks at the release boundary.

No new prefetch cost: `prefetchGameData` filters on `!isLocked`, and scenario 1
has `required_lessons_completed = 0`, so its game data was already being
prefetched for every user including non-subscribers.

### Verification state after W3

Three defects in §0.4 as written, all found before or during implementation.

**1. Suppression must set BOTH flags.** §0.4 said "mark the demo spent"; test
4.3 said both. Test 4.3 was right, and §0.4 as written was a launch-day
incident: `hasCompletedFreeDemo` alone moves RootView out of branch 4b and
straight into **4c, the post-demo paywall**. Suppressing the walkthrough would
have converted a silent repair into a surprise full-screen paywall for every
existing user. `suppressWalkthrough(userId:reason:)` writes both, and writes the
UserDefaults keys as well as the published values so the
`checkUserPostDemoWallStatus` call that runs on the very next line reads `true`
back instead of clobbering it. Ordering verified at all five call sites.

**2. Setting `hasCompletedFreeDemo` silently released the free lesson.**
`canOpenLesson(id:)` guards on that flag, so suppressing the install base would
have handed a free lesson to every existing non-paying user — an unrequested,
unmeasured monetisation change shipped as a side effect of a cosmetic fix. Fixed
with `hasSuppressedWalkthrough`, a local-only per-user flag that records *why*
the demo flag is set. `canOpenLesson` now requires the demo to have been
genuinely completed. This is the one thing in W1-W3 that could not have been
caught by reading the plan; it only appears when tracing a cohort through both
changes at once.

**3. Layer 2 cannot ship in W3.** It lives on the coordinator, which is W4.
Moved there rather than landing a helper nothing calls.

**Reinstall ordering, handled.** `hydrateLessonProgressFromCloud()` runs *after*
`checkUserFreeDemoStatus` on every path that calls it, so a local-only check
would read zero lessons for a returning user on a fresh install and hand them
the tour. `userHasPreExistingProgress()` therefore also reads
`currentUser.userMetadata["lesson_progress"]` directly — the same source
hydration uses, already populated at that moment, no network, no reordering.

**Known gap, accepted:** a lapsed ex-subscriber with scenario progress but zero
completed lessons is not caught, because scenario progress lives in
`user_scenario_progress` (a network read) rather than in metadata. §9 test 5.3
claimed layer 1 caught them; it does not, and that claim is withdrawn. W4's
layer 2 removes the part that actually stings — being asked to replay a
finished scenario — and the post-demo ask that follows is the right screen for a
lapsed subscriber anyway.

**Analytics caveat.** `walkthrough_suppressed` fires from the session-restore
path, which can beat PostHog's own detached setup at launch. The
`🎓 Walkthrough SUPPRESSED` log line is the reliable signal; the event is a
bonus, not the measurement.

**Live effect today: none.** Branches 4b and 4d both render `MainTabView`, so a
suppressed user lands on the same screen either way. The only observable change
is three UserDefaults keys and a log line — and, once W6 lands, not being shown
a walkthrough.

### Audit of W1-W3

Re-verified against the code rather than against this document. One further
defect found and fixed; everything else held.

**Fixed: `markFreeDemoCompleted()` did not clear `hasSuppressedWalkthrough`.**
Both flags set at once means `canOpenLesson(id:)` denies the credit to a user
who just earned it. Not reachable in production — suppression sets
`hasCompletedFreeDemo`, so the walkthrough never runs and the setter never fires
— but very reachable in DEBUG, because `-forceFreeDemoCompleted NO` re-arms the
walkthrough on a device whose suppressed key is already set. That is exactly how
W4-W6 will be tested, so it would have cost real debugging time. The setter now
clears the flag and removes the key.

**Verified, previously only assumed:**

| Claim | Result |
|---|---|
| Pre-session window cannot open a lesson | ✅ the global `hasCompletedFreeDemo` key is **read but never written** (vestigial, pre-existing), so it is always `false` before a session loads |
| Suppression cannot false-positive from browsing | ✅ `saveLessonProgress` has exactly one caller, inside `markLessonCompleted`; and the check reads `completed` only, never `unlocked` |
| Lesson namespace is the right user at suppression time | ✅ every one of the five paths assigns `currentUser` immediately before, and the SDK's own `currentUser` is set before it emits the event |
| Sign-out → different user signs in | ✅ per-user keys, correct namespace, no cross-contamination |
| Genuine completer on a new device | ✅ the `free_demo_completed` mirror short-circuits the suppression check before it can run, and `freeLessonId` restores from its own mirror |
| No second route into a lesson | ✅ `LessonQuizFlowView` has no navigation either — confirmed alongside `LessonCompleteView` |
| All four reset blocks carry all three new pieces | ✅ co-located in every block |

### W0 — resolved

**The mascot is `scenario_user`** (`Assets.xcassets/ScenariosScreen/`),
confirmed 2026-08-01. Facts that matter for W5:

- 2048×2048 **RGBA**, so it composites on a dimmed scrim without a white box.
- Line art, black on transparent — matches the app's existing visual language.
- **The figure occupies roughly the left 55% of the canvas and runs to the
  bottom edge.** It is not centred and it is not a bust. Dropping it into a
  bubble layout unaligned will render it small and off to one side; W5 needs an
  explicit crop/anchor, not `.scaledToFit()` on the raw asset.
- Only the `1x` slot is populated. Harmless at this resolution — it downscales
  — but it is why the file is 180KB.

One semantic wrinkle to be deliberate about in copy: this is the *player's*
avatar inside scenarios. Using it as the guide makes "I'm your wingman" a
figure the user may already read as themselves. Either lean into it ("that's
you, three weeks from now") or keep the copy in the second person and let the
figure be a generic presence. §5's drafts assume the latter.

### Verification state after W4

**Scope corrected: off-script nudges moved to W5.** A nudge *is* a mascot line,
and the mascot is W5. Wiring interception now would have made off-script taps in
demo mode do nothing at all — no paywall, no nudge, no feedback — which is worse
than today's behaviour. The `showNudge(_:)` / `dismissNudge()` API landed with
the coordinator; the tap sites that call it land with the thing that renders it.

**Activation also moved to W5**, for the same reason: a running script with
nothing rendering it is a broken app. `start(...)` exists and has **zero
callers**, so `step` can never leave `.dormant` and every other method
short-circuits on its own guard. W4 is inert by the same discipline as W1-W3.

**Layer 2 landed, and it absorbed the W3 operational risk.**
`noteScenarioList(_:)` skips the scenario beat in two cases, not one:

1. Scenario 1 already `isCompleted` — the cohort layer 1 misses (a lapsed
   ex-subscriber with scenario progress and no completed lessons), and the
   resume path for anyone who force-quit mid-walkthrough.
2. **No scenario with `order_index == 1` in the fetched list at all.** This is
   the `freeScenarioOrderIndex` fragility flagged in the W3 audit: unpublishing
   or reordering that row in the `scenarios` table would otherwise strand the
   user on an instruction they cannot follow, with no skip. It now degrades to a
   shorter walkthrough instead of a trap.

It is fed from `PracticeView`'s existing `.task`, which already fetches the
list — no second round trip.

**Deviation from §0.4:** a skipped scenario jumps to `lessonsTour`, not to
`scenarioDone`. The congratulations beat exists to land a scenario the user just
played; firing it for someone who played it weeks ago (or not at all) reads as a
bug. `didSkipScenario` is exposed so W5's copy can branch.

**Regression risk specific to this step: `@EnvironmentObject` is a runtime crash,
not a build error.** Two views now require the coordinator, and every
construction site is covered — `PracticeView` (MainTabView + its own
`#Preview`) and `PracticeGame` (inside `PracticeView`'s
`navigationDestination`, which inherits the environment, + its own `#Preview`).
Both previews were updated. `PracticeGame` already depended on this same
inheritance for `tabBarVisibility`, so the pattern is proven in production
rather than assumed.

**The new file is genuinely compiled.** The project uses
`PBXFileSystemSynchronizedRootGroup`, so `Wingman/Walkthrough/` was picked up
without a project edit. Verified by injecting a deliberate type error and
confirming the build failed at that file, then restoring it byte-identically —
a passing build alone would not have distinguished "compiles" from "silently
excluded".

Debug and Release build clean, no warnings on any changed file.

#### Audit of W4 — three defects found and fixed

All three were dead ends in the step machine: states the script could enter and
never leave, with the overlay hidden and nothing on screen able to advance it.
None would have shown up in a build; all three needed the transition graph
traced by hand.

**1. A failed game-data fetch stranded the script.**
`noteScenarioOpened()` fired at the tap site, *before* `fetchGameData(for:)` —
which returns nil on a network error, after which `loadAndNavigate` simply
stops and the user stays on `PracticeView`. The script would sit at
`scenarioRunning` with no game on screen, and `isIntercepting` is false in that
step by design, so the mascot would be hidden too. Moved to
`PracticeGame.onAppear`, the same place `practice_scenario_started` fires — the
honest "the scenario is open" signal.

**2. Backing out of the scenario stranded it permanently.** `scenarioRunning`
had exactly one exit, completion. A back-tap left the script there for the rest
of the session. Added `noteScenarioAbandoned()` on `PracticeGame.onDisappear`,
returning to `scenarioPrompt` so the mascot asks again. It no-ops on the happy
path because completion has already moved the step to `scenarioDone` before
`GameCompleteView` is dismissed.

**3. The skip could swallow the lessons tour.** `skipScenarioBeat` changed
`step` the moment the scenario list arrived. If that landed while the user was
mid-`welcome`, their pending tap would `advance()` from `lessonsTour` to
`benefits` and the tour beat would never render. Not reachable today — a
`TabView` does not run a non-selected tab's `.task` — but that is an
implementation detail holding up correctness. The skip is now *recorded*
(`scenarioBeatUnavailable`) and applied by `advance()` at a beat boundary,
unless the user is already looking at the prompt.

`didSkipScenario` also became `@Published`, since W5's copy branches on it.

#### Reachability, after the fixes

| Step | Exits |
|---|---|
| `dormant` | `start()` → `welcome` or `finished` |
| `welcome` | tap → `scenarioPrompt`, or → `lessonsTour` if the beat is unavailable |
| `scenarioPrompt` | scenario opens → `scenarioRunning`; list says skip → `lessonsTour` |
| `scenarioRunning` | completed → `scenarioDone`; **left → `scenarioPrompt`** |
| `scenarioDone` | tap → `lessonsTour` |
| `lessonsTour` | tap → `benefits` |
| `benefits` | tap → `finish()` |
| `finished` | terminal |

Every non-terminal step has at least one exit that cannot fail to fire.
`advance()` at `scenarioPrompt` and `scenarioRunning` is a deliberate no-op —
there is no skip past the scenario, which is the plan's one hard constraint.

**Not guarded, deliberately:** `noteScenarioOpened()` does not check *which*
scenario opened. During the walkthrough no other scenario is openable — #2
onwards need a completed lesson (`required_lessons_completed >= 1`), and
`canOpenLesson` requires `hasCompletedFreeDemo`, which the walkthrough has not
yet set. Reachable only by a subscriber, who never enters the script.

### Verification state after W5

**⚠️ W5 IS NOT SAFE TO SHIP ALONE.** It activates the script, but `finish()`
still does not call `markFreeDemoCompleted()` — that is W6, one line. Until it
lands, a user who completes the whole walkthrough gets it again on the next
cold launch, forever. W5 and W6 must go out together.

**This is the first step users can see.** Everything before it was inert. The
cohort affected is exactly RootView branch 4b — free users who have passed
paywall #1 and not spent the demo. Subscribers (4a) and suppressed/post-demo
users (4d) call `start(...)`, land on `finished`, and see nothing; every tap
site behaves for them exactly as it did before, because `isIntercepting` is
false.

**Interception ordering, verified rather than assumed.** All three paywall
triggers sit *behind* their interception check —
`HomeView.swift:143→148`, `PracticeView.swift:147→161`,
`CourseDetailSheet.swift:125→143`. No paywall can open while the script is
running, which is the plan's hardest rule about this feature.

`PracticeView`'s check is also ahead of the **progression** guard, not just the
paywall: a locked card currently no-ops in silence, and silence mid-script reads
as a broken app.

**Scrim hit-testing is the load-bearing part, not the dimming.** Two beats ask
the user to act in the app — tap the scenario, scroll the courses — so those
dim to 0.15 and pass touches through (`allowsHitTesting(false)`). The read-only
beats block at 0.55, which is also why an off-script tap during `welcome` never
needs a nudge: it cannot land.

**One more trap found and closed while tracing.** `scenarioPrompt` has no skip
control by design. If the free scenario's game data fails to load — offline, or
a failed fetch — `loadAndNavigate` silently does nothing, so the user would have
sat at that beat permanently with lessons and daily practice nudge-blocked
behind a script that could not advance. `noteScenarioUnavailable()` now skips
the beat from the failure branch. It is not a skip *offered* to the user; it
fires only once the app has already failed to deliver the scenario.

**Crash-risk audit.** `@EnvironmentObject` is a runtime crash, not a build
error, and W5 added two more requirers (`HomeView`, `CourseDetailSheet`).

| View | Sites | Covered |
|---|---|---|
| `HomeView` | MainTabView, `#Preview` | ✅ |
| `PracticeView` | MainTabView, `#Preview` | ✅ |
| `PracticeGame` | `PracticeView` (inherits), `#Preview` | ✅ |
| `CourseDetailSheet` | `HomeView` + `CoursesView` (both inherit), `#Preview` | ✅ |
| `MascotOverlayView` | MainTabView (explicit inject) | ✅ |

`HomeView`'s `#Preview` was already missing `CoursesRouter` and `AuthManager`
before this change — it could not have rendered. Completed rather than left
half-broken.

**Mascot geometry, checked against the asset.** The figure occupies x
0.04–0.49 of the 2048² square. At the 240pt frame height used here it spans
11–118pt, so the 148pt left crop covers it with ~30pt of slack. Without the
narrowed frame the empty right half would push it visually off-centre.

**Not visually verified.** Layout, copy fit at large Dynamic Type, and the
scrim/bubble contrast have not been seen rendered — this is static reasoning
plus geometry. §9 test 1 is the check that matters.

#### Audit of W5 — two defects found and fixed

**1. The mascot and bubble blocked taps on the two pass-through beats.** The
scrim correctly passed touches; the bubble and mascot did not. An `Image` is
hit-testable across its whole frame regardless of transparency, so 148×240pt of
the bottom-left was dead to touch on every beat — and at `scenarioPrompt` the
bubble sits ~330pt off the bottom, which on a small device can cover the first
scenario card. That is the one beat with no other way forward, so it was a
potential hard stop. The mascot is now `allowsHitTesting(false)` outright, and
the bubble only takes touches when it actually has a button.

**2. `start(...)` sent ineligible users to `.finished`.** This contradicted the
coordinator's own doc comment that only completion reaches that state, and W6
hangs `markFreeDemoCompleted()` off exactly that transition. A **subscriber**
would therefore have had the demo flag written and mirrored; when their
subscription later lapsed they would drop past branch 4b straight onto the
post-demo paywall. Ineligible users now stay `dormant`, guarded by a separate
`hasEvaluated` flag so they do not re-evaluate on every `onAppear`.

Also added `.appDynamicTypeCeiling()` — the overlay is the longest single block
of copy in the app and nothing above `MainTabView` applies the ceiling.

### Verification state after W6 — the feature is live

`MainTabView` observes the step and calls `markFreeDemoCompleted()` on
`finished`. That is safe to hang off a step change *because of* the W5 fix
above: `.finished` is now reachable only through `finish()`, which is called
only from `advance()`'s `benefits` case and guarded by `isRunning`.

Verified by grep, not assumption:

| Claim | Result |
|---|---|
| `step = .finished` assignments | exactly one, inside `finish()` |
| `finish()` callers | exactly one, `advance()` at `benefits` |
| `markFreeDemoCompleted()` callers | exactly one, `MainTabView` |
| RootView branch order 4a → 4b → 4c | intact |

**The live flow, end to end.** Free user passes paywall #1 → branch 4b →
`start` → welcome ×2 → tab flips to Scenarios → plays Bar Window free → congrats
→ tab flips to Courses, browsable → benefits → `finish()` →
`markFreeDemoCompleted()` → RootView re-renders into **4c, the post-demo ask** →
dismiss → **4d** with one free lesson waiting. `markFreeDemoCompleted()` also
clears `hasSuppressedWalkthrough`, so `canOpenLesson` releases the credit.

**Cohorts that must see no change, and don't:** a subscriber or a
suppressed/post-demo user leaves `start(...)` still `dormant`, so `isRunning` is
false (no overlay), `isIntercepting` is false (every tap site behaves exactly as
before), and the `finished` transition never fires (no flag write).

**Offline completion works.** `markFreeDemoCompleted()` writes UserDefaults
synchronously and mirrors to `user_metadata` best-effort; a failed mirror is
logged, not fatal. The post-demo paywall then has no offerings, which is what
`onOfflineBypass` exists for — the user reaches 4d for that session and the ask
re-arms on the next cold start.

**Still not visually verified.** Layout, copy fit, scrim contrast and the tab
flips are static reasoning. §9 test 1 is the check that matters, and it is now
worth running end to end.

#### Audit of W6 — correct, with one omission

The wiring itself held: `.finished` is set in exactly one place, `finish()` has
exactly one caller, `markFreeDemoCompleted()` has exactly one caller, and
RootView's 4a → 4b → 4c ordering is intact.

**Omission: neither of the two transitions W6 makes reachable was animated.**
`hasCompletedFreeDemo` and `hasDismissedPostDemoWall` were missing from
RootView's `.animation(value:)` list, so the mascot's last beat would hard-cut
to the post-demo paywall in a single frame. This is the identical defect the
file already documents and fixes for `effectivePaywallFlowCompleted` — "reads as
a glitch rather than a step" — and it lands on the money moment. Both added.

### Verification state after W7

**Deviation, deliberate: there is no `walkthrough_abandoned`.** Abandonment is a
force-quit, and it cannot be captured honestly at the moment it happens. Firing
something on backgrounding instead would conflate "took a phone call" with "gave
up". `walkthrough_step_viewed` answers the same question strictly better — it
shows *which beat* loses people rather than collapsing all of them into one
number — so the funnel is per-step and the abandonment event is not faked.

**Deviation, deliberate: no `free_lesson_completed` event.** `lesson_completed`
carries `is_free_lesson` instead. A second event would need its own definition
of "finished a lesson", and `lesson_completed` already owns that — quiz
included. Two definitions of the same thing eventually disagree.

**Deviation, deliberate: no `demo_scenario_completed`.** The existing
`practice_scenario_started` / `practice_scenario_completed` pair carries
`during_walkthrough` instead, so one pair of events serves both funnels rather
than a parallel `demo_*` pair that would drift.

| Event | Emitted from | Properties |
|---|---|---|
| `walkthrough_started` | `start()` | — |
| `walkthrough_step_viewed` | `step` didSet, per beat | `step`, `skipped_scenario` |
| `walkthrough_nudge_shown` | `showNudge(_:)` | `surface`, `step` |
| `walkthrough_completed` | `finish()` | `duration_seconds`, `skipped_scenario` |
| `walkthrough_suppressed` | both layers | `reason` (4 values) |
| `free_lesson_claimed` | `claimFreeLesson` | `lesson_id`, `course_id` |
| `lesson_completed` | unchanged site | **+ `is_free_lesson`** |
| `practice_scenario_*` | unchanged sites | **+ `during_walkthrough`** |

**Emission ordering verified, not assumed.** Three places where the causal and
recorded order could have diverged:

- `walkthrough_started` fires before `step = .welcome`, so it precedes its own
  first `step_viewed`.
- `didSkipScenario = true` precedes `step = .lessonsTour` at both skip sites, so
  the beat is tagged correctly rather than one event late.
- Both `practice_scenario_*` captures run *before* the coordinator advances, so
  `during_walkthrough` is still true at each — reading it after
  `noteScenarioCompleted()` would have recorded `false` on every completion.

`walkthrough_completed` is captured before the step change, so PostHog's
ordering matches the causal one: completed → RootView re-renders →
`paywall_viewed(source=postDemo)`.

**Reliability caveat.** Unlike `walkthrough_suppressed` (which fires on the
session-restore path and can beat PostHog's detached setup), these all fire from
`MainTabView`, which appears long after launch — so they are not exposed to that
race. The residual risk is a cold launch straight into branch 4b, where
`walkthrough_started` could in principle precede SDK setup; `setup()` is local
and `restoreSessionGracefully()` gates MainTabView behind a network round trip,
so this should not happen in practice. If `walkthrough_started` ever undercounts
`walkthrough_step_viewed`(`welcome`), that is the cause.

### Content finding, recorded because the code no longer carries it

`Course.lessonsCount` in `CourseCategory.dummyCategories` sums to **171** across
25 courses. The bundled JSON those same 25 courses actually load contains
**94** lessons. The declared counts overstate the catalogue by roughly 80%, and
they are what the Courses UI displays.

This surfaced while deriving a catalogue count for the walkthrough's closing
beat. That beat has since been cut to a plain sign-off, so the helper that
counted real lessons was removed with it — but the discrepancy is unrelated to
the walkthrough and is still there.

**Operational dependency, worth stating.** `freeScenarioOrderIndex = 1` is
matched against the `scenarios` table's `order_index`, not against "first row in
the list". If order 1 is ever unpublished or reordered, **no** scenario is free
and the walkthrough's core beat breaks silently. Keyed on `order_index`
deliberately — "whatever happens to be first" is the more fragile rule — but it
means the free scenario is a content decision, not just a code one. W4's
coordinator has to locate the same scenario, so guard it there too.

---

## 9. Manual test plan

Simulator is fine for everything except the linking test, which
`anonymous-auth-plan.md` §0 already owns.

### 1. The happy path

1. Fresh install → Skip for now → onboarding → dismiss paywall #1.
2. **PASS:** mascot welcome appears over MainTabView, tab bar visible behind it.
3. Tap through → scenario prompt → tap Scenarios → **scenario 1 opens with no
   paywall**.
4. Inside the scenario: **PASS:** no mascot overlay visible at any point.
5. Finish it → back on `PracticeView` → **PASS:** congratulations appears.
6. Continue → **PASS:** lands on Courses, scrollable, mascot bubble present.
7. Continue → benefits → Continue → **PASS:** post-demo paywall
   (`source=postDemo`).
8. Dismiss → MainTabView → open any lesson → **PASS:** it opens, and
   `free_lesson_claimed` fires.
9. Open a *second* lesson → **PASS:** paywall.
10. Re-open the *first* lesson → **PASS:** still opens.

### 2. Never twice

1. Complete the walkthrough, force-quit, relaunch.
2. **PASS:** straight to MainTabView, no mascot, no post-demo paywall
   (`hasDismissedPostDemoWall` already set).
3. Delete and reinstall on the same account (or link the guest to an Apple ID
   first) → **PASS:** `free_demo_completed` rehydrates from `user_metadata`,
   still no walkthrough.

### 3. Abandonment

1. Start the walkthrough, complete scenario 1, force-quit at the congratulations
   beat.
2. Relaunch → **PASS:** walkthrough restarts at `welcome`, then **skips the
   scenario step** — scenario 1 reads `isCompleted`.
3. Force-quit during `welcome` instead → relaunch → **PASS:** full restart
   including the scenario.

### 4. Existing user is not tutorialised

1. On a build *before* this change, complete one lesson. Install this build over
   it. **Do not delete.**
2. **PASS:** no mascot. Console shows the suppression, and
   `walkthrough_suppressed { reason: existingProgress }` fires.
3. **PASS:** no post-demo paywall either — the demo is marked spent, and
   `hasDismissedPostDemoWall` is separately false, so verify which branch they
   actually land in. If they land on 4c, the suppression must set **both** flags.

> This is the one case most likely to be wrong on first implementation. Marking
> the demo spent without also marking the wall dismissed converts a silent
> suppression into a surprise paywall for every existing user on launch day.

### 5. Paying user never sees any of it

1. Subscribe at paywall #1 → **PASS:** branch 4a, no walkthrough.
2. Existing subscriber updating the app → **PASS:** same.
3. Lapsed ex-subscriber **with completed lessons** → **PASS:** no walkthrough,
   layer 1 catches them. Verify explicitly — this cohort has
   `hasActiveSubscription == false` and would otherwise fall into 4b.
4. Lapsed ex-subscriber with **scenario progress but no completed lessons** →
   **EXPECTED:** they *do* get the welcome, but layer 2 skips the scenario beat.
   Known gap, see the W3 verification note. Not a failure.

### 6. No paywall interrupts the script

Walk the whole script tapping every wrong thing — daily practice, locked
scenarios, lesson cards, Profile, Log Approach.

**PASS:** every one produces a mascot nudge or nothing. A paywall appearing at
any point before step 5 is a failure.

---

## 10. Open items

1. **Mascot art** (W0). Blocks W5 only; everything else can proceed.
2. **Nudge on Profile / Log Approach.** Approach logging is free and always has
   been. Letting a user log an approach mid-walkthrough is harmless but breaks
   the script's pacing. Currently specced as "no nudge, no interception" —
   revisit if it reads badly.
3. **Second free lesson for a linked account.** A guest who claims the free
   lesson then links an Apple ID keeps the same `user_id`, so the credit
   correctly does not regrant. A guest who instead signs in on a *new device*
   gets a new row and a fresh credit. Known, accepted, same limitation as
   `anonymous-auth-plan.md` §Phase G.
4. **Scenario 2's threshold is 1 completed lesson** (verified against the live
   `scenarios` table, 2026-08-01 — this closes open item 1 of
   `demo-then-wall-plan.md`). The walkthrough completes zero lessons, so scenario
   2 stays progression-locked throughout. If the user later spends the free
   lesson, scenario 2 unlocks progression-wise but remains subscription-gated.
   No leak, but re-check if the free lesson ever becomes free *lessons*.
5. **`post_demo_wall_hard` stays `false` for launch.** Flipping it before there
   is a `source=postDemo` purchase-rate baseline is a one-way bet on a funnel
   nobody has measured yet.
