# Spanish and French (Release C): setup log

Branch `localization-release-c`. Prompt: [localization-release-c/0-setup-prompt.md](localization-release-c/0-setup-prompt.md). This is the shared log for the setup session (Phases 0–3). The two language sessions keep their own logs: `docs/localization-es-progress.md` and `docs/localization-fr-progress.md`. Everything translated here is a machine draft (Claude), marked "needs review"; nothing is applied to the live database.

Model: German (Release B), see [localization-de-progress.md](localization-de-progress.md) and [localization-de-brief.md](localization-de-brief.md).

## Where it stands

Phase 0 started. The branch exists and holds the three prompts.

## Summary

| Phase | Part | State |
|---|---|---|
| 0 | Branch and prompts | Done (2026-11-15) |
| 0 | Language-generic scripts and tests | Not started |
| 1 | Spanish brief | Not started |
| 1 | French brief | Not started |
| 2 | Spanish UI catalogs | Not started |
| 2 | French UI catalogs | Not started |
| 3 | Spanish and French sessions started | Not started |

## Log

- **2026-11-15. Branch and prompts.** `localization-release-b` had two commits not in `Shat` (`69c708b`, `893fef3`, "Final changes", 13 Nov: Xcode 26.6 upgrade check, one analyzer setting, test-target ID reorder, scheme tweaks). Asked Arthur; he chose to branch from `localization-release-b`, so `localization-release-c` starts at `893fef3` and includes them. `Shat` is unchanged. The uncommitted scheme change (Run language `de` → `en`) stays uncommitted, as the prompt says. First commit: "Release C: prompts".

## Questions for Arthur

None open.
