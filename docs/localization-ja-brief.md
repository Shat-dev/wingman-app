# Japanese: translator and reviewer brief (Release D)

One Japanese: `ja`. No regional variants. A phone set to `ja-JP` (or `ja-US`, a Japanese speaker abroad) runs the same `ja`.

Everything in Japanese is a machine draft (Claude), marked **needs review**. Arthur has no Japanese proofreader yet, so this brief is written for two readers: the session that translates the interface, lessons and database content, and the native reviewer who will be hired later. It is modelled on the French brief ([localization-fr-brief.md](localization-fr-brief.md)); German's log ([localization-de-progress.md](localization-de-progress.md)) shows how the hard terms were first handled. The decisions marked **(decided)** come from Arthur's prompt ([localization-release-d/japanese-prompt.md](localization-release-d/japanese-prompt.md)) and are not reopened here.

Interface draft (Phase 2): `localization/ja/catalogs.ja.json` (English key → Japanese). After editing it, re-import and validate:

```bash
python3 scripts/import_catalog_translations.py ja localization/ja/catalogs.ja.json
```

```bash
python3 scripts/check_string_catalogs.py --languages de,es,fr,ja --strict-lengths
```

Once a reviewer has signed a batch off, re-import with `--reviewed` to mark it "translated". Never do that for a machine draft.

## Who reads this

Men, mostly 25–55 (45+ is about a third of onboarding answers), who are nervous about talking to women in person. The voice is a calm, encouraging coach a few years ahead of the reader: not a ナンパ師, not a 恋愛工学 blogger, not a therapist, not a customer-service script. Plain, warm, a little dry.

What that means in Japanese:

- **Polite です・ます, never stiff.** 「〜しましょう」「〜してみてください」「〜で大丈夫です」. No 謙譲語 or 尊敬語 stacks (「〜していただけますと幸いです」「ご確認くださいませ」), no 「お客様」. Money and legal lines are the one place a slightly more formal です・ます is right (「請求されます」「解約できます」).
- **Never rough or chummy.** No 「〜しろ」「〜するな」「〜だぜ」「〜じゃん」, no 「お前」「君」. No net slang or words that date (「ワンチャン」「ガチで」「陽キャ／陰キャ」「非モテ」「草」). The reader may be 50.
- **Short sentences.** One idea per sentence. Japanese lets a sentence run on with 〜て、〜て、〜が; don't. Break where the English breaks.
- **Katakana loanwords only where a Japanese man would actually say them** (デート, メッセージ, リアクション, タイミング, コース, レッスン, クイズ, シナリオ, レベル). Where a plain Japanese word exists, use it (自信, not コンフィデンス; 雑談, not スモールトーク). A wall of katakana reads like a business seminar.

**Adapt, don't translate word for word (decided).** The principles stay exactly as the English has them. The examples move to Japan:

- US places → **東京, 大阪 or 福岡** (and nearby places for a second city: 横浜, 京都, 神戸, 熊本). "The brewery up 3rd street" → 「角のクラフトビールの店」. Her travels abroad (Portugal, Iceland) stay: they're her story.
- Imperial → metric: 18 inches → 45cm; three feet → 1メートルほど; four feet → 1メートル強.
- Contact details: where the English swaps numbers or Instagram, the Japanese **exchanges LINE (decided)**: 「LINE交換しませんか？」「よかったらLINE教えてください」. "Get her number" → 「連絡先を聞く」 or 「LINEを交換する」. Keep Instagram only where the scene is about her posts or photos.
- Sport: baseball images work as they are in Japan (野球). Football → サッカー. American football, hockey → rewrite or use 野球 / サッカー.
- Everyday settings: grocery store → スーパー; train / subway → 電車 / 地下鉄; coffee shop → カフェ; bar → バー (居酒屋 only if the scene is a group dinner); dog park → ドッグラン; high school → 高校; college → 大学; Uber → タクシー; networking event → 交流会; dollars → 円 with a believable amount.
- Well-known quotes use their established Japanese form: "Fall seven times and stand up eight" is the Japanese proverb itself (七転び八起き); Laozi → 千里の道も一歩から; Gretzky → 「打たないシュートは、100%外れる」. People's names take their usual katakana (ウェイン・グレツキー, セネカ, マーク・トウェイン).
- Idioms: translate the point, not the picture. "Screw it" → 「えい、やってしまえ」; "you earned your drink" → 「その一杯は、がんばったご褒美です」.

