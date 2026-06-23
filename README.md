<p align="center">
  <img src="https://raw.githubusercontent.com/MemberJunction/MJ/main/logo.png" alt="MemberJunction" width="120" />
</p>

<h1 align="center">BizApps Issues</h1>

<p align="center">
  <strong>Reusable issue / case / ticket management for the <a href="https://github.com/MemberJunction/MJ">MemberJunction</a> platform</strong>
</p>

<p align="center">
  <a href="#installation">Install</a> &middot;
  <a href="#entity-model">Entity Model</a> &middot;
  <a href="#how-it-fits">How It Fits</a> &middot;
  <a href="plans/IMPLEMENTATION_PLAN.md">Implementation Plan</a>
</p>

<p align="center">
  <img alt="MJ Version" src="https://img.shields.io/badge/MemberJunction-%3E%3D5.0.0%20%3C6.0.0-blue?style=flat-square" />
  <img alt="Angular" src="https://img.shields.io/badge/Angular-21-DD0031?style=flat-square&logo=angular&logoColor=white" />
  <img alt="TypeScript" src="https://img.shields.io/badge/TypeScript-5.9-3178C6?style=flat-square&logo=typescript&logoColor=white" />
  <img alt="License" src="https://img.shields.io/badge/License-ISC-green?style=flat-square" />
  <img alt="Node" src="https://img.shields.io/badge/Node-18%2B-339933?style=flat-square&logo=node.js&logoColor=white" />
  <img alt="Status" src="https://img.shields.io/badge/Status-Pre--release%20(v1%20in%20progress)-orange?style=flat-square" />
</p>

---

> ⚠️ **Status: early development.** This repository is being built out from the
> [implementation plan](plans/IMPLEMENTATION_PLAN.md). The entities, packages, and components
> described below are the **v1 design target**, not yet a shipped release. See the plan for the
> phased build order and current scope.

Issue, case, and ticket tracking is a universal need -- products collect bug reports and feature
requests, support teams manage cases, and apps need a way for users to send feedback and hear back.
BizApps Issues provides this as a reusable **MemberJunction Open App**: a thin, shared foundation of
issue/case primitives that any MJ application can depend on, rather than each app reinventing its own
ticketing tables and workflow.

