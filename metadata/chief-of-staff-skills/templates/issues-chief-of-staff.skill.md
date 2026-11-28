# BizApps Issues Skill

**BizApps Issues** (`mj-bizapps-issues`) is installed in this MemberJunction workspace. Use this skill whenever the user asks about open support tickets, bug reports, feature requests, customer feedback, issue triage queues, escalation risks, or issue comment threads.

## 1. Core Data Access & RLS Rules

- **Always query and mutate through `RunView` and `BaseEntity` under the caller's `ContextUser` — NEVER execute raw SQL.**
- Row-Level Security and entity permissions govern which issues and comments the caller can see:
  - Different users may have access restricted by `AppScope`, `ReporterPersonID`, `AssigneeRecordID`, or role permissions (for example, external/portal users seeing only their own reported issues and non-internal comments vs. internal support leads seeing triage queues and `Source = 'internal'` notes).
  - Never expose `MJ_BizApps_Issues: Issue Comments` where `Source = 'internal'` to external reporters or audiences who cannot see internal comments via RLS.
  - Never infer or summarize issues outside what `RunView` returns for the caller.
- When updating an issue (`StatusID`, `AssigneeEntityID`/`AssigneeRecordID`, `Priority`, `Severity`), always save via the `MJ_BizApps_Issues: Issues` entity (never direct SQL) so `IssueEntityServer.Save()` automatically assigns `IssueNumber`, stamps `ResolvedAt`/`ClosedAt`, and fires configured `IssueType` lifecycle hooks (`OnCreate`, `OnStatusChange`, `OnAssign`, `OnClose`).

## 2. Core Entities & Key Fields

| Entity Name | Purpose & Key Fields |
| --- | --- |
| `MJ_BizApps_Issues: Issues` | Core issue/case/ticket records: `IssueNumber`, `Title`, `Description`, `IssueTypeID` / `IssueType`, `StatusID` / `Status`, `Severity` (`Critical`, `High`, `Medium`, `Low`), `Priority` (`Critical`, `High`, `Medium`, `Low`), `ReporterPersonID`, `ReporterEmail`, `AssigneeEntityID` + `AssigneeRecordID` (polymorphic FK to e.g. `MJ_BizApps_Common: People` or `MJ: AI Agents`), `SourceEntityID` + `SourceRecordID` (polymorphic origin link), `AppScope`, `ResolvedAt`, `ClosedAt`, `CreatedByPersonID`, `PredictedCriticalEscalationProbability`, `PredictedEscalationRiskBand` (`Critical`, `High`, `Medium`, `Low`), `PredictedEscalationScoredAt`. |
| `MJ_BizApps_Issues: Issue Comments` | Threaded discussion on an issue: `IssueID`, `Body`, `AuthorPersonID`, `AuthorEmail`, `Source` (`inbound`, `internal`, `outbound`). |
| `MJ_BizApps_Issues: Issue Status` | Configurable lifecycle statuses ordered by `Sequence`: `New` (`IsDefault = 1`), `Triaged`, `In Progress`, `Waiting on Reporter`, `Resolved` (`IsResolved = 1`), `Closed` (`IsTerminal = 1`), `Won't Fix` (`IsTerminal = 1`). |
| `MJ_BizApps_Issues: Issue Types` | Issue categories with default routing/hooks: `Bug` (High), `Feature Request` (Medium), `Question` (Low), `Feedback` (Medium); `DefaultPriority`, `DefaultTaskTypeID`, `OnCreateActionID`, `OnStatusChangeActionID`, `OnAssignActionID`, `OnCloseActionID`, `IsActive`. |
| `MJ_BizApps_Issues: Issue Number Sequences` | Internal per-scope sequence counters (`ScopeCode`, `NextSequenceNumber`); read-only reference, never mutate directly. |

## 3. Common Chief of Staff Workflows

- **Triage & escalation briefing:** Query `MJ_BizApps_Issues: Issues` via `RunView` filtering out terminal statuses (`ClosedAt IS NULL`) and ordering by `Severity` / `Priority` / `PredictedCriticalEscalationProbability DESC`. Lead with `Critical` / `High` severity items, issues flagged `PredictedEscalationRiskBand IN ('Critical', 'High')`, and untriaged `New` issues.
- **Personal action queue:** Resolve the caller's `PersonID` (`MJ_BizApps_Common: People`) and filter `MJ_BizApps_Issues: Issues` by `AssigneeRecordID = '<PersonID>'` (for issues assigned to them) or `ReporterPersonID = '<PersonID>'` (for issues they reported), highlighting items in `Waiting on Reporter`.
- **Thread review & follow-up:** Load `MJ_BizApps_Issues: Issue Comments` by `IssueID` ordered by `__mj_CreatedAt ASC` to summarize the latest `inbound` customer ask, `outbound` responses, and (when visible to the caller) `internal` engineering/support notes.
- **Creating or transitioning issues:** Confirm with the user before creating, reassigning, or closing an issue; resolve `IssueTypeID` from `MJ_BizApps_Issues: Issue Types` and `StatusID` from `MJ_BizApps_Issues: Issue Status` rather than hardcoding IDs.
