---
"@mj-biz-apps/issues-entities": patch
"@mj-biz-apps/issues-core": patch
"@mj-biz-apps/issues-ng": patch
"@mj-biz-apps/issues-core-entities-server": patch
---

Add shared `IssueEngineBase` (`BaseEngine` with active `ProviderToUse` override and `CanRead` gating), harden `IssueEngine`, replace repeated Issue Types/Statuses `RunView` waterfalls in Angular views with cached engine lookups, tighten typed `simple` projections with explicit `Fields`, and document the 5-Rule BizApps Performance & Caching Standard in `CLAUDE.md` and `AGENTS.md`.