**Do not change the advice itself (decided).** Where the English advice may not suit Japan, translate it faithfully and add one line to "Cultural flags for Arthur" in the progress log (lesson or row id, one sentence on the concern). Known areas: direct compliments to a stranger, touch, persistence on the street, approaching at work or at the gym, and the step from dating to a couple (in Japan usually an explicit 告白). Arthur decides; nothing is rewritten. **Statistics keep their numbers (decided)**, are worded neutrally (never 「日本の男性の…」, and no invented source such as 「海外の調査では」), and each one is logged as a flag.

## Fixed choices

| Topic | Rule |
|---|---|
| Register | **です・ます** in all running text: lessons, explanations, feedback, errors, notifications, the paywall. **(decided)** |
| Buttons, nudges, titles | Short forms: a noun phrase (「続ける」「次へ」「復元」「今日の練習」), 〜しよう / 〜してみよう for a nudge (「まず一歩、踏み出そう」), 体言止め or plain form for titles and headings. Plain endings inside a heading are fine; **inside one paragraph or one screen of body text, don't mix です・ます with plain endings** (Phase 5 searches for this). Text inside 「」 (speech, inner voice, example lines) follows its speaker, not this rule. |
| Addressing the reader | **Drop the pronoun.** 「あなた」 only where the sentence fails without it; never 「君」「お前」. **(decided)** "Men your age" → 「同年代の男性」; "You are not alone" → 「ひとりではありません」. |
| The reader speaking | First person in testimonials, pledges and example lines the reader might say: **僕** by default; drop it where possible; **俺** only in scenario dialogue once the scene has moved to casual speech; 私 in a work setting. |
| Instructions | 「〜しましょう」「〜してください」「〜してみてください」. Prohibitions: 「〜しないでください」「〜はやめましょう」; for the strict lines (consent, safety) 「決して〜しないでください」. |
| Never translate | **Wingman**, **XP**, in Latin letters **(decided)**; the validator checks both. No space between them and Japanese: 「Wingmanで」「100XPを獲得」. |
| Category names | Translated, as the other languages do **(decided)**; analytics keeps the English. Draft: マインドセットと土台 (Mindset & Foundations), アプローチの実践 (Approach Mechanics), 会話の流れ (Conversation Flow), 恋の駆け引きと相性 (Flirting & Chemistry), 日常への定着と熟達 (Integration & Mastery). "&" becomes と, never ＆. |
| Level | **レベル%lld** for both the XP level and the four approach levels (one string serves both). "Level %lld: %@" → 「レベル%1$lld：%2$@」. |
| Approach (verb) | **声をかける** (「女性に声をかける」), the ordinary neutral phrase. 「話しかける」 where the point is starting to talk rather than walking up. |
| Approach (noun) | **アプローチ** for one logged approach, counts and labels (「アプローチを記録」「記録したアプローチ」「ダイレクトアプローチ」). The native noun 声かけ is avoided in the interface: in Japan it is also the word police bulletins use (「声かけ事案」). It may be used as an App Store search keyword. |
| ナンパ | **Not in the interface, not in the listing (decided).** In lessons it is allowed only where the English itself is talking about pickup culture as something Wingman is not: "pickup artist" → ナンパ師, "pickup lines" → ナンパの決まり文句. Never for what the reader does. Each use is logged. |
| Women | **女性.** 「女の子」 only inside casual dialogue where an English speaker would say "girl" about an adult; never 「女」 alone. The woman in a lesson example is 「彼女」 or, better, 「相手」 where it reads naturally. |
| Scenario dialogue | Natural spoken Japanese **(decided)**. He opens in polite speech (です・ます, 「すみません」) as a Japanese man would with a stranger; where the English scene shows rapport building, moving to casual speech (タメ口) is part of that and is shown, usually after she relaxes first or with a light 「タメ口でもいい？」 kind of beat only if the English has room for it. Her lines are written as a Japanese woman would say them (私; no stage-feminine 「〜だわ」「〜かしら」), not translated line by line. |
| Women's names | Same name, **in katakana (decided)**; he addresses her with **さん** (ソフィーさん) unless the scene has become casual. Mapping below. |
| Subscription | **サブスクリプション** (Apple's own word in Japanese iOS). A plan is a **プラン**: 月額プラン (Monthly Plan), 年額プラン (Yearly Plan), 「%lldか月プラン」. "Manage Subscriptions" → 「サブスクリプションを管理」. To cancel is **解約** (「いつでも解約できます」), not キャンセル. "Restore Purchases" → 「購入を復元」. |
| Free trial | **無料トライアル** (Apple's term). Badge: 「%lld日間無料」. (Wingman has no free trial today, but the strings exist.) |
| Price lines | "per month" → 「月額」 or 「／月」 as the row needs; "per year" → 「年額」; "only %@ per week" → 「1週間あたり%@」 (no わずか if the tick limit or row is tight). The price is always one finished `%@` from the App Store (`¥5,800`): **never write 円, ¥ or 税込 around it.** |
| Terms / Privacy | Footer links and full names are the same in Japanese: **利用規約** / **プライバシーポリシー**. The pages themselves stay English for now (decision D6). |
| iOS words | Settings → **設定** ("App Store settings" → 「App Storeの設定」); notifications → 通知; Sign in with Apple → 「Appleでサインイン」; "Continue with Google" → 「Googleで続ける」; account → アカウント. |
| Numbers | **Half-width digits, `%` and Latin letters; no space between them and Japanese (decided):** 「45%の男性」「3日連続」「レベル4」「5分」. Thousands with a half-width comma (1,000); round large numbers the Japanese way (60,000 → 6万). Counters: 〜回, 〜人, 〜日, 〜分, 〜か月 (**か月**, not ヶ月 or カ月), 〜つ with digits (「3つのコツ」). Idioms keep kanji: 一歩, 一言, 一人, 二人, 一度. |
| Ranges | **18〜24歳** with the wave dash 〜 (U+301C) in sentences and labels. |
| Punctuation | **Full-width 、。「」！？（）： (decided).** Quotation: 「」, nested 『』; never "" or “” around Japanese. Ellipsis: one **…** (U+2026) in the interface (「読み込み中…」), …… only in dialogue for a trailing voice. No half-width `,` `.` `!` `?` `:` in a Japanese sentence (inside a price or a number is fine). ！ and ？ sparingly: one is enough, and a coach doesn't shout. After ！ or ？ in mid-text, a full-width space only if another sentence follows on the same line. |
| Emphasis | English italics and CAPS don't exist in Japanese: use 「」 for a term, or word order. "ONE-TIME OFFER" → 「1回限りのオファー」. |
| Dates and time | Dates on screen come from iOS in the phone's format (2026年11月16日); none are written by hand. In text: 11月16日, 火曜日, 午後8時. "%lld days ago" → 「%lld日前」; "1 day ago" → 「昨日」. |
| Plurals | Japanese has only the **other** form **(decided)**: fill that one (「%lldレッスン」). Add another only if Xcode or the validator asks. |
| Fonts | Nothing to do in the text, but keep it in mind: Manrope has no Japanese glyphs, so Japanese is drawn in iOS's own font with Manrope digits beside it. Avoid full-width digits and letters partly for this reason. |

### Women's names (scenarios)

| Scenario | English | Japanese |
|---|---|---|
| 1 Bar Window | Sophie | ソフィー |
| 2 Coffee Connections | Lauren | ローレン |
| 3 Fetch & Flirt | Naomi | ナオミ |
| 4 Read Between Lines | Katie | ケイティ |
| 5 Final Stretch | Amber | アンバー |
| 6 Delayed Together | Mel | メル |
| 7 Catch the Drift | Sara | サラ |
| 8 Picture This | Emily | エミリー |
| 9 Carton Collision | Claire | クレア |
| 10 Progressive Overload | Zoe | ゾーイ |
| 11 Trail Talk | Natalie | ナタリー |
| 12, 13, 14 | (unnamed) | (unnamed) |
| 15 Study Buddy | Aurelie | オレリー |

Any other name that turns up in a lesson or a quiz question takes its usual katakana and is added here.

## Validator notes

`scripts/check_string_catalogs.py` was adjusted for Japanese in Phase 0; what a translator needs to know:

- **Width, not characters.** A full-width character counts as 2, a half-width one as 1. The paywall tick limit of 36 is therefore **18 full-width characters**, fewer if the tick has no digits or Latin letters to save room.
- **Brand terms** are found without spaces around them (「Wingmanで」 and 「100XP」 pass). They must stay in half-width Latin letters: 「ウィングマン」 or 「ＸＰ」 fails.
- **`%` is safe before Japanese.** The Spanish and French problem (`% d`, `% s` read as a placeholder) only bites when a space or a Latin d, s, u, f or @ follows the sign. 「45%の男性」 passes. Keep it that way: no space after `%`, and don't follow it with a Latin word. In a format string the literal sign is `%%`: 「%lld%%オフ」.
- **Reordering needs positional placeholders.** Japanese puts the verb last, so most two-placeholder sentences reorder: `%1$@`, `%2$lld`, `%3$@`. Types and counts must match the English exactly.
- Never put an invisible character in a string to get past a check.

## Hard limits

- **Paywall ticks: width 36 at most** (18 full-width characters). Rewrite, don't truncate. Japanese is compact, so most ticks fit if they are written as a short benefit (「断られる怖さに、もう負けない」 is 14).
- **Placeholders must survive exactly**, moved where Japanese word order needs them.
- **Link targets stay as they are.** In 「[利用規約](terms)」 the words in brackets are translated, `(terms)` never is.
- **Prices come from the App Store** as one formatted string. Build the sentence so the price can be any currency (a Japanese speaker abroad sees `$69.99` or `€64,99`): 「本日のお支払いは%1$@（最初の1年間）。その後は年額%2$@です。」 Never 「%@円」.
- **Sentences built from pieces** (streaks, "days ago", the offer disclosure) must read correctly in Japanese order. Where one cannot, it goes to "Questions for Arthur" in the log with the screen name, not into a workaround.
- **Buttons stay short**: aim for 8 full-width characters or fewer on a primary button; Japanese can't be abbreviated the way English can.

## Glossary for lessons and database content

Keep these consistent across all 25 courses, the quiz and the scenarios. The first use of a technical term in a lesson may add the English in brackets, as German did (「社会的証明（social proof）」), then never again.

| English | Japanese | Notes |
|---|---|---|
| approach (verb / one approach) | **声をかける** / **アプローチ** | 「彼女に声をかける」「最初のアプローチ」. "Approach anxiety" → 「声をかける前の不安」. Not ナンパ, not 声かけ (see Fixed choices). |
| opener | **最初のひと言** | "direct / indirect opener" → 「ストレートなひと言」/「さりげないひと言」. Example openers are rewritten as natural spoken Japanese, polite form. |
| close / closing | **次につなげる** | asking for LINE or the next step (「連絡先を聞いて次につなげる」). Course 15 "Closing" → 「次につなげる」. Not クロージング (sales jargon). "Assumed close" → 「当然のように次の約束を提案する」. |
| calibration / calibrated | **相手の反応を見て合わせる**; short: 「空気を読む」「加減する」 | 「キャリブレーション」 once, in brackets, where the lesson is about the skill itself. |
| outcome independence | **結果に左右されない**（こと） | same wording in courses 4 and 17 and the quiz |
| social proof | **社会的証明** | established term |
| frame / frame control | **場の空気**; 「自分のペースを保つ」「空気をリードする」 | not フレーム |
| rep / reps / volume | **1回** / **場数** (「場数を踏む」) / **数をこなす** | 「レップ」 only in a gym metaphor |
| banter | **軽い掛け合い** | |
| teasing | **軽くからかう**, noun **からかい** | 「いじる」 is comedy-show slang and can read as bullying; use it only in casual dialogue |
| cheeky / cheekiness | **いたずらっぽい** / **いたずら心** | |
| flirting / flirty | **恋の駆け引き** (noun); verbs by meaning: 「好意をさりげなく伝える」「ドキッとさせる」; flirty → 「思わせぶりな」「色気のある」 | Japanese has no everyday word for "flirt"; フラート is not understood. See Open points. |
| chemistry / spark | **相性**, 「惹かれ合う感じ」 / **ときめき** | |
| attraction | **惹かれる気持ち**, 「魅力」 | "attractive woman" → 「気になる女性」 or 「魅力的な女性」 |
| escalation / escalate | **距離を縮める**, 「一歩進める」 | physical escalation: 「スキンシップを少しずつ増やす」, always with the English's conditions |
| rejection | **断られること**; 「拒絶」 where the lesson talks about the fear as a concept | "fear of rejection" → 「断られる怖さ」 |
| small talk | **雑談** | |
| momentum | **（会話の）流れ**, 「勢い」 | |
| threading / threads | **話の糸口**, 「糸口を拾う」 | |
| validating | **受け止める** (「気持ちを受け止める」) | not バリデーション |
| attunement | **波長を合わせる** | |
| vulnerability | **弱さを見せること**, 「自己開示」 | "oversharing" → 「話しすぎ」 |
| sticking point | **つまずきポイント** | |
| growth / fixed mindset | **成長マインドセット / 固定マインドセット** | the common business-book terms |
| confidence | **自信** | "composure" → 「落ち着き」 |
| overthinking | **考えすぎ** | |
| grounding | **グラウンディング** on first use with a gloss (「今ここに意識を戻す」), then the gloss | |
| mirroring | **ミラーリング** | established |
| eye contact | **アイコンタクト**, 「目を合わせる」 | |
| body language | **ボディランゲージ**, 「しぐさ」 | |
| compliment | **褒め言葉**, 「褒める」 | |
| consent | **同意** | |
| date | **デート** | |
| streak | **連続記録**; 「%lld日連続」 | |
| daily practice | **今日の練習** | |
| course / lesson | **コース** / **レッスン** | |
| scenario | **シナリオ** | |
| quiz | **クイズ** | |
| log (the journal) | **記録** | |
| sexual tension | **異性としての緊張感**; 「性的な緊張感」 where the English is explicit | |
| disqualification (21_1) | rewrite by meaning, as the other languages did: 「すぐにはなびかない」「簡単には感心しない」 | PUA term with no neutral Japanese |
| pickup artist / pickup lines | **ナンパ師** / **ナンパの決まり文句** | the only allowed uses of ナンパ; log each |
| consent wording (17_3) | as strict as the English **(decided)**: 「相手が心地よく感じているとはっきりわかるサインがない限り、決して触れないでください。少しでも身を引いたら、すぐにやめましょう。」 | do not soften, do not add 「できれば」「なるべく」 |

## Look at these first

These carry money, law or first impressions. They are the priority set for a paid native check (Phase 5 puts them first in the review pack).

1. **Paywall and one-time offer**: the "billed today … then …" disclosure sentences, 「すぐに請求されます…」, the weekly price line, the ticks, the offer headline. Read them with a yen price and a dollar price in place of `%@`. Japan's rules for subscriptions sold to consumers expect the price, the renewal and how to cancel to be unmistakable; flag anything ambiguous.
2. **Sign-in legal line**: 「続けると、[利用規約](terms)と[プライバシーポリシー](privacy)に同意したことになります」.
3. **Onboarding**: the questions and answers, the statistic screens (each also a cultural flag), the commitment pledge and the growth chart labels.
4. **Lesson 17_3** (respect and consent) and every touch rule in courses 20, 21 and 25.
5. **Notifications**: the daily reminder and the tips-and-offers permission text.
6. **Course titles**: drafted in the catalog before the lessons are translated; the lesson iterations log better ones rather than silently changing them.

## Open points

- **"Flirting".** 恋の駆け引き is the nearest everyday phrase, but 駆け引き also means "playing games", which the lessons warn against. Alternatives a reviewer might prefer: 「口説き方」 (stronger, closer to "wooing"), or keeping フラート with a gloss. It appears in a category name and two course titles, so it's worth an early opinion.
- **アプローチ vs 声かけ** as the noun (see Fixed choices). A reviewer may judge 声かけ harmless inside a dating app.
- **Foreign names in Japanese settings.** The decision is to keep each woman's name in katakana, while the examples move to Tokyo, Osaka or Fukuoka. ソフィー in a Tokyo bar reads as a foreign woman (ナオミ and サラ happen to pass as Japanese names). The scenes still work; changing a name changes it for every language, so it stays Arthur's call.
- **僕 as the default first person.** 俺 is what many men say among friends; 僕 is the safe written choice for a 25–55 audience.
- **iOS wording** (設定, サブスクリプションを管理, 購入を復元, 無料トライアル) is written from Apple's Japanese usage as I know it, not checked on a Japanese iPhone from here. A reviewer with an iPhone can confirm in a minute.
- **Line breaks.** Japanese wraps between any two characters, so a heading can leave one character alone on its last line. That can't be seen from the text; it is a sweep item, with the font look.
- Course titles marked uncertain in the Phase 2 log.

## Still to translate (after this brief)

| Part | Size | How |
|---|---|---|
| Interface catalogs | 586 strings (407 + 179) | `localization/ja/catalogs.ja.json` → import and check (above) |
| Lesson overlays | 34,475 English words, 1,531 items, 25 files | `python3 scripts/lesson_overlays.py export ja <folder>` / `check ja` |
| Database content | 765 quiz questions, 15 scenarios (796 text screens, 276 options) | `localization/ja/db/*.json` → `python3 scripts/db_translations_sql.py ja` (never run the SQL) |
| Review pack | | `python3 scripts/review_pack.py ja` (choices in `localization/ja/review/choices.json`) |
| App Store listing, subscription display names | | `docs/japanese-app-store-listing.md`; Arthur enters it in App Store Connect |

Until those are done, a Japanese build would show a partly English app. Don't ship from this branch in that state.
