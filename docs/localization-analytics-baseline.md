# Localization analytics baseline (prerequisite P4)

Captured 2026-11-10 from PostHog project 393936 (Wingman), production events only, last 90 days.
Purpose: the reference set for the parity test and the Release A soak in [localization-implementation-plan.md](localization-implementation-plan.md). After Release A, every value seen for these properties must already appear in this file, or in the app's canonical constants where noted.

Counts are for orientation only. The values are what matters.

## 1. Onboarding answers (person properties)

Multi-select answers are stored ", "-joined; they are split into single options here.

**`onboarding_motivation`** (multi-select; question shipped 2026-11-09, so data is thin)

| Value | Users |
|---|---|
| Want more confidence in general | 7 |
| Done with dating apps | 1 |
| Tired of being on my own | 1 |
| Back on the market after a breakup or divorce | 1 |

Not yet observed but valid, from `OnboardingFlow.swift:84-91`: "I freeze up around women I find attractive", "Other".

**`onboarding_barriers`** (multi-select)

| Value | Users |
|---|---|
| Not knowing what to say or how to start | 385 |
| Fear of rejection or being embarrased | 268 |
| Worrying about coming across wrong | 188 |
| Fear of social consequences | 150 |
| Other | 81 |

The misspelling "embarrased" is the real stored value and must be preserved.

**`onboarding_goals`** (multi-select)

| Value | Users |
|---|---|
| Creating attraction and romantic interest | 410 |
| Learning how to approach | 371 |
| Keeping conversations going | 352 |
| Better mindset & confidence | 336 |
| Other | 55 |

**`onboarding_age`**

| Value | Users |
|---|---|
| 25-34 | 220 |
| 35-44 | 122 |
| 18-24 | 99 |
| 45+ (legacy, pre-split) | 86 |
| 45-54 | 69 |
| 55+ | 43 |

**`onboarding_last_approach`**

| Value | Users |
|---|---|
| Within the past week | 321 |
| Within the past month | 108 |
| A few months ago | 83 |
| Never approached before | 70 |
| More than a year ago | 57 |

One user carries the stray value "25-34" under this key. It is an existing data oddity, not a valid option.

**`onboarding_approach_frequency`**

| Value | Users |
|---|---|
| Most times | 217 |
| Sometimes | 213 |
| Every time | 128 |
| Rarely | 54 |
| No, I usually go for it | 29 |

## 2. Lesson events: `lesson_id` → `lesson_name`, `category`

Events: `lesson_started`, `lesson_completed`, `lesson_quiz_started`, `lesson_quiz_completed`, `lesson_quiz_abandoned`, `lesson_quiz_unavailable`. 94 lessons, all observed.

