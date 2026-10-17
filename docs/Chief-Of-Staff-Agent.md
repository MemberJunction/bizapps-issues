# Chief of Staff Agent Architecture & Operations Guide

> [!NOTE]
> **Why this guide lives in `bizapps-issues`**: The Chief of Staff Agent's core primitives (`MJ: AI Agent User Policies`, the 3-Tier Wake Gate on `MJ: User Routines`, per-user `AIBridgeAgentIdentity`, and the 4 Chief of Staff actions) ship in **MemberJunction Core (`MJ`)**, while its organizational work-tracking spine spans **`bizapps-common`** (`People.LinkedUserID`), **`bizapps-tasks`** (`Tasks` Priority/OKR extensions & `TaskCheckIn`), and **`bizapps-issues`** (`Issues` & escalations). Because `bizapps-issues` sits at the leaf of this dependency graph, the end-to-end reference guide is hosted here and linked from [`MJ/guides/BUILT_IN_AGENTS_GUIDE.md`](../../MJ/guides/BUILT_IN_AGENTS_GUIDE.md).

---

## 1. Purpose & Strategic Rationale

The **Chief of Staff (CoS)** is a personal, always-on AI agent for any user in an organization (`One CoS per user`). Unlike **Sage** (the ambient workspace concierge designed for reactive UI navigation and quick delegation), the Chief of Staff:
- Looks across the organization's workstreams (`Tasks`, `TaskCheckIns`, `Issues`).
- Tracks quarterly **Priority Objectives** and measurable **Key Results (OKRs)**.
- Writes executive briefings, status rollups, and decision memos.
- Triages incoming approvals and escalations.
- Follows up with colleagues (or their Chief of Staff agents) across chat, email, and voice/telephony—strictly within the user's narrowed governance policy.
- Decides on its own when to wake up next via MemberJunction's **3-Tier Wake Gate**.

```mermaid
flowchart TB
    subgraph Core["MemberJunction Core (@memberjunction/*)"]
        User["MJ: Users<br/>(Security Principal / contextUser)"]
        Policy["MJ: AI Agent User Policies<br/>(Narrowed CRUD, RLS/FLS, Time Windows, Approvals)"]
        Routine["MJ: User Routines (RoutineType='AgentWake')<br/>+ 3-Tier WakeGateEvaluator"]
        Bridge["MJ: AI Bridge Agent Identities<br/>(Per-User Email & Phone Numbers)"]
        CoSAgent["Chief of Staff Agent<br/>+ 4 CoS Core Actions"]
    end

    subgraph Common["bizapps-common (@mj-biz-apps/common)"]
        Person["MJ_BizApps_Common: People<br/>(LinkedUserID -> MJ: Users.ID)"]
        Contact["MJ_BizApps_Common: Contact Methods<br/>(Work Email, Mobile, Direct Line)"]
    end

    subgraph Tasks["bizapps-tasks (@mj-biz-apps/tasks)"]
        Obj["Priority Objectives & Key Results<br/>(HealthStatus, Target/Current, RollupWeight)"]
        CheckIn["MJ_BizApps_Tasks: Task Check Ins<br/>(TaskCheckInEntityServer Auto-Rollup)"]
    end

    subgraph Issues["bizapps-issues (@mj-biz-apps/issues)"]
        Issue["MJ_BizApps_Issues: Issues<br/>(Blockers, SLA Risks & Escalations)"]
    end

    User --> Policy
    User --> Routine
    User --> Bridge
    User <-->|"People.LinkedUserID"| Person
    Person --> Contact
    CoSAgent --> Policy
    CoSAgent --> Routine
    CoSAgent --> Obj
    CoSAgent --> CheckIn
    CoSAgent --> Issue
    CheckIn -->|"Updates Metrics & Rolls Up Parent"| Obj
    Issue -->|"Impacts HealthStatus"| Obj
```

---

## 2. Identity, Security & Narrowed Per-User Policies

### 2.1 Security Principal Invariant (`contextUser`)

