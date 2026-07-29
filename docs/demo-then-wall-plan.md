# Demo-then-Wall — Implementation Plan

Target flow:

```
Onboarding quiz
  → RatingPromptView
  → Paywall #1 (dismissible, unchanged)
  → Account creation (already forced for anonymous users)
  → MainTabView in DEMO MODE
      → mascot walks user into 1 scenario
      → mascot walks user into 1 lesson
  → Hard wall (non-dismissible paywall, RootView route)
```

Everything below was verified against the code on branch `Shat`. Line numbers are
from the state at time of writing.

---

## 0. The two flags, and why the migration is safe

This is the part that has a trap in it, so it goes first.

There are two *different* questions that the current code conflates into one flag:

| Question | Flag | Status |
|---|---|---|
| Has the user passed paywall #1? | `hasCompletedPaywallFlow` | exists |
| Has the user spent their free demo? | `hasCompletedFreeDemo` | **new** |

Today `effectivePaywallFlowCompleted` (`AuthManager.swift:233`) answers the first
question and is used to admit the user to `MainTabView`. The four
`.subscriptionGate` modifiers are what actually stop a non-payer from *using*
anything once inside.

**The trap:** every existing non-paying user already has
`hasCompletedPaywallFlow == true` — persisted per-user in UserDefaults
(`hasCompletedPaywallFlow_<userId>`) *and* mirrored to Supabase `user_metadata`
as `paywall_flow_completed` (`AuthManager.swift:1022-1053`). The flag never
expires. If the four gates are deleted and nothing replaces them, every one of
those users gets the whole app free, permanently, on next launch.

**The fix:** `hasCompletedFreeDemo` is a *new* key, so it defaults to `false` for
everyone. Existing non-paying users therefore land in demo mode, play the demo,
and hit the wall — which is the desired behavior. The migration is safe **by
construction**, but only because the new flag exists. Do not delete the gates
before it lands.