| lesson_id | lesson_name | category |
|---|---|---|
| lesson_1_1 | You are not your thoughts | Beliefs & Reframes |
| lesson_1_2 | Rejection isn't personal | Beliefs & Reframes |
| lesson_1_3 | Rewrite the Story | Beliefs & Reframes |
| lesson_1_4 | Confidence Comes from Evidence | Beliefs & Reframes |
| lesson_1_5 | Growth mindset vs Fixed mindset | Beliefs & Reframes |
| lesson_2_1 | Fear Shrinks When You Chase it | Fear & Exposure |
| lesson_2_2 | Own Your Presence in Public | Fear & Exposure |
| lesson_2_3 | Using Breath to Reduce Fear | Fear & Exposure |
| lesson_2_4 | Anchor Points: Staying Grounded | Fear & Exposure |
| lesson_3_1 | Your body speaks first | Presence & Expressions |
| lesson_3_2 | The Power of a Calm Voice | Presence & Expressions |
| lesson_3_3 | Energy Is Contagious | Presence & Expressions |
| lesson_3_4 | Smile First, Speak Second | Presence & Expressions |
| lesson_4_1 | Nothing to Prove | Inner Stability |
| lesson_4_2 | Own Your Pace | Inner Stability |
| lesson_4_3 | Outcome Independence | Inner Stability |
| lesson_4_4 | Handling Positive Responses | Inner Stability |
| lesson_5_1 | Build the Body, Build the Belief | Non-negotiables |
| lesson_5_2 | Grooming Is Essential | Non-negotiables |
| lesson_5_3 | Hygiene Goes a Long Way | Non-negotiables |
| lesson_5_4 | Fashion and Style | Non-negotiables |
| lesson_6_1 | Hesitation Guarantees the Loss | Approach Readiness |
| lesson_6_2 | Life's Fun If You Open Your Mouth | Approach Readiness |
| lesson_6_3 | Curiosity Beats Agenda | Approach Readiness |
| lesson_6_4 | You're Always in the Field | Approach Readiness |
| lesson_7_1 | The 3-Second Rule | The Physical Approach |
| lesson_7_2 | Approach Angle & Distance | The Physical Approach |
| lesson_7_3 | Your Body in Motion | The Physical Approach |
| lesson_7_4 | Eye Contact & First Impression | The Physical Approach |
| lesson_8_1 | Indirect Openers | The Opener |
| lesson_8_2 | Direct Intent Openers | The Opener |
| lesson_8_3 | Frame Control | The Opener |
| lesson_8_4 | Voice Mechanics | The Opener |
| lesson_9_1 | Reading Her Response | Reading & Responding |
| lesson_9_2 | Responding to Neutral Signals | Reading & Responding |
| lesson_9_3 | Recognizing Signals: A Guide | Reading & Responding |
| lesson_10_1 | Daytime Approaches | Situational Specific Approaches |
| lesson_10_2 | Nighttime Approaches | Situational Specific Approaches |
| lesson_10_3 | Approaching Women in Groups | Situational Specific Approaches |
| lesson_11_1 | Curiosity Based Openers | Advanced Opening Techniques |
| lesson_11_2 | Assumption Based Openers | Advanced Opening Techniques |
| lesson_11_3 | Opinion Openers | Advanced Opening Techniques |
| lesson_11_4 | Setting Time Constraints | Advanced Opening Techniques |
| lesson_11_5 | Nighttime technique: False Exits | Advanced Opening Techniques |
| lesson_12_1 | Never Run Out of Things to Say | Small Talk & Momentum |
| lesson_12_2 | Use Observations and Statements | Small Talk & Momentum |
| lesson_12_3 | Maintain Momentum | Small Talk & Momentum |
| lesson_12_4 | When Silence Works | Small Talk & Momentum |
| lesson_13_1 | Listen for Subtext, Not Just Words | Listening & Attunement |
| lesson_13_2 | Listen to understand, not to reply | Listening & Attunement |
| lesson_13_3 | Validating Her Response First | Listening & Attunement |
| lesson_13_4 | Non-Verbal Listening Cues | Listening & Attunement |
| lesson_14_1 | Match First, Then Lead | Sharing & Vulnerability |
| lesson_14_2 | What to Share, What Not to Share | Sharing & Vulnerability |
| lesson_14_3 | Tell Stories That Connect | Sharing & Vulnerability |
| lesson_14_4 | Link the Stories Back to Her World | Sharing & Vulnerability |
| lesson_15_1 | Know When the Moment Is Ready | Closing |
| lesson_15_2 | End on Connection, Not Luck | Closing |
| lesson_15_3 | Make It Easy to Say Yes | Closing |
| lesson_15_4 | Assume she is interested | Closing |
| lesson_16_1 | Resetting After Energy Drops | Advanced Conversation Skills |
| lesson_16_2 | Disagree Without Disconnecting | Advanced Conversation Skills |
| lesson_16_3 | Make Being With You Fun | Advanced Conversation Skills |
| lesson_17_1 | The Goal of Flirting | Flirting Prerequisites |
| lesson_17_2 | Identifying the Signals | Flirting Prerequisites |
| lesson_17_3 | Respect | Flirting Prerequisites |
| lesson_17_4 | Energy | Flirting Prerequisites |
| lesson_18_1 | Humour: Banter and Teasing | Playfulness & Spark |
| lesson_18_2 | Light, Playful Challenges | Playfulness & Spark |
| lesson_18_3 | Add a Little Bit of Cheek | Playfulness & Spark |
| lesson_19_1 | Compliments That Actually Land | Compliments & Verbal Chemistry |
| lesson_19_2 | Being Nice Is Not Desire | Compliments & Verbal Chemistry |
| lesson_19_3 | One Line to Change the Dynamic | Compliments & Verbal Chemistry |
| lesson_20_1 | Eye Contact That Creates Tension | Physical Presence |
| lesson_20_2 | Using Proximity to Build Attraction | Physical Presence |
| lesson_20_3 | Using Mirroring to Build Rapport | Physical Presence |
| lesson_20_4 | When and How to Use Touch | Physical Presence |
| lesson_21_1 | Disqualification Techniques | Advanced Flirting Skills |
| lesson_21_2 | Flirt by Creating Sexual Tension | Advanced Flirting Skills |
| lesson_21_3 | Callbacks & Inside Jokes | Advanced Flirting Skills |
| lesson_22_1 | The Effect of Social Status | Upgrading Your Lifestyle |
| lesson_22_2 | The Interesting Man Advantage | Upgrading Your Lifestyle |
| lesson_22_3 | The Power of Mystery | Upgrading Your Lifestyle |
| lesson_22_4 | The Average of Your Social Circle | Upgrading Your Lifestyle |
| lesson_23_1 | Create More Chances to Connect | Creating Opportunities |
| lesson_23_2 | Train Where You Live | Creating Opportunities |
| lesson_23_3 | Home Court Advantage | Creating Opportunities |
| lesson_24_1 | Volume Creates Familiarity | Mastery & Identity |
| lesson_24_2 | Stay Consistent | Mastery & Identity |
| lesson_24_3 | From Technique to Intuition | Mastery & Identity |
| lesson_25_1 | The Experimental Mindset | Learning & Self Discovery |
| lesson_25_2 | Your Authentic Style | Learning & Self Discovery |
| lesson_25_3 | Identify Your Sticking Point | Learning & Self Discovery |
| lesson_25_4 | The Growth Plateau | Learning & Self Discovery |