Every Chief of Staff run—whether interactive chat, scheduled wake (`UserRoutineDispatcherDriver` / `AgentScheduledJobDriver`), durable multi-agent workflow (`TaskGraphOrchestrator`), or sub-agent call—executes as the user who owns it (`contextUser`):
1. **No Privilege Escalation**: The user's MemberJunction Entity Permissions, Row-Level Security (RLS), Field-Level Security (FLS), and scoped document retrieval form an **unbreakable ceiling**.
2. **Bridging `MJ: Users` and `MJ_BizApps_Common: People`**:
   - Security and permissions bind to `MJ: Users(ID)`.
   - Organizational ownership on Tasks and Issues binds to `MJ_BizApps_Common: People(ID)` via `People.LinkedUserID`.

### 2.2 `MJ: AI Agent User Policies` (`__mj.AIAgentUserPolicy`)

Users can narrow their Chief of Staff's capabilities below their own permission ceiling through a strongly-typed `MJ: AI Agent User Policies` record enforced at runtime by `AgentUserPolicyEngine` inside `BaseAgent`:

```mermaid
erDiagram
    USER ||--o{ AI_AGENT_USER_POLICY : "owns policy"
    AI_AGENT ||--o{ AI_AGENT_USER_POLICY : "governed by"
    USER ||--o| PERSON : "People.LinkedUserID"
    USER ||--o{ USER_ROUTINE : "OwnerUserID (AgentWake)"
    USER ||--o{ AI_BRIDGE_AGENT_IDENTITY : "per-user phone/email"

    AI_AGENT_USER_POLICY {
        uniqueidentifier ID PK
        uniqueidentifier AgentID FK
        uniqueidentifier UserID FK
        nvarchar DisplayNameOverride
        nvarchar OnboardingStatus "NotStarted | InProgress | Completed"
        nvarchar CoordinationMode "Observer | Coordinator | Autonomous"
        nvarchar EmailChannelMode "Disabled | ReadOnly | DraftOnly | SendAsAgent | SendAsUser"
        nvarchar PhoneChannelMode "Disabled | InboundOnly | OutboundWithApproval | OutboundAutonomous"
        nvarchar MessagingChannelMode "Disabled | Enabled"
        nvarchar DefaultDataAccessMode "UserCeiling | ReadOnly | AllowListOnly"
        bit RequireApprovalForExternalComms
        bit RequireApprovalForFinancials
        bit RequireApprovalForDestructiveActions
        decimal AutoApproveAmountThreshold
        nvarchar EntityAccessRules "JSONType: IAgentUserEntityAccessRule[]"
        nvarchar ActionPolicyRules "JSONType: IAgentUserActionPolicyRule[]"
    }
```

#### `EntityAccessRules` (`IAgentUserEntityAccessRule[]`)
Inherits the user's CRUD/RLS/FLS ceiling and supports further narrowing per entity or wildcard pattern:
- **Operation Ceiling**: `allowRead`, `allowCreate`, `allowUpdate`, `allowDelete`
- **RLS Narrowing**: `rlsFilterExpression` (additional SQL/filter predicate) and `AdditionalScopeFilter`
- **FLS Narrowing**: `ReadableFields`, `WritableFields`, `HiddenFields`
- **Time-Based Windows**: `timeWindows` (`daysOfWeek`, `startTime`, `endTime`, `timezone`)

```json
[
  {
    "entityNamePattern": "MJ_BizApps_Tasks:*",
    "allowRead": true,
    "allowCreate": true,
    "allowUpdate": true,
    "allowDelete": false
  },
  {
    "entityNamePattern": "*Invoice*",
    "allowRead": true,
    "allowCreate": false,
    "allowUpdate": false,
    "allowDelete": false,
    "HiddenFields": ["BankAccountNumber", "TaxID"]
  }
]
```

#### `ActionPolicyRules` (`IAgentUserActionPolicyRule[]`)
Controls action execution with `'Allow' | 'ApprovalRequired' | 'Deny'`, optional `conditionExpression` (`SafeExpressionEvaluator`), and `timeWindows`:

