---
"@mj-biz-apps/issues-core-entities-server": patch
"@mj-biz-apps/issues-server": patch
"@mj-biz-apps/issues-ng": patch
---

Consolidate remaining security hardening fixes from #37, #48, and #87 on top of #90:

- **Server-stamped comment authorship (`IssueCommentEntityServer`)**: Register priority-2 server subclass for `MJ_BizApps_Issues: Issue Comments` that stamps `AuthorPersonID`/`AuthorEmail` from `ContextCurrentUser` on insert (overriding client values), freezes authorship fields on update, and restricts content edits (`Body`, `Source`, `IssueID`) to the original author.
- **Parameterized & bounded sequence allocation (`SequenceService` + `IssueEntityServer`)**: Bind `AppScope` as a positional parameter (`?` on SQL Server, `$1` on PostgreSQL) instead of inlining a SQL literal, strip NUL bytes and bound scope length to 50 characters, validate `AppScope` against `^[A-Za-z0-9 _-]{1,50}$` on issue insert, and log `IssueNumber` update-tampering attempts while restoring the stored value.
- **Viewer-scoped "My Issues" page (`MyIssuesPageComponent`)**: Filter `LoadData()` to the signed-in user's `ReporterEmail` via `EscapeSQLString` (returning empty lists when no user is identified) instead of returning the 50 newest issues org-wide.
- **Script credential hygiene (`scripts/pg-objectmodel-test.mjs`)**: Remove committed password fallback and fail fast when `PGPASSWORD` is unset.
