# Demo-then-Ask — Implementation Plan

Supersedes the earlier hard-wall-first draft. Agreed sequence:

```
Onboarding quiz
  → RatingPromptView
  → Paywall #1 (dismissible, unchanged)
  → Account creation (already forced for anonymous users)
  → MainTabView in DEMO MODE
      mascot: welcome / "gym for your confidence"
      → scenario 1        (order_index = 1, required_lessons_completed = 0)
      → lesson 1          (first lesson, first course)
      → profile handoff   ("log approaches, track confidence" — logging is free)
  → ASK AT PEAK INTENT  ← the money moment
      dismissible in v1.0; hardness is a remote flag, not a rebuild
  → dismissed: into the app. Logging free. Three gates remain
      (lesson / scenario / daily practice), unchanged from today.
```

The single deliberate design constraint: **the walkthrough ends with the ask.**
Peak intent is the moment the demo finishes, not whenever the user later happens
to tap something. Everything else here is plumbing around that.

Verified against branch `Shat`. Line numbers from state at time of writing.

---

## 0. Flags

Three questions the code must answer separately. Today it conflates the first
two into one flag, which is where the trap is.

| Question | Flag | Status |
|---|---|---|
| Passed paywall #1? | `hasCompletedPaywallFlow` | exists — **leave alone** |
| Spent the free demo? | `hasCompletedFreeDemo` | new |
| Declined the post-demo ask? | `hasDismissedPostDemoWall` | new |

**The trap, restated because it still applies:** every existing non-paying user
has `hasCompletedPaywallFlow == true`, persisted per-user
(`hasCompletedPaywallFlow_<userId>`) *and* mirrored to Supabase `user_metadata`
as `paywall_flow_completed` (`AuthManager.swift:1022-1053`). It never expires.
It must not be what admits a user to content. Both new flags default `false`, so
existing users correctly fall into demo mode on first launch after the update.

### Spec — `AuthManager.swift`

Mirror `hasSeenSecondChanceOffer` exactly; it is the cleanest existing example of
a per-user persisted + cloud-mirrored boolean.

For each of `hasCompletedFreeDemo` and `hasDismissedPostDemoWall`:

- `@Published var … = false` near line 72
- Global-key load at init (~line 136) for the pre-session default
- Per-user load in a `checkUser…Status(userId:)` alongside
  `checkUserSecondChanceStatus` (~line 481), including the `user_metadata`
  rehydrate fallback
- A `mark…()` setter mirroring `markSecondChanceOfferShown()` (~line 1064):
  sets flag, writes per-user key, best-effort mirror to `user_metadata`
- Reset on `signedOut` (~338), `userDeleted` (~413), and the account-deletion
  cleanup paths (~1386, ~1418, ~1492, ~1531)

---

## 1. Routing — `WingmanApp.swift`

The post-demo ask is a **RootView route, not a sheet.** This matters: it is what
makes the hard/soft switch in §2 a config change instead of a refactor.

Replace the terminal `else { MainTabView() }` in the authenticated branch
(~line 163) with:

```
} else if authManager.hasActiveSubscription {
    MainTabView()                                   // full access

} else if !authManager.hasCompletedFreeDemo {
    MainTabView()                                   // demo mode

} else if !authManager.hasDismissedPostDemoWall && !bypassWallThisSession {
    NavigationStack {
        PaywallView(authManager: authManager,
                    isDismissible: !postDemoWallIsHard,
                    source: .postDemo)
    }

} else {
    MainTabView()                                   // post-demo, gated
}
```

Walkthrough finishes → `markFreeDemoCompleted()` → RootView re-renders into the
ask. User dismisses → `markPostDemoWallDismissed()` → re-renders into
MainTabView. No sheet coordination, no presentation races.

The anonymous branch (lines 168-210) needs **no change** — it already forces
account creation after paywall #1, which is the sequencing you want. Those users
fall through to the branch above once authenticated.

Add both flags to the diagnostic dump (~line 334) and the `.onChange` logging
(~line 368).

---

## 2. Wall hardness — a remote flag, not a rebuild

PostHog is configured (`WingmanApp.swift:250-301`) but **no feature flags are
used anywhere in the app yet.** This is the cheapest way to keep the hard-wall
decision open.

- `postDemoWallIsHard` reads `PostHogSDK.shared.isFeatureEnabled("post_demo_wall_hard")`,
  defaulting `false`
- Ship v1.0 with the flag off — the ask is dismissible
- Once there's data on `paywall_viewed → purchased` at `source: post_demo`,
  flip it server-side. **No App Store release required**, and it can run as a
  proper A/B test rather than a one-way bet
- Cache the value at launch alongside the existing `/decide` handling; do not
  read it mid-render