```json
[
  {
    "actionNamePattern": "Send Single Message",
    "policy": "ApprovalRequired",
    "timeWindows": [
      {
        "daysOfWeek": ["Mon", "Tue", "Wed", "Thu", "Fri"],
        "startTime": "08:00",
        "endTime": "18:00",
        "timezone": "America/Chicago"
      }
    ]
  }
]
```

---

## 3. Self-Scheduling & the 3-Tier Wake Gate (`MJ: User Routines`)

Instead of holding open an idle LLM process, an autonomous agent run completes cleanly (`Status = 'Completed'`) and calls **`Schedule Next Agent Wake`**, which creates or updates a row in `MJ: User Routines` with:
- `RoutineType = 'AgentWake'` (hidden from the default User Routines UI list unless the user toggles **"Agent Wakes (N)"** in the User Routines Command Center).
- `ScheduleMode = 'OneShot' | 'Adaptive' | 'Recurring'`.
- `WakeConfiguration` (`JSONType: IRoutineWakeConfiguration`).

When the routine's `NextRunAt` arrives, `UserRoutineDispatcherDriver` runs `WakeGateEvaluator.Instance.Evaluate()` **before** invoking the agent:

```mermaid
flowchart TD
    Poll["Scheduled / Due UserRoutine<br/>(RoutineType = 'AgentWake')"] --> HasConfig{"Has WakeConfiguration?"}
    HasConfig -->|"No"| Wake["Proceed to Agent Run<br/>(as OwnerUserID)"]
    HasConfig -->|"Yes"| Tier0["Tier 0: Durable Watermark & Unchanged Hash Check<br/>• Poll MAX(__mj_UpdatedAt) & COUNT(*) on watched entities<br/>• Query MJ: Record Changes since LastCheckedAt<br/>• Check forceWakeAfterMinutes heartbeat"]
    Tier0 --> Changed{"Changes detected OR<br/>Force-Wake elapsed?"}
    Changed -->|"No (and skipIfUnchanged=true)"| Skip0["Skip Agent Run (Zero LLM Tokens)<br/>Update LastCheckedAt & LastOutputHash"]
    Changed -->|"Yes"| Tier1{"Tier 1: conditionExpression<br/>configured?"}
    Tier1 -->|"Yes"| Eval1["Evaluate via SafeExpressionEvaluator<br/>(hasChanges, totalChangeCount, changesByEntity)"]
    Eval1 -->|"False"| Skip1["Skip Agent Run (Zero LLM Tokens)"]
    Eval1 -->|"True"| Tier2
    Tier1 -->|"No"| Tier2{"Tier 2: useDecisionModel<br/>configured?"}
    Tier2 -->|"Yes"| Eval2["Run Fast Decision Model<br/>(AIDecisionRunner / Default Decision)"]
    Eval2 -->|"False"| Skip2["Skip Agent Run (Minimal Tokens)"]
    Eval2 -->|"True"| Tier3
    Tier2 -->|"No"| Tier3{"Tier 3: tier3WakePromptId<br/>configured?"}
    Tier3 -->|"Yes"| Eval3["Execute Full Wake Prompt<br/>(AIPromptRunner)"]
    Eval3 -->|"False"| Skip3["Skip Agent Run"]
    Eval3 -->|"True"| Wake
    Tier3 -->|"No"| Wake
    Wake --> Compact["Run Agent with compactAfterRun=true<br/>(Auto-compacts conversation & prunes scratchpad)"]
```

---

## 4. First-Run Onboarding Flow

When a user interacts with their Chief of Staff for the first time (`OnboardingStatus = 'NotStarted'` or `'InProgress'`), the agent conducts a structured onboarding conversation by voice or text:

