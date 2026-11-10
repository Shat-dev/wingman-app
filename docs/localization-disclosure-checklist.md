# Subscription disclosure checklist

For requirement 13 of the localization work: the paywall's subscription disclosure must stay complete and accurate in every language. Tick this once per language during QA, on the real storefront for that language, with real prices on screen.

Plan reference: WP4 item 7 in [localization-implementation-plan.md](localization-implementation-plan.md). Written 2026-11-10 from the code on branch `localization-release-a`.

## How to use it

1. Open the screen on a build that loads real products (a Debug build does not).
2. For each row, check the text is present, in the right language, and matches what the App Store will actually charge.
3. Every number must come from the product: no price, currency, trial length or period typed into a translation.

## Main paywall

| # | What the user must be told | Where it is today | Source of the value | State |
|---|---|---|---|---|
| 1 | Name of the plan | Plan row title: "Yearly Plan", "Monthly Plan" | Catalog text | Present |
| 2 | Billing period | Under the full price: "per year", "per month" | Catalog text, chosen by the product's period | Present |
| 3 | Full price | Plan row, right side: "$69.99" | StoreKit's own formatted price | Present |
| 4 | Price per week (a convenience, not a requirement) | Plan row: "only $1.35 per week" | Product price ÷ 52 or 4.33, formatted by the product's formatter (slice 25) | Present |
| 5 | Free trial length | Badge on the selected plan: "3-day Free Trial" | The product's introductory offer (slice 26) | Present |
| 6 | Nothing is charged at the start of a trial | Under the button: "No payment now. Cancel anytime before your trial ends." | Catalog text, shown only to a user who gets the trial | Present |
| 7 | **What is charged when the trial ends, and that it renews until cancelled** | **Not stated as a sentence.** The price and period are in the plan row; nothing says the plan renews | — | **Not stated; left as is by decision (D4: option C, 2026-11-10)** |
| 8 | A user with no trial is charged straight away | Under the button: "Billed immediately. Cancel anytime in App Store settings." | Catalog text, shown only to a user without the trial | Present |
| 9 | How to cancel | "Cancel anytime in App Store settings." (no-trial variant). The trial variant says "before your trial ends" but not where | Catalog text | Present for no-trial; partial for trial |
| 10 | Privacy Policy link | Footer: "Privacy" | `Constants.PRIVACY_POLICY_URL`, in-app browser | Present |
| 11 | Terms link | Footer: "Terms" | `Constants.TERMS_CONDITIONS_URL`, in-app browser | Present |
| 12 | Restore purchases | Footer: "Restore" | RevenueCat restore | Present |

## One-time offer

| # | What the user must be told | Where it is today | Source of the value | State |
|---|---|---|---|---|
| 1 | What is charged today | Under the button: "$34.99 billed today …" and the price pair above | StoreKit's formatted introductory price | Present |
| 2 | How long the discount lasts | "off your first year" and "… for your first year …" | The introductory offer's period (slice 27) | Present |
| 3 | What it renews into, and how often | "… then $69.99/year." | StoreKit's formatted price and the product's period | Present |
| 4 | The saving, if a percentage is shown | "50%" | Computed from this storefront's two prices, rounded down; no percentage shown if the numbers are implausible | Present |
| 5 | How to cancel | "Cancel anytime in App Store settings." | Catalog text | Present |
| 6 | Privacy, Terms, Restore | Footer | Same as the main paywall | Present |

## Per-language sign-off

Copy this table for each language when it is added.

| Language | Storefront checked | Main paywall rows 1–12 | Offer rows 1–6 | Currency matches storefront | Checked by | Date |
|---|---|---|---|---|---|---|
| English | United States | Rows 1–4 and 8–12 seen with real products, 2026-11-10. Rows 5–6 (trial) not seen: no trial was offered on that run. Row 7 left as is by decision (D4: option C) | Rows 1–6 seen with real products, 2026-11-10 | Yes: USD throughout | Claude, Release run on the simulator | 2026-11-10 |

## Decision D4: the missing sentence (row 7)

> **Decided 2026-11-10: option C. The paywall stays as it is.** Row 7 remains as it stands: the price and period are shown in the plan row, and no sentence states the renewal. Nothing was built for D4. The options below are kept for the record, in case the question comes back (for example from App Review).

The plan approved adding "one full sentence under the button, per trial / no-trial variant, built from StoreKit values". Two things were not decided, and both change what English users read on the screen that earns the money, so they are yours:

**1. The audit missed that a line already exists under the button.** So the choice is between changing that line and adding a second one.

**2. The exact words.**

| Option | With a free trial | Without a free trial | Cost |
|---|---|---|---|
| **A. Add a second, smaller line below the existing one** (my recommendation) | Existing line unchanged, then: "Then $69.99 per year. Renews automatically until you cancel." | Existing line unchanged, then: "$69.99 per year. Renews automatically until you cancel." | One more 12 pt line in the pinned block under the button. The line that reassures about the trial stays exactly as it has been tested |
| B. Replace the existing line with a fuller one | "No payment now. After your 3-day free trial, $69.99 per year until you cancel. Cancel anytime in App Store settings." | "Billed immediately: $69.99 per year until you cancel. Cancel anytime in App Store settings." | The existing line changes, and grows from one line to two or three |
| C. Leave the paywall as it is | — | — | Row 7 stays open; the renewal is only implied by the plan row |

In all options the price, the period and the trial length are placeholders filled from the product, and the monthly plan reads "per month".

Why I lean to A: it adds the two missing facts (the price after the trial, and that it renews) without touching the sentence that carries the trial reassurance, and reverting it is deleting one line. Whichever you choose ships in Release A, where its effect on conversion can be read on English traffic alone.

Nothing has been built for D4 yet.