**Offline escape hatch — required the moment hardness can be true.** The dismiss
overlay in `PaywallView` currently renders whenever `isDismissible`, and its
comment notes it is available in every state "so a user is never trapped if
RevenueCat is slow or offline." Condition it on
`isDismissible || viewModel.offerings == nil`.

The offline dismissal must **not** call `markPostDemoWallDismissed()` — it sets
the session-scoped `bypassWallThisSession` in RootView, so the ask re-arms on
next cold start. That is deliberately the Gleam pressure-valve behavior, and it
also guarantees an App Reviewer who force-quits sees a working app.

`footerLinks` already renders Restore / Terms / Privacy in every state —
required by Guideline 3.1.2 and non-negotiable on a non-dismissible screen. Do
not regress it.

---

## 3. Walkthrough — net new

Verified: **no walkthrough, coach-mark, tooltip, or mascot code exists.** Mascot
asset is `scenario_user`, already in the project.

- `Walkthrough/WalkthroughCoordinator.swift` — `ObservableObject` owning a step
  enum: `welcome → prompt_scenario → scenario_running → scenario_done →
  prompt_lesson → lesson_running → lesson_done → profile_handoff → finished`.
  `@StateObject` in `MainTabView` (`MainTabView.swift:19-23`, beside
  `coursesRouter` / `tabBarVisibility`), injected via `.environmentObject` into
  all four tabs so state survives tab switches and navigation pushes.
- `Walkthrough/MascotOverlayView.swift` — speech bubble, layered into the
  `ZStack` at `MainTabView.swift:26` above the tab bar.
- Step advancement hooks existing completion points rather than new ones:
  `practiceScenarioCompleted` and `lessonCompleted` already fire
  (`Analytics.swift:25-30`), and `LessonCompleteView` / `QuestionsCompleteView`
  are natural handoff moments.
- Coordinator drives tab switching for the "let's go to the course section"
  beat — `MainTabView` already listens on `NavigateToHomeView`
  (`MainTabView.swift:58`); same pattern, or bind `selectedTab` through the
  coordinator.
- `finished` → `authManager.markFreeDemoCompleted()` → the ask.

**Constraint worth enforcing at review:** the mascot walks the user *into doing*
the scenario. If it drifts into pointing at tab-bar chrome, it becomes a generic
coach-mark tour, gets skipped, and the plan loses its point.

---

## 4. Demo mode — restricting, not intercepting

During demo mode the three gates must not fire; instead everything except the
two demo items renders as *unavailable*. Reuse the existing progression-lock
visuals rather than inventing a second lock language.

- **Scenarios** — `Practice.isLocked` (`Practice.swift:23`) is computed by the
  service post-fetch. In demo mode, lock everything except `order_index = 1`.
  `PracticeView.loadAndNavigate` already no-ops on locked practices (line 132).
- **Courses / lessons** — `CoursesViewModel.courseLockReason(_:)`
  (`CoursesViewModel.swift:239`) is a single chokepoint feeding both
  `CourseCardContent` and `CourseDetailSheet`. Add a `.demoMode` case to
  `CourseLockReason` with its own banner copy. Inside the demo course,
  `CourseDetailSheet.loadLessons()` (line 178) already force-locks lessons when
  the course is locked — extend it to lock all but the first.
- **Daily practice** — `HomeView.swift:138`. Not part of the script; reuse the
  existing disabled-button treatment (`canStart`, line 133).
- **Approach logging** — free, no change. Already shipped.

### Gates that stay (unchanged from today)

| File | Line | Gate |
|---|---|---|
| `Home/HomeView.swift` | 307 | daily practice |
| `PracticeGame/PracticeView.swift` | 66 | scenarios |
| `Courses/CourseDetailSheet.swift` | 156 | lessons |
| `Payment/SubscriptionGateModifier.swift` | — | keep |

These become **backstops**, not the conversion mechanism. The post-demo ask is
the conversion mechanism.

---

## 5. Second-chance offer

Two open items, both your call — the trigger survives because
`SubscriptionGateModifier` survives.

1. **Mechanics.** `wingman_yearly_discount` is Pay-Up-Front
   (`RevenueCatConfig.swift:44`). Playing a free scenario does not consume
   StoreKit intro eligibility — eligibility is per *subscription group*
   (see the comment at `SubscriptionGateModifier.swift:86`), so a demo user is
   still fully eligible for the 3-day trial. Offering pay-up-front withdraws a
   $0 door and replaces it with a $X door, and taking it permanently burns their
   trial eligibility. **Recommendation:** reconfigure the discount product to
   keep the 3-day trial at a lower post-trial price. RevenueCat dashboard
   change; the existing `checkTrialOrIntroDiscountEligibility` plumbing already
   supports it.
