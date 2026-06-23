# BizAppsIssues — Implementation Plan

A new MemberJunction **OpenApp** providing reusable case / issue / ticket primitives.
Built to be the shared foundation that **Izzy** (Freshdesk/Zendesk-style UX) layers on top
of, and the "phone home" destination for MJC cloud feedback — replacing the bespoke
feedback machinery proposed in **PR #2699**.

> Design origin: Amith's thread on PR #2699 — keep the MJ Framework core thin, move
> ticketing/case semantics into a separate installable app, and add a generic
> "Shell Extension" registration point to the framework rather than hardcoding a
> feedback entry into core.

---

## Locked Decisions

| Decision | Choice |
|---|---|
| **v1 scope** | Thin foundational layer: issue + task core, **comments included**. Full ticketing UX deferred to Izzy. |
| **External sync (GitHub/Zendesk/Jira)** | **Deferred to v1.1** — pluggable provider abstraction + GitHub provider + webhook + email loop. |
| **bizapps-tasks reuse** | Depend on it. Reuse the **Task Type action-hook pattern** and spawn/link **Tasks** for the actual work via the existing polymorphic `TaskLink`. |
| **Shell Extension** | **Companion MJ-core PR now** — generic registry; BizAppsIssues registers its feedback entry through it. |
| **Dev branch (all repos)** | `claude/ecstatic-dijkstra-749jex` |

---

## Dependency Chain

```
bizapps-common   (Person, Organization, Address…)         schema __mj_BizAppsCommon
      ▲
bizapps-tasks    (Task, TaskType+action hooks, TaskLink)   schema __mj_BizAppsTasks
      ▲
bizapps-issues   (Issue, IssueType, IssueStatus, Comment)  schema __mj_BizAppsIssues   ◄── NEW
      ▲
Izzy             (SLAs, queues, portal, KB, agent triage)
```

`bizapps-issues` declares **both** `mj-bizapps-tasks` and `mj-bizapps-common` as `mj-app.json`
dependencies (it FKs into `__mj_BizAppsTasks.TaskType` and `__mj_BizAppsCommon.Person`).

---

## Phase 0 — Repo Scaffold

Clone the **bizapps-tasks** layout exactly. It is the proven standalone-app template.

```
bizapps-issues/
  mj-app.json                 name: mj-bizapps-issues, displayName: "Issues",
                              icon: fa-solid fa-bug (or fa-life-ring),
                              schema: { name: "__mj_BizAppsIssues", createIfNotExists: true },
                              mjVersionRange: ">=5.0.0 <6.0.0",
                              dependencies: [ mj-bizapps-tasks, mj-bizapps-common ]
  package.json                workspaces: ["packages/*"]; turbo build scripts;
                              overrides pinning @memberjunction/core + global
  mj.config.cjs               entityPackageName: @mj-biz-apps/issues-entities;
                              output targets (EntitySubclasses / ActionSubclasses /
                              GraphQLServer / Angular / DBSchemaJSON);
                              newEntityDefaults.NameRulesBySchema →
                                { __mj_BizAppsIssues : "MJ.BizApps.Issues: " }
  turbo.json, tsconfig.json
  apps/
    MJAPI/      (port 4101)   GraphQL API server; .env symlink → ../../.env
    MJExplorer/ (port 4301)   Angular UI
  packages/
    Entities/   @mj-biz-apps/issues-entities   role: library  (CodeGen entity subclasses)
    Actions/    @mj-biz-apps/issues-actions    (CodeGen action subclasses)
    Core/       @mj-biz-apps/issues-core       role: library  (real logic — services/engine)
    Server/     @mj-biz-apps/issues-server     role: bootstrap, startupExport: LoadBizAppsIssuesServer
    Angular/    @mj-biz-apps/issues-ng         role: bootstrap, startupExport: LoadBizAppsIssuesClient
  migrations/
    B…__v1.0.x_Schema_and_Tables.sql
    V…__v1.0.x_Fix_Schema_Info_and_Entity_Names.sql   (prefix + entity renames only)
    v5/                        (CodeGen output committed here)
  metadata/                    (seed data lives here — see Phase 3, NOT in migrations)
    issue-statuses/  issue-types/
```