## 3. Gate events: `course_title`, `previous_course_title`, `lesson_title`

`course_locked_encountered` (`course_id` → `course_title` ← `previous_course_title`):

| course_id | course_title | previous_course_title |
|---|---|---|
| course_2 | Fear & Exposure | Beliefs & Reframes |
| course_3 | Presence & Expressions | Fear & Exposure |
| course_4 | Inner Stability | Presence & Expressions |
| course_5 | Non-negotiables | Inner Stability |
| course_7 | The Physical Approach | Approach Readiness |
| course_8 | The Opener | The Physical Approach |
| course_9 | Reading & Responding | The Opener |
| course_11 | Advanced Opening Techniques | Situational Specific Approaches |
| course_13 | Listening & Attunement | Small talk & Momentum |
| course_14 | Sharing & Vulnerability | Listening & Attunement |
| course_19 | Compliments & Verbal Chemistry | Playfulness & Spark |
| course_20 | Physical Presence | Compliments & Verbal Chemistry |
| course_21 | Advanced Flirting Skills | Physical Presence |
| course_23 | Creating Opportunities | Upgrading Your Lifestyle |
| course_24 | Mastery & Identity | Creating Opportunities |
| course_25 | Learning & Self Discovery | Mastery & Identity |

`lesson_gate_blocked` uses the same `course_title` values, plus `lesson_title` values that match `lesson_name` in section 2 for the same `lesson_id`.

**Existing inconsistency to preserve, not fix, in Release A:** course 12 is "Small talk & Momentum" in gate events (from the Swift catalog) but "Small Talk & Momentum" in lesson events (from the lesson JSON). The two properties have different sources today. Each must keep its own current value.

## 4. Scenario events: `scenario_id` → `scenario_name`