```mermaid
sequenceDiagram
    participant U as User
    participant CoS as Chief of Staff Agent
    participant Policy as Configure Agent User Policy
    participant Wake as Schedule Next Agent Wake

    U->>CoS: First message / voice session
    CoS->>U: Greets user, explains role (vs. Sage), asks for preferred name & CoordinationMode
    U->>CoS: "Call yourself Atlas. Coordinator mode—ask before emailing externals."
    CoS->>U: Confirms Email/Phone/Messaging channel modes, approval thresholds & top Q4 priorities
    U->>CoS: Shares 3 Q4 priorities + 8:00 AM weekday check-in preference
    CoS->>Policy: Configure Agent User Policy (OnboardingStatus='Completed', DisplayNameOverride='Atlas', ...)
    Policy-->>CoS: PolicyID saved
    CoS->>Wake: Schedule Next Agent Wake (ScheduleMode='Adaptive', WakeConfigurationJSON={...})
    Wake-->>CoS: RoutineID & ScheduledWakeTime
    CoS->>U: Summarizes active policy, priority trackers, and next scheduled briefing
```

---

## 5. Priority / OKR & Issue Tracking Across `bizapps-tasks` and `bizapps-issues`

### 5.1 Priority Objectives, Key Results & `TaskCheckIn` Rollup

`bizapps-tasks` models strategic priorities and OKRs directly on `MJ_BizApps_Tasks: Tasks` using seeded Task Types (`PRIORITY_OBJECTIVE` and `KEY_RESULT`) and 12 tracking fields (`HealthStatus`, `ConfidenceScore`, `BaselineValue`, `TargetValue`, `CurrentValue`, `UnitOfMeasure`, `MetricDirection`, `RollupWeight`, `PlanningPeriod`, `CheckInCadence`, `LastCheckInAt`, `NextCheckInDueAt`), paired with `MJ_BizApps_Tasks: Task Check Ins` (`TaskCheckIn`):

```mermaid
sequenceDiagram
    participant CoS as Chief of Staff / Owner
    participant CheckIn as TaskCheckInEntityServer
    participant KR as Key Result (TaskEntityServer)
    participant Svc as TaskService.rollupParentProgress
    participant Obj as Priority Objective (Parent Task)

    CoS->>CheckIn: Save TaskCheckIn (NewValue=30, HealthStatus='AtRisk', ConfidenceScore=65)
    CheckIn->>CheckIn: Capture PreviousValue (20) & compute PercentComplete (50%)
    CheckIn->>KR: Update CurrentValue=30, PercentComplete=50, HealthStatus='AtRisk', NextCheckInDueAt
    KR->>Svc: Post-save event triggers rollupParentProgress(ParentID)
    Svc->>Obj: Recompute weighted PercentComplete, worst-case HealthStatus ('AtRisk') & weighted ConfidenceScore
    Svc->>Obj: Save Parent Objective (recurses to Grandparent if present)
```

### 5.2 Connecting Issues (`bizapps-issues`) to Priorities

- Blocking issues in `MJ_BizApps_Issues: Issues` link to tasks and key results via `MJ_BizApps_Tasks: Task Links` or `MJ_BizApps_Issues: Issue Links`.
- Including `MJ_BizApps_Issues: Issues` in the Chief of Staff's Tier 0 `entityWatches` allows the agent to wake up when a high-severity issue is created or escalated, correlate it with the affected Key Result, and alert the user with recommended mitigation steps.

---

## 6. Multi-Channel & Peer Coordination Guardrails

1. **Inter-Agent Coordination (`Chief of Staff Inter-Agent Request`)**:
   - Enables User A's Chief of Staff to send a structured coordination request to User B's Chief of Staff (resolving User B via `TargetUserID` or `People.LinkedUserID` from `TargetPersonID`).
   - Enforces `CoordinationMode != 'Observer'` on the sender and isolates the request inside User B's Chief of Staff conversation so User B's CoS evaluates it under User B's own permissions and policy.
2. **Outbound Telephony (`Prepare Chief of Staff Outbound Call`)**:
   - Validates the user's `PhoneChannelMode` (`Disabled`, `InboundOnly`, `OutboundWithApproval`, `OutboundAutonomous`).
   - Generates a mandatory `DisclosureGreeting` (*"Hello [Recipient], I am [AgentName], an AI assistant calling on behalf of [UserName]..."*), enforces `ProhibitedCommitments`, and structures a tight `Objective` and `FallbackPlan`.