**Loading wiring** (mirrors tasks):
- Server: register the package in MJAPI's `mj.config.cjs` `dynamicPackages` (or the app's
  bootstrap import) → `LoadBizAppsIssuesServer()` triggers `@RegisterClass` registrations.
- Client: static import in MJExplorer's `open-app-bootstrap.generated.ts` →
  `LoadBizAppsIssuesClient()`.

---

## Phase 1 — Migration (baseline `B…` script)

Schema `__mj_BizAppsIssues`. **App-managed migration conventions** (per bizapps-tasks, NOT
MJ-core migration rules): `__mj_CreatedAt` / `__mj_UpdatedAt` columns ARE written explicitly
(`DATETIMEOFFSET NOT NULL DEFAULT GETUTCDATE()`); CodeGen still owns FK indexes + views +
stored procs. Add `sp_addextendedproperty` for every business column.

### Tables (v1)

**1. `IssueType`** — lifecycle automation, mirrors `TaskType`'s action-hook pattern.
```
ID, Name (UNIQUE), Description, IconClass,
DefaultPriority NVARCHAR(20) DEFAULT 'Medium'  CHECK IN (Low,Medium,High,Critical),
DefaultTaskTypeID  UNIQUEIDENTIFIER  → __mj_BizAppsTasks.TaskType(ID)   -- spawned work type
OnCreateActionID         → __mj.[Action](ID)
OnStatusChangeActionID   → __mj.[Action](ID)
OnAssignActionID         → __mj.[Action](ID)
OnCloseActionID          → __mj.[Action](ID)
IsActive BIT DEFAULT 1
+ __mj_CreatedAt/UpdatedAt
```

**2. `IssueStatus`** — workflow states (seeded). Drives the board columns later.
```
ID, Name (UNIQUE), Description, Sequence INT DEFAULT 100,
IsDefault BIT DEFAULT 0, IsTerminal BIT DEFAULT 0, ColorCode NVARCHAR(20)
+ __mj_CreatedAt/UpdatedAt
```

**3. `Issue`** — the core case/ticket/feedback record.
```
ID, Title NVARCHAR(500), Description NVARCHAR(MAX),
IssueTypeID   → IssueType(ID)            (NOT NULL)
StatusID      → IssueStatus(ID)          (NOT NULL)
Severity NVARCHAR(20) DEFAULT 'Medium'   CHECK IN (Low,Medium,High,Critical)
Priority NVARCHAR(20) DEFAULT 'Medium'   CHECK IN (Low,Medium,High,Critical)
-- Reporter (who raised it)
ReporterPersonID  → __mj_BizAppsCommon.Person(ID)   (nullable — external reporters may not exist as Person)
ReporterEmail NVARCHAR(320)
-- Polymorphic assignee (verbatim from TaskAssignment): a Person OR an AI Agent
AssigneeEntityID  → __mj.Entity(ID)       (nullable)
AssigneeRecordID  NVARCHAR(450)           (nullable)
-- Polymorphic source: WHAT the feedback/issue is about (any record in the system)
SourceEntityID    → __mj.Entity(ID)       (nullable)
SourceRecordID    NVARCHAR(450)           (nullable)
AppScope NVARCHAR(255)                    -- which app/product this issue belongs to
ResolvedAt DATETIMEOFFSET, ClosedAt DATETIMEOFFSET
CreatedByPersonID → __mj_BizAppsCommon.Person(ID)
+ __mj_CreatedAt/UpdatedAt
```

**4. `IssueComment`** — threaded discussion.
```
ID, IssueID → Issue(ID) (NOT NULL),
Body NVARCHAR(MAX),
AuthorPersonID → __mj_BizAppsCommon.Person(ID) (nullable),
AuthorEmail NVARCHAR(320),
Source NVARCHAR(20) DEFAULT 'internal'   CHECK IN ('internal','email','external')
                                          -- 'external' reserved for v1.1 sync
+ __mj_CreatedAt/UpdatedAt
```