| scenario_id | scenario_name |
|---|---|
| A1000001-0000-0000-0000-000000000001 | Bar Window |
| A1000002-0000-0000-0000-000000000002 | Coffee Connections |
| A1000003-0000-0000-0000-000000000003 | Fetch & Flirt |
| A1000004-0000-0000-0000-000000000004 | Read Between Lines |
| A1000005-0000-0000-0000-000000000005 | Final Stretch |
| A1000006-0000-0000-0000-000000000006 | Delayed Together |
| A1000007-0000-0000-0000-000000000007 | Catch the Drift |
| A1000008-0000-0000-0000-000000000008 | Picture This |
| A1000009-0000-0000-0000-000000000009 | Carton Collision |
| A1000010-0000-0000-0000-000000000010 | Progressive Overload |
| A1000011-0000-0000-0000-000000000011 | Trail Talk |
| A1000012-0000-0000-0000-000000000012 | Performance Review |
| A1000013-0000-0000-0000-000000000013 | House Wine |
| A1000014-0000-0000-0000-000000000014 | Dressed to Impress |
| A1000015-0000-0000-0000-000000000015 | Study Buddy |

"Practice Scenario" also appears 56 times against the Bar Window ID. It is the app's fallback title when the title lookup fails, and is a valid existing value.

## 5. Other display-text properties

**`level_name`** on `approach_logged` (`approach_level` → `level_name`)

| approach_level | level_name |
|---|---|
| 1 | Social Warm-up (from `LogApproachViewModel.swift:27`; not observed in the window) |
| 2 | Extended Conversation |
| 3 | Indirect Approach |
| 4 | Direct Approach |

**`headline`** on `commitment_pact_viewed` / `commitment_pact_committed`

| Value | Events |
|---|---|
| I am becoming a guy who takes action. | 1,277 |

This is the only value. 171 of those events have `personalized = true`, where the screen shows "I, {first name}, …", but the property still carries the generic sentence: the name is never sent. (An earlier version of this file assumed otherwise without checking; corrected 2026-11-10 against PostHog and the code.)

## 6. Screen names (`$screen_name`)

Auth, AuthAfterPurchase, AuthRequired, AuthSaveProgress, Course Detail, Courses, Daily Practice, Home, Landing, Lesson, Onboarding, OneTimeOffer, Paywall, Practice, Profile, Settings.

`SecondChanceOffer` also appears (56 events) from builds before 1.12; the screen no longer exists in the code. `Practice Detail` is defined in code (`PracticeDetailView.swift:74`) but was not observed.

## 7. Event names

Custom events seen in the window (60):

account_ask_skipped, account_deletion_started, account_linked, approach_logged, commitment_pact_committed, commitment_pact_viewed, course_locked_encountered, daily_challenge_completed, daily_challenge_started, free_lesson_claimed, lesson_completed, lesson_gate_blocked, lesson_quiz_abandoned, lesson_quiz_completed, lesson_quiz_started, lesson_started, notification_permission_result, onboarding_completed, onboarding_name_answered, onboarding_started, onboarding_step_viewed, one_time_offer_unavailable, paywall_dismissed, paywall_offerings_failed, paywall_plan_selected, paywall_purchase_cancelled, paywall_purchase_failed, paywall_purchase_started, paywall_purchase_succeeded, paywall_viewed, practice_scenario_completed, practice_scenario_started, purchases_restore_failed, purchases_restored, recovery_offer_dismissed, recovery_offer_not_eligible, recovery_offer_purchase_cancelled, recovery_offer_purchase_started, recovery_offer_viewed, recovery_offer_window_opened, review_prompt_requested, review_prompt_skipped, session_invalidated, smartlink_tap, social_proof_continued, subscription_entitlement_lost, subscription_expired, user_logged_in, user_logged_out, user_signed_up, walkthrough_completed, walkthrough_interrupted, walkthrough_nudge_shown, walkthrough_scenario_abandoned, walkthrough_started, walkthrough_step_viewed, walkthrough_suppressed, xp_award_failed, xp_awarded, xp_outbox_flushed.

Notes:
- `recovery_offer_*`, `onboarding_name_answered`, `free_lesson_claimed` and `walkthrough_scenario_abandoned` come from older builds or code paths not found in the 1.14 call-site scan; they are listed so their absence after Release A is not mistaken for a regression.
- `smartlink_tap` is fired by the website, not the app.
- Defined in 1.14 code but not observed in the window: `approach_log_failed`, `approach_deleted`, `lesson_quiz_unavailable`, `rate_app_tapped`, `daily_reading_goal_set`, `marketing_notification_opened`, `marketing_notifications_toggled`.