2. **Review risk.** Exit offers are currently rejected under Guidelines 5.6 and
   3.1.2 as manipulative. New app, no approval history. **Recommendation:** ship
   v1.0 without it, add in v1.1. Flagged, noted, your decision.

---

## 6. Analytics

Add to `Analytics.Event` (`Analytics.swift:23`):

```
walkthrough_started / walkthrough_step_completed / walkthrough_abandoned / walkthrough_completed
demo_scenario_completed
demo_lesson_completed
```

Add `case postDemo` to `PaywallSource` (`PaywallView.swift:16`) — keep
`featureGate`, the gates still emit it.

The funnel to watch:

```
install → onboarding_complete
       → paywall#1_viewed → {purchased | dismissed}
       → walkthrough_started → demo_scenario_completed → demo_lesson_completed
       → paywall_viewed(source=post_demo) → purchased
```

The number that decides whether to flip `post_demo_wall_hard`: **purchase rate
at `source=post_demo` vs `source=onboarding`.** If post-demo materially beats
onboarding, the demo is doing its job and closing the door is worth testing.
Judge on revenue per install, not on activation rate.

---

## Phasing

| Phase | Work | Blocked by | Status |
|---|---|---|---|
| **1** | Both flags + persistence + resets | — | ✅ done |
| **2** | RootView four-way branch; ask renders after demo | 1 | ✅ done |
| **3** | `.postDemo` source; PostHog flag; offline escape hatch | 2 | ✅ done |
| **4** | Demo-mode locking across scenarios / courses / daily practice | 1, 2 | next |
| **5** | Trial timeline on paywall | — (independent) | |
| **6** | Walkthrough coordinator + mascot overlay + step hooks | 4 | |
| **7** | Analytics events | 6 | |

### Corrections found while implementing 1-3

- **This plan under-specified the load paths.** There are **three**, not one:
  `.signedIn`, `.initialSession`, *and* `restoreSessionGracefully()` — the last
  being the common cold-launch-with-cached-session path. Missing it would have
  left the new flags holding their global-key defaults on every relaunch, so a
  returning user would have been handed the demo again and again once phase 6
  landed. All three now call both new loads.
- **`PaywallSource.postDemo` uses the implicit raw value `"postDemo"`**, not
  `"post_demo"`. The `source` property's existing values (`onboarding`,
  `featureGate`) are camelCase; mixing conventions inside one property makes
  PostHog filters error-prone. Event *names* stay snake_case as before.
- **DEBUG-only launch-argument overrides added** so phases 1-3 are testable
  before the walkthrough exists:
  - `-forceFreeDemoCompleted YES` — jump straight to the post-demo ask
  - `-forceDismissedPostDemoWall NO` — re-arm the ask on a repeat run
  - `-postDemoWallIsHard YES` — hard mode without touching PostHog

### Verification state after 1-3

Nothing calls `markFreeDemoCompleted()`, and nothing writes the
`free_demo_completed` metadata mirror, so `hasCompletedFreeDemo` is `false` for
every user. Branches 4c/4d are therefore unreachable in production and every
user who previously reached MainTabView still reaches it via 4a or 4b. **Phases
1-3 are behaviourally inert by design** — infrastructure only. The single live
change is one `$feature_flag_called` event per launch for
`post_demo_wall_hard`.

Phases 1-3 are self-contained and testable without the mascot: set
`hasCompletedFreeDemo` by hand, confirm the ask appears, Restore works, the flag
flips hardness, and killing the network produces the escape hatch rather than a
brick. Phase 5 is independent and can ship any time.

---

## Open items

1. **Scenario 2's unlock threshold.** `required_lessons_completed` is a
   threshold against `totalLessonsCompleted()` across *all* courses
   (`Practice.swift:15`). The demo completes one lesson. **If scenario 2's
   threshold is 1, the demo silently unlocks it.** Check the `scenarios` table
   before shipping. (Cannot query it from here — the connected Supabase MCP
   points at a different project.)
2. **Walkthrough abandonment.** If the user force-quits mid-walkthrough,
   `hasCompletedFreeDemo` is still false, so they resume in demo mode. Decide
   whether the coordinator resumes at the last step or restarts. Restarting is
   simpler and probably fine.
3. **Streaks during demo.** `StreakStore` behavior while daily practice is
   unavailable — confirm nothing breaks or misreports.
4. **Demo re-grant after sign-out.** Assumed no: the per-user key survives, so
   the same account gets one demo. A new account gets a fresh one.
5. **Trial timeline copy** — `Today: full access → Day 2: reminder → Day 3:
   billed`. Highest-value remaining paywall addition, independent of everything
   above.