> **Work items** are NOT a new table. An Issue produces `Task` records (bizapps-tasks), linked
> back to the Issue via the existing polymorphic `__mj_BizAppsTasks.TaskLink`
> (`EntityID` = the Issues entity, `RecordID` = the Issue's ID). Sub-tasks, assignment,
> dependencies, Kanban/Gantt all come for free from bizapps-tasks.

### Entity naming
A `V…_Fix_Schema_Info_and_Entity_Names.sql` (same as tasks) sets
`SchemaInfo.EntityNamePrefix = 'MJ.BizApps.Issues: '` and renames:
`MJ.BizApps.Issues: Issues`, `… Issue Types`, `… Issue Statuses`, `… Issue Comments`.

---

## Phase 2 — CodeGen

Run `npm run mj:codegen` against a clean DB with the app schema migrated.
Commit generated output: entity subclasses, action subclasses, GraphQL resolvers,
Angular forms, and the `migrations/v5/CodeGen_Run_*.sql`. **Never hand-edit generated files.**

After CodeGen, the strongly-typed `IssueEntity`, `IssueTypeEntity`, `IssueStatusEntity`,
`IssueCommentEntity` exist — only then write dependent TypeScript (no `.Get()/.Set()`).

---

## Phase 3 — Seed Data (metadata, NOT SQL)

> ⚠️ **Do NOT copy bizapps-tasks' SQL `V…_Seed_Data.sql` approach** — that's an anti-pattern
> being corrected in tasks. Per the MJ root guide, lookup/reference tables are seeded via
> **`.mj-sync.json` metadata files**, never SQL `INSERT`s in migrations. Metadata seeds are
> version-controlled, declarative, support `@lookup:` references, and `mj sync push` handles
> idempotent upsert.

Create one metadata directory per seeded entity under `metadata/`, each with an
`.mj-sync.json` config (entity name, filePattern, pull defaults) plus the seed-record JSON
file. Omit `primaryKey` / `sync` blocks — mj-sync populates them on first push.

```
metadata/
  issue-statuses/
    .mj-sync.json                 entity: "MJ.BizApps.Issues: Issue Statuses"
    .issue-statuses.json          array of { "fields": { … } } records
  issue-types/
    .mj-sync.json                 entity: "MJ.BizApps.Issues: Issue Types"
    .issue-types.json
```

- **IssueStatus**: `New` (IsDefault), `Triaged`, `In Progress`, `Waiting on Reporter`,
  `Resolved`, `Closed` (IsTerminal), `Won't Fix` (IsTerminal) — with Sequence + ColorCode.
- **IssueType**: `Bug`, `Feature Request`, `Question`, `Feedback` — each optionally referencing
  a `DefaultTaskTypeID` via `@lookup:MJ.BizApps.Tasks: Task Types.Name=…`.

Push with `npx mj sync push --dir=metadata`. `mj-app.json` already points `metadata.directory`
at `metadata/`, so installs apply these automatically.

---

## Phase 4 — Core Service Layer (`packages/Core`)

Plain service/engine classes (no Angular), following tasks' `services/` pattern.

- **`IssueEngine`** (extends `BaseEngine`, cached + reactive via `ObserveProperty`) — loads
  IssueTypes/IssueStatuses for fast lookup; exposes `Issues$` observable for UI.
- **`IssueService`** — create/triage/transition logic:
  - `CreateIssue(...)` — resolve reporter (Person by email or anonymous), set default status/type.
  - `TransitionStatus(issue, newStatus)` — fires `IssueType.OnStatusChangeActionID` hook.
  - `Close(issue)` — fires `OnCloseActionID`, stamps `ClosedAt`.
- **`IssueWorkService`** — `SpawnTask(issue, taskType?)`: creates a `Task` via Metadata and a
  `TaskLink` back to the Issue. Uses bizapps-tasks entities directly (typed imports).
- Action-hook firing reuses the **same mechanism tasks uses** for its `On…ActionID` columns
  (study `TaskService` and copy the invocation pattern; actions invoked via the Action engine).

All server-side calls pass `contextUser`. Functions ≤ ~40 lines; decompose.

---

## Phase 5 — Angular (`packages/Angular`)

- Generated forms for the 4 entities (CodeGen, `maxComponentsPerModule: 20`).
- A **`ReportIssueComponent`** (feedback/report dialog) — the entry point that the Shell
  Extension (below) surfaces. Uses `<mj-dialog>`, `<mj-dropdown>`, `<mj-loading>`,
  `--mj-*` tokens; confirm button LEFT.
- `LoadBizAppsIssuesClient()` tree-shaking export wired from `public-api.ts`.

---

## Companion PR — MJ Core "Register a Shell Extension"

**Separate PR in `memberjunction/mj`** (branch `claude/ecstatic-dijkstra-749jex`).
Keeps the framework thin (Amith's ask) and removes the hardcoded feedback entry from MJServer.

- A small **shell-extension registry** in the Explorer shell: installed apps contribute menu
  items (e.g. into the avatar / user context menu) declaratively via metadata or a
  `@RegisterClass`-discoverable contribution.
- Minimal contract: `{ label, icon, location: 'avatar-menu' | 'context-menu' | …, onSelect }`.
- BizAppsIssues registers a **"Report an Issue / Submit Feedback"** entry that opens
  `ReportIssueComponent`.
- Scope this PR minimally — just the extension point + one consumer (the feedback entry).
  Do not absorb broader nav refactors.

---

## Relationship to PR #2699 (supersession path)

| #2699 element | Fate |
|---|---|
| `UserFeedbackSubmission` table (MJ core) | **Replaced** — the `Issue` record itself holds reporter + source; v1.1's `IssueExternalLink` holds the GitHub mapping. |
| `/webhooks/github/feedback` router in MJServer | **Relocated** to BizAppsIssues Server as a generic `/webhooks/issues/:providerType` endpoint (v1.1). |
| GitHub HMAC verify / idempotency / comment sanitize / email-on-update | **Becomes the `GitHubIssueProvider` reference implementation** (v1.1). |
| Hardcoded feedback entry point | **Replaced** by the Shell Extension registration. |

Net: #2699's engineering isn't discarded — it's re-homed into the app + provider abstraction.
Recommend a note on the thread proposing #2699 be held/closed in favor of this app.

---

## v1.1 Preview — External Sync (fast-follow, NOT this build)

New tables: **`IssueProvider`** (ProviderType GitHub/Zendesk/Jira/Izzy + config + credential ref)
and **`IssueExternalLink`** (Issue ↔ external key/URL). New abstraction:

```
abstract BaseIssueProvider          // Core, @RegisterClass keyed by ProviderType
  CreateExternalIssue(issue): ExternalLink
  UpdateExternalIssue(link, changes)
  AddComment(link, comment)
  VerifyWebhook(headers, rawBody): boolean
  NormalizeWebhookEvent(payload): IssueProviderEvent   // status change | new comment
```

`GitHubIssueProvider` first; generic webhook endpoint resolves provider via ClassFactory →
verify → normalize → write `IssueComment` (Source='external') / transition `Status` →
`CommunicationEngine` emails the reporter. Izzy later ships an `IzzyIssueProvider` — zero core
changes.

---

## Build Order & Checkpoints

1. **Scaffold** repo (Phase 0) → **checkpoint: review skeleton before SQL.**
2. **Migration** baseline (Phase 1) → **checkpoint: review DDL before CodeGen.**
3. **CodeGen** (Phase 2) + commit generated.
4. **Seed** (Phase 3).
5. **Core services** (Phase 4) → `npm run build` per package; add Vitest.
6. **Angular** forms + ReportIssueComponent (Phase 5).
7. **Companion MJ shell-extension PR** (parallel track once contract is agreed).
8. Wire feedback entry → ReportIssueComponent end-to-end; manual verify via Playwright.
9. **v1.1**: provider abstraction + GitHub + webhook + email (supersede #2699).

---

## Open Items To Confirm Before Coding

1. **App icon** — `fa-bug`, `fa-life-ring`, or `fa-ticket`?
2. **Severity vs Priority** — keep both on `Issue` (recommended: Severity = impact,
   Priority = scheduling), or collapse to one for v1?
3. **Seed status/type values** — confirm the starter sets in Phase 3.
4. **Shell-extension contract** — confirm the minimal interface + the one location
   (avatar menu) before opening the MJ PR.
5. **Repo creation** — confirm `memberjunction/bizapps-issues` exists / should be created,
   and that v1 publishes under `1.0.0`.