`effectivePaywallFlowCompleted` keeps its current job (routing paywall #1) and
must **not** be what admits a user to content.

### New flag spec — `AuthManager.swift`

Mirror the exact shape of `hasSeenSecondChanceOffer`, which is the cleanest
existing example of a per-user persisted + cloud-mirrored boolean:

- `@Published var hasCompletedFreeDemo: Bool = false` — near line 72
- Global-key load at init (line ~136) for the pre-session default
- Per-user load `hasCompletedFreeDemo_<userId>` in a
  `checkUserFreeDemoStatus(userId:)`, alongside `checkUserSecondChanceStatus`
  (line ~481), including the `user_metadata` rehydrate fallback
- `func markFreeDemoCompleted()` mirroring `markSecondChanceOfferShown()`
  (line ~1064): sets the flag, writes the per-user key, best-effort mirror to
  `user_metadata["free_demo_completed"]`
- Reset to `false` on `signedOut` (line ~338), `userDeleted` (line ~413), and in
  the account-deletion cleanup paths (lines ~1386, ~1418, ~1492) and
  `userDefaults.removeObject` at line ~1531

**Decision needed:** should the demo be re-granted after sign-out? Following
`hasCompletedPaywallFlow`'s precedent, sign-out resets the in-memory flag but
the per-user key survives, so the same account does not get a second demo. A
brand-new account does. That is the right default.

---

## 1. Routing — `WingmanApp.swift`

Current authenticated branch (lines 130-167) ends with:

```
} else {                       // effectivePaywallFlowCompleted
    MainTabView()
}
```

Replace that terminal `else` with a three-way branch:

```
} else if authManager.hasActiveSubscription {
    MainTabView()                              // full access
} else if !authManager.hasCompletedFreeDemo {
    MainTabView()                              // demo mode
} else {
    NavigationStack { PaywallView(..., isDismissible: false, source: .postDemo) }
}
```

Because this is a route and not a sheet, flipping `hasCompletedFreeDemo` causes
RootView to re-render straight into the wall. That is the whole mechanism — no
gate modifiers involved.

The anonymous branch (lines 168-210) needs **no change**: it already forces
account creation after paywall #1, which is exactly the sequencing you asked
for. Once authenticated, those users fall through to the branch above.

Add `hasCompletedFreeDemo` to the `.onChange` logging block at line ~368 and the
diagnostic dump at line ~334.

---

## 2. Demo mode — replacing the four gates

Delete all four `.subscriptionGate` call sites and the modifier itself:

| File | Line | Action |
|---|---|---|
| `Home/HomeView.swift` | 307 | remove modifier + `showDailyPracticePaywall` state + the branch at 138 |
| `PracticeGame/PracticeView.swift` | 66 | remove modifier + `showPaywall` state + the guard at 137 |
| `Courses/CourseDetailSheet.swift` | 156 | remove modifier + `showPaywall` state + the branch at 125 |
| `Payment/SubscriptionGateModifier.swift` | — | delete file |
| `LogApproch/LogApproachBottomSheet.swift` | — | already done |

In their place, demo mode restricts *what is visible as available* rather than
intercepting taps. The app already has lock rendering for progression locks —
reuse it rather than inventing a second visual language:

- **Scenarios** — `Practice.isLocked` (`Practice.swift:23`) is already computed
  by the service after fetch. Extend that computation: in demo mode, everything
  except the designated demo scenario is locked. `PracticeView`'s
  `loadAndNavigate` already no-ops on locked practices (line 132).
- **Courses / lessons** — `CoursesViewModel.courseLockReason(_:)`
  (`CoursesViewModel.swift:239`) is the single chokepoint feeding both
  `CourseCardContent` and `CourseDetailSheet`. Add a `.demoMode` case to
  `CourseLockReason` (`CourseLockReason.swift`) so every course except the demo
  course renders locked with its own banner copy. Within the demo course,
  `CourseDetailSheet.loadLessons()` (line 178) already force-locks lessons when
  the course is locked — extend it to lock all but the first lesson.
- **Daily practice** — `HomeView.swift:138`. Not part of the scripted demo;
  keep it unavailable during demo mode. Reuse the existing disabled-button
  treatment (`canStart`, line 133) rather than a paywall.
- **Approach logging** — free, no change.

**Decision needed:** which scenario is the demo scenario? The `scenarios` table
has `order_index` and `required_lessons_completed`. The natural pick is the
lowest `order_index` published row with `required_lessons_completed == 0`. I
cannot query your Supabase project from here — confirm such a row exists, or
add an explicit `is_demo` column, which is more robust than relying on
ordering.

Lessons come from **bundled JSON**, not Supabase
(`LessonDataService.swift:72-119`, `courseJsonMapping` at line 32), so the demo
lesson can be selected client-side with no data change.

---

## 3. Mascot walkthrough — net new

Verified: **no walkthrough, coach-mark, tooltip, or mascot code exists in the
project.** This is the largest piece of work and the only one with an external
dependency (the mascot asset itself).

Suggested shape:

- `Walkthrough/WalkthroughCoordinator.swift` — `ObservableObject` owning a
  `WalkthroughStep` enum state machine (`welcome → prompt_scenario →
  scenario_in_progress → scenario_done → prompt_lesson → lesson_in_progress →
  lesson_done → finished`). Instantiated as `@StateObject` in `MainTabView`
  (`MainTabView.swift:19-23`, next to `coursesRouter` / `tabBarVisibility`) and
  injected via `.environmentObject` on all four tabs so state survives tab
  switches and navigation pushes.
- `Walkthrough/MascotOverlayView.swift` — the speech-bubble overlay, layered in
  the `ZStack` at `MainTabView.swift:26` above the tab bar.
- Step advancement hooks into the existing completion points rather than new
  ones: scenario completion already emits
  `Analytics.Event.practiceScenarioCompleted`, lesson completion already emits
  `lessonCompleted` (`Analytics.swift:25-30`), and `LessonCompleteView` /
  `QuestionsCompleteView` exist as natural handoff moments.
- On `finished` → `authManager.markFreeDemoCompleted()` → RootView swaps to the
  wall.

**Design constraint worth honoring in code review:** the mascot's job is to walk
the user *into doing* the scenario, not to point at UI chrome. If the
implementation drifts into a generic coach-mark tour over the tab bar, it will
be skipped and the whole plan loses its value.

---

## 4. The hard wall — `PaywallView.swift`

- Add `case postDemo` to `PaywallSource` (line 16). Remove `case featureGate`
  once the gates are gone — nothing will emit it.
- **Offline escape hatch (required).** The dismiss overlay currently renders
  when `isDismissible` (line ~355 region). Its comment explicitly notes it is
  available in every state "so a user is never trapped if RevenueCat is slow or
  offline." A flatly non-dismissible wall destroys that property and bricks the
  app for anyone whose offerings fetch fails.

  Change the overlay condition to `isDismissible || viewModel.offerings == nil`.
  The escape-hatch dismissal must **not** call `completePaywallFlow()` — it
  should set a session-scoped `@State` bypass in RootView that lets the user
  into `MainTabView` for this launch only, with the wall re-arming on next
  cold start. This is deliberately the Gleam behavior: a pressure valve that
  also guarantees an App Reviewer who force-quits sees a working app.
- `footerLinks` already renders Restore/Terms/Privacy in every state — required
  by Guideline 3.1.2, and doubly important on a non-dismissible screen. Do not
  regress it.
- The `$0.00` CTA (`continueButtonTitle`, line 439) and `zeroPriceString`
  (`PaywallViewModel.swift:128`) are already in place and need no change.
- Still outstanding from earlier discussion: the **trial timeline** element
  (`Today: full access → Day 2: reminder → Day 3: billed`). Apple's 2026
  guidance explicitly favors transparent trial timelines, and this is the
  highest-value remaining paywall addition.

---

## 5. Second-chance offer — remove the trigger

Two reasons, one strategic (asking pay-up-front from someone who just declined a
free trial) and one practical (exit offers are being rejected under Guidelines
5.6 and 3.1.2 as manipulative — a real risk for an app with no approval
history).

The trigger lives entirely inside `SubscriptionGateModifier.swift`
(`evaluateSecondChanceOffer`, lines 89-126), which is being deleted in step 2.
So the trigger disappears for free.

**Recommendation: leave the rest in place, unreferenced.** `SecondChanceOfferView
.swift`, `SecondChanceOfferViewModel.swift`, the `Constants.SECOND_CHANCE_*`
entries, `RevenueCatConfig.SecondChanceOffer`, `AuthManager
.hasSeenSecondChanceOffer` / `markSecondChanceOfferShown`, and the
`Analytics.Event.recoveryOffer*` names all compile fine unused. Ship v1.0
without it, get approved, and rewire in v1.1 if you still want it — at which
point it should offer the **same 3-day trial at a lower post-trial price**, not
a discount that swaps the trial for an immediate charge.

Leave the `second_chance` offering configured in the RevenueCat dashboard; it is
not `current`, so it cannot surface on its own.

---

## 6. Analytics

Add to `Analytics.Event` (`Analytics.swift:23`):

```
walkthrough_started / walkthrough_step_completed / walkthrough_completed
demo_scenario_completed
demo_lesson_completed
hard_wall_viewed          (or reuse paywall_viewed with source=post_demo)
```

The funnel you actually need to watch after this ships:

```
install → onboarding_complete → paywall#1_viewed → {purchased | dismissed}
        → walkthrough_started → demo_scenario_completed → demo_lesson_completed
        → hard_wall_viewed → purchased
```

Expect install→activation to look *worse* and revenue per install to look
better. Judge on the second.

---

## Phasing

| Phase | Work | Blocked by |
|---|---|---|
| **1** | `hasCompletedFreeDemo` flag + persistence + resets | — |
| **2** | RootView three-way branch; wall renders when flag true | 1 |
| **3** | Offline escape hatch + session bypass | 2 |
| **4** | Demo-mode locking; delete 4 gates + `SubscriptionGateModifier` | 1, 2 |
| **5** | Trial timeline on paywall | — (independent) |
| **6** | Mascot coordinator + overlay + step hooks | 4, mascot asset |
| **7** | Analytics events | 6 |

Phases 1-3 are self-contained and testable without the mascot: set the flag
manually and confirm the wall appears, that Restore works, and that killing the
network produces the escape hatch rather than a brick. Phase 5 is independent
and can ship any time.

---

## Open decisions

1. **Demo scenario selection** — `is_demo` column vs. lowest `order_index` with
   `required_lessons_completed == 0`. Needs a look at the real `scenarios` data.
2. **Mascot asset** — design dependency, gates phase 6.
3. **Daily practice + streaks during demo** — assumed unavailable. Confirm, since
   `StreakStore` behavior during a locked period may need thought.
4. **Demo re-grant after sign-out** — assumed no (per-user key survives).
5. **Paywall #1 stays dismissible** — confirmed intent. It catches high-intent
   buyers at the post-quiz peak; only two asks now sit between install and the
   wall, with real value in between.