It is deliberately **thin by design**. Heavy ticketing experiences (SLAs, queues, customer portals,
knowledge bases) are expected to be built *on top* of this app -- most notably by
[Izzy](https://github.com/MemberJunction/izzy) -- and external trackers (GitHub, Zendesk, Jira) plug
in through a provider abstraction rather than being hardcoded into the framework core.

---

## How It Fits

BizApps Issues sits in the BizApps layer cake, building on
[BizApps Tasks](https://github.com/MemberJunction/bizapps-tasks) and
[BizApps Common](https://github.com/MemberJunction/bizapps-common):

```
bizapps-common   People, Organizations, Addresses          __mj_BizAppsCommon
      ▲
bizapps-tasks    Tasks, Task Types (action hooks), links    __mj_BizAppsTasks
      ▲
bizapps-issues   Issues, Issue Types, Statuses, Comments    __mj_BizAppsIssues   ◄── this app
      ▲
Izzy             SLAs, queues, portal, KB, agent triage
```

**An Issue is the *case*; Tasks are the *work*.** Rather than reinventing assignment, dependencies,
and Kanban/Gantt, BizApps Issues reuses BizApps Tasks: resolving an issue spawns `Task` records
linked back to the issue via the existing polymorphic `TaskLink`. `IssueType` mirrors the proven
`TaskType` **action-hook pattern** (`OnCreate`, `OnStatusChange`, `OnAssign`, `OnClose`) so issue
lifecycle automation is declarative.

---

## Installation

BizApps Issues is a [MemberJunction Open App](https://github.com/MemberJunction/MJ/tree/main/packages/OpenApp).
Once published, install it into any MJ environment using the [MJ CLI](https://github.com/MemberJunction/MJ/tree/main/packages/MJCLI):

```bash
mj app install https://github.com/MemberJunction/bizapps-issues
```

This single command:

1. Fetches the `mj-app.json` manifest from this repository
2. Validates MJ version compatibility (`>=5.0.0 <6.0.0`)
3. Installs the dependencies [BizApps Tasks](https://github.com/MemberJunction/bizapps-tasks) and [BizApps Common](https://github.com/MemberJunction/bizapps-common) if not already present
4. Creates the `__mj_BizAppsIssues` database schema
5. Runs Skyway migrations to create the tables
6. Loads seed data (issue types + statuses) via mj-sync metadata
7. Installs npm packages into your MJAPI and MJExplorer workspaces
8. Configures server bootstrap (`@mj-biz-apps/issues-server`) in `mj.config.cjs`
9. Adds client bootstrap (`@mj-biz-apps/issues-ng`) to `open-app-bootstrap.generated.ts`

After installation, restart MJAPI and rebuild MJExplorer to activate.

### Manage the App

```bash
mj app list                     # See installed apps
mj app info bizapps-issues      # Show details and version
mj app upgrade bizapps-issues   # Upgrade to latest release
mj app disable bizapps-issues   # Temporarily disable
mj app enable bizapps-issues    # Re-enable
mj app remove bizapps-issues    # Uninstall (--keep-data to preserve schema)
```

---

## What You Get

### Database Tables (v1)

All tables live in the `__mj_BizAppsIssues` SQL schema, deployed via migrations.

| Category | Tables | Purpose |
|----------|--------|---------|
| **Core** | Issue | The case / ticket / feedback record, with polymorphic reporter, assignee, and source |
| **Classification** | IssueType, IssueStatus | Lifecycle automation (action hooks) and workflow states |
| **Collaboration** | IssueComment | Threaded discussion (internal / email; external reserved for sync) |

> **Work items are not a new table.** Issues produce `Task` records from
> [BizApps Tasks](https://github.com/MemberJunction/bizapps-tasks), linked back via the existing
> polymorphic `TaskLink` -- so sub-tasks, multi-person assignment, dependencies, and Kanban/Gantt
> come for free.

**Planned for v1.1 (external sync):** `IssueProvider` and `IssueExternalLink`, backing a pluggable
`BaseIssueProvider` abstraction (GitHub first; Zendesk / Jira / Izzy later) plus a generic webhook
endpoint and reporter email notifications.

### TypeScript Packages

| Package | NPM Name | Role |
|---------|----------|------|
| **Entities** | `@mj-biz-apps/issues-entities` | Strongly-typed entity classes with Zod validation |
| **Actions** | `@mj-biz-apps/issues-actions` | Server-side action handlers |
| **Core** | `@mj-biz-apps/issues-core` | IssueEngine, IssueService, issue→task spawning, lifecycle hooks |
| **Server** | `@mj-biz-apps/issues-server` | GraphQL resolvers and server bootstrap |
| **Angular** | `@mj-biz-apps/issues-ng` | UI components, generated forms, the "Report an Issue" entry point |

---

## Entity Model

```
┌────────────┐     ┌──────────────────────┐     ┌───────────────┐
│ IssueType  │────►│        Issue         │◄────│  IssueStatus  │
│            │     │                      │     │  (workflow)   │
│ On…ActionID│     │  Severity / Priority │     └───────────────┘
│ Default-   │     │  Reporter (Person /  │
│ TaskTypeID │     │   email)             │
└─────┬──────┘     │  Assignee (poly:     │     ┌───────────────┐
      │            │   Person or Agent)   │────►│ IssueComment  │
      │            │  Source (poly: any   │     │ (internal /   │
      │            │   record)            │     │  email)       │
      ▼            └──────────┬───────────┘     └───────────────┘
 BizApps Tasks                │ spawns + links via TaskLink
 TaskType                     ▼
                    BizApps Tasks: Task
```

### Key Design Patterns

**Polymorphic assignee** -- `AssigneeEntityID` + `AssigneeRecordID` (copied from BizApps Tasks) let
an issue be assigned to a Person *or* an AI Agent, so agent-driven triage needs no schema change.

**Polymorphic source** -- `SourceEntityID` + `SourceRecordID` capture *what the issue is about* --
any record in the system -- so feedback can point at the exact thing it concerns.

**Type-driven lifecycle** -- `IssueType` carries `OnCreate / OnStatusChange / OnAssign / OnClose`
action FKs (the BizApps Tasks `TaskType` pattern) plus an optional `DefaultTaskTypeID`, so triaging
an issue can auto-create work of the right type.

**Pluggable external trackers (v1.1)** -- a `BaseIssueProvider` abstraction keeps GitHub/Zendesk/Jira
sync out of the framework core. Each provider implements create/update/comment + webhook
verify/normalize; a single generic endpoint routes by provider type.

See the [Implementation Plan](plans/IMPLEMENTATION_PLAN.md) for the complete schema-level field
lists, migration conventions, and phased build order.

---

## Seed Data

Loaded via mj-sync **metadata files** (`metadata/`), not SQL inserts -- so values are
version-controlled, declarative, and customizable per deployment.

| Type Table | Included Records |
|------------|-----------------|
| **IssueType** | Bug, Feature Request, Question, Feedback |
| **IssueStatus** | New, Triaged, In Progress, Waiting on Reporter, Resolved, Closed, Won't Fix |

---

## Using BizApps Issues in Your Code

> API names below reflect the v1 design target and will be confirmed once CodeGen runs.

### Creating an Issue

```typescript
import { Metadata } from '@memberjunction/core';
import { IssueEntity } from '@mj-biz-apps/issues-entities';

const md = new Metadata();
const issue = await md.GetEntityObject<IssueEntity>('MJ.BizApps.Issues: Issues');
issue.Title = 'Export to CSV fails on large datasets';
issue.Description = 'Times out above ~50k rows.';
issue.ReporterEmail = 'user@example.com';
// IssueTypeID / StatusID resolved to the seeded "Bug" / "New" defaults
await issue.Save();
```

### Querying Issues

```typescript
import { RunView } from '@memberjunction/core';

const rv = new RunView();
const result = await rv.RunView<IssueEntity>({
    EntityName: 'MJ.BizApps.Issues: Issues',
    ExtraFilter: "Severity = 'High'",
    OrderBy: '__mj_CreatedAt DESC',
    ResultType: 'entity_object'
});
```

---

## Relationship to Izzy and "Phone Home" Feedback

This app is the shared substrate for two consumers:

- **Izzy** builds its Freshdesk/Zendesk-style support experience *on top of* these entities
  (extending, not duplicating), and can register itself as an issue provider.
- **MJC cloud feedback** uses BizApps Issues as the destination for in-product "Report an Issue /
  Submit Feedback" -- the entry point is surfaced through a framework **Shell Extension** rather than
  being hardcoded into MJ core. This supersedes the bespoke feedback machinery proposed in
  [MJ PR #2699](https://github.com/MemberJunction/MJ/pull/2699), re-homing it as the GitHub provider.

---

## Building an App That Depends on BizApps Issues

Declare the dependency in your `mj-app.json`:

```json
{
  "dependencies": [
    {
      "name": "mj-bizapps-issues",
      "repository": "https://github.com/MemberJunction/bizapps-issues",
      "versionRange": ">=1.0.0 <2.0.0"
    }
  ]
}
```

When users install your app, the MJ CLI installs BizApps Issues (and its own dependencies, BizApps
Tasks and BizApps Common) first if they aren't already present.

---

## Contributing (Developer Setup)

```bash
git clone https://github.com/MemberJunction/bizapps-issues.git
cd bizapps-issues
npm install
```

### Configure Environment

Create a `.env` file at the repo root:

```env
DB_HOST=localhost
DB_PORT=1433
DB_DATABASE=YourDatabase
DB_USERNAME=sa
DB_PASSWORD=yourpassword
GRAPHQL_PORT=4101
```

### Deploy and Build

```bash
npm run mj:migrate                   # Create schema and tables
npx mj-sync push --dir ./metadata    # Load seed data (issue types + statuses)
npm run mj:codegen                   # Generate TypeScript/GraphQL/Angular code
npm run build                        # Build all packages (Turborepo)
```

### Run Development Servers

```bash
npm run start:api      # GraphQL server at localhost:4101
npm run start:explorer # Angular app at localhost:4301
```

---

## Repository Structure

```
bizapps-issues/
├── mj-app.json                    # MJ Open App manifest
├── apps/
│   ├── MJAPI/                     # GraphQL API server (port 4101)
│   └── MJExplorer/                # Angular UI application (port 4301)
├── packages/
│   ├── Entities/                   # @mj-biz-apps/issues-entities
│   ├── Actions/                    # @mj-biz-apps/issues-actions
│   ├── Core/                       # @mj-biz-apps/issues-core
│   ├── Server/                     # @mj-biz-apps/issues-server
│   └── Angular/                    # @mj-biz-apps/issues-ng
├── migrations/                     # Skyway SQL migrations
├── metadata/                       # Seed data (synced via mj-sync)
└── plans/
    └── IMPLEMENTATION_PLAN.md      # Design + phased build plan
```

### Build Dependency Graph

```
Entities ──► Actions ──► Server ──► MJAPI
    │            │
    │            └──► Core
    └──────► Angular ────────────► MJExplorer
```

---

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Platform** | [MemberJunction](https://github.com/MemberJunction/MJ) | >=5.0.0 <6.0.0 |
| **Runtime** | Node.js | 18+ |
| **Language** | TypeScript | 5.9 |
| **Database** | SQL Server / Azure SQL | 2019+ |
| **API** | GraphQL (Apollo Server) | -- |
| **UI Framework** | Angular | 21 |
| **Build** | Turborepo | 2.x |
| **Validation** | Zod | 3.x |

---

## License

ISC

---

<p align="center">
  Built on <a href="https://github.com/MemberJunction/MJ">MemberJunction</a> -- the open-source metadata-driven application platform.
</p>
