-- =============================================================================
-- BizApps Issues — Baseline Schema (v1.0.x)
-- =============================================================================
-- Creates the entire BizApps Issues schema in a single baseline:
--   - 4 tables: IssueType, IssueStatus, Issue, IssueComment
--   - Foreign keys (cross-schema to ${mjSchema}.Entity, ${mjSchema}.[Action],
--     __mj_BizAppsTasks.TaskType, __mj_BizAppsCommon.Person; and within-schema
--     Issue → IssueType / IssueStatus, IssueComment → Issue)
--   - CHECK constraints (Severity / Priority / DefaultPriority enums,
--     IssueComment.Source enum, polymorphic all-or-nothing pairs)
--   - MS_Description extended properties for the schema, every table, and
--     every column
--
-- Schema placeholders (per CLAUDE.md / SaaS convention):
--   ${flyway:defaultSchema} = this app's schema (e.g. __mj_BizAppsIssues)
--   ${mjSchema}             = MemberJunction core schema (e.g. __mj)
--   Sibling app schemas (__mj_BizAppsTasks, __mj_BizAppsCommon) have no
--   placeholder and are written literally.
--
-- Per CLAUDE.md "CodeGen Handles These Automatically": this file hand-writes
-- ONLY business columns + constraints. CodeGen owns __mj_CreatedAt /
-- __mj_UpdatedAt, FK indexes, base views, spCreate/spUpdate/spDelete, and the
-- ${mjSchema}.Entity / EntityField metadata — none of that is hand-written here
-- (it lands in migrations/codegen/ when `mj:codegen` runs).
--
-- Work items are NOT a table here: an Issue spawns bizapps-tasks Task records,
-- linked back via the existing polymorphic __mj_BizAppsTasks.TaskLink
-- (EntityID = the Issues entity, RecordID = the Issue's ID).
--
-- Reference: plans/IMPLEMENTATION_PLAN.md (Phase 1).
-- =============================================================================

-- =============================================================================
-- 1. SCHEMA
-- =============================================================================
-- Guarded create (matches bizapps-common / bizapps-accounting baselines).
-- mj-app.json also declares createIfNotExists, but creating it here keeps the
-- baseline self-contained. Literal name: the ${flyway:defaultSchema} placeholder
-- is for object references resolved by the migration engine, not for the
-- CREATE SCHEMA name argument.
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '__mj_BizAppsIssues')
    EXEC('CREATE SCHEMA __mj_BizAppsIssues');
GO

-- =============================================================================
-- 2. TABLES (created without foreign keys; FKs added in section 3)
-- =============================================================================

---------------------------------------------------------------------------
-- 2.1 IssueType — lifecycle automation for a class of issue. Mirrors
--     bizapps-tasks' TaskType action-hook pattern: each On*ActionID points at
--     a ${mjSchema}.[Action] fired by IssueService at the matching lifecycle
--     event. DefaultTaskTypeID is the bizapps-tasks TaskType used when an Issue
--     of this type spawns work via IssueWorkService.
---------------------------------------------------------------------------
CREATE TABLE ${flyway:defaultSchema}.IssueType (
    ID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    IconClass NVARCHAR(100) NULL,
    DefaultPriority NVARCHAR(20) NOT NULL DEFAULT 'Medium',
    DefaultTaskTypeID UNIQUEIDENTIFIER NULL,
    OnCreateActionID UNIQUEIDENTIFIER NULL,
    OnStatusChangeActionID UNIQUEIDENTIFIER NULL,
    OnAssignActionID UNIQUEIDENTIFIER NULL,
    OnCloseActionID UNIQUEIDENTIFIER NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_IssueType PRIMARY KEY (ID),
    CONSTRAINT UQ_IssueType_Name UNIQUE (Name),
    CONSTRAINT CK_IssueType_DefaultPriority CHECK (DefaultPriority IN ('Low', 'Medium', 'High', 'Critical'))
);
GO

---------------------------------------------------------------------------
-- 2.2 IssueStatus — workflow states (seeded via metadata, not here). Drives
--     board columns later. IsDefault marks the new-issue status; IsTerminal
--     marks closed/resolved end states.
---------------------------------------------------------------------------
CREATE TABLE ${flyway:defaultSchema}.IssueStatus (
    ID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    Sequence INT NOT NULL DEFAULT 100,
    IsDefault BIT NOT NULL DEFAULT 0,
    IsTerminal BIT NOT NULL DEFAULT 0,
    ColorCode NVARCHAR(20) NULL,
    CONSTRAINT PK_IssueStatus PRIMARY KEY (ID),
    CONSTRAINT UQ_IssueStatus_Name UNIQUE (Name)
);
GO

---------------------------------------------------------------------------
-- 2.3 Issue — the core case / ticket / feedback record.
--     - Reporter: ReporterPersonID (nullable — external reporters may not exist
--       as a Person) plus ReporterEmail for anonymous/external sources.
--     - Polymorphic assignee (pattern from TaskAssignment): a Person OR an AI
--       Agent, addressed by AssigneeEntityID + AssigneeRecordID.
--     - Polymorphic source: WHAT the issue is about — any record in the system,
--       addressed by SourceEntityID + SourceRecordID.
--     - Severity = impact, Priority = scheduling (kept distinct per decision).
---------------------------------------------------------------------------
CREATE TABLE ${flyway:defaultSchema}.Issue (
    ID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    Title NVARCHAR(500) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    IssueTypeID UNIQUEIDENTIFIER NOT NULL,
    StatusID UNIQUEIDENTIFIER NOT NULL,
    Severity NVARCHAR(20) NOT NULL DEFAULT 'Medium',
    Priority NVARCHAR(20) NOT NULL DEFAULT 'Medium',
    ReporterPersonID UNIQUEIDENTIFIER NULL,
    ReporterEmail NVARCHAR(320) NULL,
    AssigneeEntityID UNIQUEIDENTIFIER NULL,
    AssigneeRecordID NVARCHAR(450) NULL,
    SourceEntityID UNIQUEIDENTIFIER NULL,
    SourceRecordID NVARCHAR(450) NULL,
    AppScope NVARCHAR(255) NULL,
    ResolvedAt DATETIMEOFFSET NULL,
    ClosedAt DATETIMEOFFSET NULL,
    CreatedByPersonID UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_Issue PRIMARY KEY (ID),
    CONSTRAINT CK_Issue_Severity CHECK (Severity IN ('Low', 'Medium', 'High', 'Critical')),
    CONSTRAINT CK_Issue_Priority CHECK (Priority IN ('Low', 'Medium', 'High', 'Critical')),
    -- Polymorphic columns are all-or-nothing: an entity reference without a
    -- record id (or vice versa) is a data error.
    CONSTRAINT CK_Issue_Assignee CHECK (
        (AssigneeEntityID IS NULL AND AssigneeRecordID IS NULL) OR
        (AssigneeEntityID IS NOT NULL AND AssigneeRecordID IS NOT NULL)
    ),
    CONSTRAINT CK_Issue_Source CHECK (
        (SourceEntityID IS NULL AND SourceRecordID IS NULL) OR
        (SourceEntityID IS NOT NULL AND SourceRecordID IS NOT NULL)
    )
);
GO

---------------------------------------------------------------------------
-- 2.4 IssueComment — threaded discussion on an Issue. Author is a Person when
--     internal; AuthorEmail carries the address for email/external sources.
--     Source 'external' is reserved for v1.1 provider sync.
---------------------------------------------------------------------------
CREATE TABLE ${flyway:defaultSchema}.IssueComment (
    ID UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    IssueID UNIQUEIDENTIFIER NOT NULL,
    Body NVARCHAR(MAX) NOT NULL,
    AuthorPersonID UNIQUEIDENTIFIER NULL,
    AuthorEmail NVARCHAR(320) NULL,
    Source NVARCHAR(20) NOT NULL DEFAULT 'internal',
    CONSTRAINT PK_IssueComment PRIMARY KEY (ID),
    CONSTRAINT CK_IssueComment_Source CHECK (Source IN ('internal', 'email', 'external'))
);
GO

-- =============================================================================
-- 3. FOREIGN KEYS
-- =============================================================================

-- IssueType → bizapps-tasks TaskType (default work type) and core [Action] hooks
ALTER TABLE ${flyway:defaultSchema}.IssueType
    ADD CONSTRAINT FK_IssueType_DefaultTaskType
        FOREIGN KEY (DefaultTaskTypeID) REFERENCES __mj_BizAppsTasks.TaskType(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.IssueType
    ADD CONSTRAINT FK_IssueType_OnCreateAction
        FOREIGN KEY (OnCreateActionID) REFERENCES ${mjSchema}.[Action](ID);
GO
ALTER TABLE ${flyway:defaultSchema}.IssueType
    ADD CONSTRAINT FK_IssueType_OnStatusChangeAction
        FOREIGN KEY (OnStatusChangeActionID) REFERENCES ${mjSchema}.[Action](ID);
GO
ALTER TABLE ${flyway:defaultSchema}.IssueType
    ADD CONSTRAINT FK_IssueType_OnAssignAction
        FOREIGN KEY (OnAssignActionID) REFERENCES ${mjSchema}.[Action](ID);
GO
ALTER TABLE ${flyway:defaultSchema}.IssueType
    ADD CONSTRAINT FK_IssueType_OnCloseAction
        FOREIGN KEY (OnCloseActionID) REFERENCES ${mjSchema}.[Action](ID);
GO

-- Issue → IssueType / IssueStatus (within schema), polymorphic entity refs to
-- core Entity, reporter + creator Person (cross-schema to bizapps-common).
ALTER TABLE ${flyway:defaultSchema}.Issue
    ADD CONSTRAINT FK_Issue_IssueType
        FOREIGN KEY (IssueTypeID) REFERENCES ${flyway:defaultSchema}.IssueType(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.Issue
    ADD CONSTRAINT FK_Issue_Status
        FOREIGN KEY (StatusID) REFERENCES ${flyway:defaultSchema}.IssueStatus(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.Issue
    ADD CONSTRAINT FK_Issue_AssigneeEntity
        FOREIGN KEY (AssigneeEntityID) REFERENCES ${mjSchema}.Entity(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.Issue
    ADD CONSTRAINT FK_Issue_SourceEntity
        FOREIGN KEY (SourceEntityID) REFERENCES ${mjSchema}.Entity(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.Issue
    ADD CONSTRAINT FK_Issue_ReporterPerson
        FOREIGN KEY (ReporterPersonID) REFERENCES __mj_BizAppsCommon.Person(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.Issue
    ADD CONSTRAINT FK_Issue_CreatedByPerson
        FOREIGN KEY (CreatedByPersonID) REFERENCES __mj_BizAppsCommon.Person(ID);
GO

-- IssueComment → Issue (within schema), author Person (cross-schema).
ALTER TABLE ${flyway:defaultSchema}.IssueComment
    ADD CONSTRAINT FK_IssueComment_Issue
        FOREIGN KEY (IssueID) REFERENCES ${flyway:defaultSchema}.Issue(ID);
GO
ALTER TABLE ${flyway:defaultSchema}.IssueComment
    ADD CONSTRAINT FK_IssueComment_AuthorPerson
        FOREIGN KEY (AuthorPersonID) REFERENCES __mj_BizAppsCommon.Person(ID);
GO

-- =============================================================================
-- 4. EXTENDED PROPERTIES (MS_Description) — schema, tables, and every column
-- =============================================================================

-- Schema
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'BizApps Issues: reusable case / issue / ticket primitives. The shared foundation for ticketing UX (Izzy) and the destination for MJ cloud feedback.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}';
GO

---------------------------------------------------------------------------
-- 4.1 IssueType
---------------------------------------------------------------------------
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core [Action] records fired at the matching lifecycle event.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier (UUID).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'ID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Display name of the issue type (unique). E.g. ''Bug'', ''Feature Request''.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'Name';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Detailed description of what this issue type represents and when to use it.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'Description';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Font Awesome (or similar) icon class shown next to issues of this type in the UI.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'IconClass';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'DefaultPriority';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'DefaultTaskTypeID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Action fired by IssueService when an Issue of this type is created.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'OnCreateActionID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Action fired by IssueService when an Issue of this type changes status.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'OnStatusChangeActionID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Action fired by IssueService when an Issue of this type is assigned.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'OnAssignActionID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Action fired by IssueService when an Issue of this type is closed.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'OnCloseActionID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueType', @level2type = N'COLUMN', @level2name = N'IsActive';
GO

---------------------------------------------------------------------------
-- 4.2 IssueStatus
---------------------------------------------------------------------------
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier (UUID).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'ID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Display name of the status (unique). E.g. ''In Progress'', ''Resolved''.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'Name';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Detailed description of what this status means in the workflow.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'Description';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Sort order of the status on boards and in dropdowns. Lower values appear first.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'Sequence';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Whether new issues default to this status. Exactly one status should have this set.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'IsDefault';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Whether this is a terminal (end) state such as Closed or Won''t Fix. Terminal statuses stop SLA timers and remove the issue from active queues.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'IsTerminal';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Hex (or token) color used to render this status as a chip / board column header.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueStatus', @level2type = N'COLUMN', @level2name = N'ColorCode';
GO

---------------------------------------------------------------------------
-- 4.3 Issue
---------------------------------------------------------------------------
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier (UUID).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'ID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Short, one-line summary of the issue.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'Title';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Full description / body of the issue (Markdown or plain text).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'Description';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'IssueTypeID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Current workflow status of the issue.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'StatusID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'Severity';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'Priority';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'ReporterPersonID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Email of the reporter, used when there is no linked Person (external feedback, email-in).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'ReporterEmail';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'AssigneeEntityID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'AssigneeRecordID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'SourceEntityID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Polymorphic source: the primary key (as string) of the source record within SourceEntityID.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'SourceRecordID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Which app / product this issue belongs to (free-text scope tag, e.g. ''MJC'', ''Explorer'').',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'AppScope';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'ResolvedAt';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Timestamp the issue was closed (entered a terminal state). NULL while open.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'ClosedAt';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The Person who created the issue record in the system (may differ from the reporter).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'CreatedByPersonID';
GO

---------------------------------------------------------------------------
-- 4.4 IssueComment
---------------------------------------------------------------------------
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier (UUID).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'ID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The Issue this comment belongs to.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'IssueID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Comment body (Markdown or plain text).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'Body';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'AuthorPersonID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Email of the comment author, used when there is no linked Person.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'AuthorEmail';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Origin of the comment: ''internal'' (in-app), ''email'' (email reply), or ''external'' (reserved for v1.1 provider sync).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'Source';
GO

































































/*----------------------------------------------CODEGEN-----------------------------------------*/
/* SQL generated to create new entity MJ_BizApps_Issues: Issue Types */

      INSERT INTO [${mjSchema}].[Entity] (
         [ID],
         [Name],
         [DisplayName],
         [Description],
         [NameSuffix],
         [BaseTable],
         [BaseView],
         [SchemaName],
         [IncludeInAPI],
         [AllowUserSearchAPI],
         [AllowCaching]
         , [TrackRecordChanges]
         , [AuditRecordAccess]
         , [AuditViewRuns]
         , [AllowAllRowsAPI]
         , [AllowCreateAPI]
         , [AllowUpdateAPI]
         , [AllowDeleteAPI]
         , [UserViewMaxRows]
         , [__mj_CreatedAt]
         , [__mj_UpdatedAt]
      )
      VALUES (
         '850e81f1-4918-4621-ae33-f5143f76e848',
         'MJ_BizApps_Issues: Issue Types',
         'Issue Types',
         'Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core [Action] records fired at the matching lifecycle event.',
         NULL,
         'IssueType',
         'vwIssueTypes',
         '${flyway:defaultSchema}',
         1,
         1,
         0
         , 1
         , 0
         , 0
         , 0
         , 1
         , 1
         , 1
         , 1000
         , GETUTCDATE()
         , GETUTCDATE()
      );

/* SQL generated to create new application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[Application] (ID, Name, Description, SchemaAutoAddNewEntities, Path, AutoUpdatePath)
                       VALUES ('6fec12ca-2e04-47ba-89dd-3ba59075be0a', '${flyway:defaultSchema}', 'Generated for schema', '${flyway:defaultSchema}', 'mjbizappsissues', 1);

/* Adding role UI to application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[ApplicationRole]
                                 ([ApplicationID], [RoleID], [CanAccess], [CanAdmin]) VALUES
                                 ('6fec12ca-2e04-47ba-89dd-3ba59075be0a', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0);

/* Adding role Developer to application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[ApplicationRole]
                                 ([ApplicationID], [RoleID], [CanAccess], [CanAdmin]) VALUES
                                 ('6fec12ca-2e04-47ba-89dd-3ba59075be0a', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1);

/* Adding role Integration to application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[ApplicationRole]
                                 ([ApplicationID], [RoleID], [CanAccess], [CanAdmin]) VALUES
                                 ('6fec12ca-2e04-47ba-89dd-3ba59075be0a', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0);

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Types to application ID: '6fec12ca-2e04-47ba-89dd-3ba59075be0a' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('6fec12ca-2e04-47ba-89dd-3ba59075be0a', '850e81f1-4918-4621-ae33-f5143f76e848', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '6fec12ca-2e04-47ba-89dd-3ba59075be0a'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('850e81f1-4918-4621-ae33-f5143f76e848', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('850e81f1-4918-4621-ae33-f5143f76e848', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('850e81f1-4918-4621-ae33-f5143f76e848', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to create new entity MJ_BizApps_Issues: Issue Status */

      INSERT INTO [${mjSchema}].[Entity] (
         [ID],
         [Name],
         [DisplayName],
         [Description],
         [NameSuffix],
         [BaseTable],
         [BaseView],
         [SchemaName],
         [IncludeInAPI],
         [AllowUserSearchAPI],
         [AllowCaching]
         , [TrackRecordChanges]
         , [AuditRecordAccess]
         , [AuditViewRuns]
         , [AllowAllRowsAPI]
         , [AllowCreateAPI]
         , [AllowUpdateAPI]
         , [AllowDeleteAPI]
         , [UserViewMaxRows]
         , [__mj_CreatedAt]
         , [__mj_UpdatedAt]
      )
      VALUES (
         '04858fb3-6827-4f81-ba45-5fe46b4fb69e',
         'MJ_BizApps_Issues: Issue Status',
         'Issue Status',
         'Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.',
         NULL,
         'IssueStatus',
         'vwIssueStatus',
         '${flyway:defaultSchema}',
         1,
         1,
         0
         , 1
         , 0
         , 0
         , 0
         , 1
         , 1
         , 1
         , 1000
         , GETUTCDATE()
         , GETUTCDATE()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Status to application ID: '6FEC12CA-2E04-47BA-89DD-3BA59075BE0A' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('6FEC12CA-2E04-47BA-89DD-3BA59075BE0A', '04858fb3-6827-4f81-ba45-5fe46b4fb69e', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '6FEC12CA-2E04-47BA-89DD-3BA59075BE0A'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('04858fb3-6827-4f81-ba45-5fe46b4fb69e', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('04858fb3-6827-4f81-ba45-5fe46b4fb69e', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('04858fb3-6827-4f81-ba45-5fe46b4fb69e', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to create new entity MJ_BizApps_Issues: Issues */

      INSERT INTO [${mjSchema}].[Entity] (
         [ID],
         [Name],
         [DisplayName],
         [Description],
         [NameSuffix],
         [BaseTable],
         [BaseView],
         [SchemaName],
         [IncludeInAPI],
         [AllowUserSearchAPI],
         [AllowCaching]
         , [TrackRecordChanges]
         , [AuditRecordAccess]
         , [AuditViewRuns]
         , [AllowAllRowsAPI]
         , [AllowCreateAPI]
         , [AllowUpdateAPI]
         , [AllowDeleteAPI]
         , [UserViewMaxRows]
         , [__mj_CreatedAt]
         , [__mj_UpdatedAt]
      )
      VALUES (
         'b6aad5f4-938c-441e-a2a7-27b0dbae61d1',
         'MJ_BizApps_Issues: Issues',
         'Issues',
         'The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.',
         NULL,
         'Issue',
         'vwIssues',
         '${flyway:defaultSchema}',
         1,
         1,
         0
         , 1
         , 0
         , 0
         , 0
         , 1
         , 1
         , 1
         , 1000
         , GETUTCDATE()
         , GETUTCDATE()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issues to application ID: '6FEC12CA-2E04-47BA-89DD-3BA59075BE0A' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('6FEC12CA-2E04-47BA-89DD-3BA59075BE0A', 'b6aad5f4-938c-441e-a2a7-27b0dbae61d1', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '6FEC12CA-2E04-47BA-89DD-3BA59075BE0A'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('b6aad5f4-938c-441e-a2a7-27b0dbae61d1', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('b6aad5f4-938c-441e-a2a7-27b0dbae61d1', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('b6aad5f4-938c-441e-a2a7-27b0dbae61d1', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to create new entity MJ_BizApps_Issues: Issue Comments */

      INSERT INTO [${mjSchema}].[Entity] (
         [ID],
         [Name],
         [DisplayName],
         [Description],
         [NameSuffix],
         [BaseTable],
         [BaseView],
         [SchemaName],
         [IncludeInAPI],
         [AllowUserSearchAPI],
         [AllowCaching]
         , [TrackRecordChanges]
         , [AuditRecordAccess]
         , [AuditViewRuns]
         , [AllowAllRowsAPI]
         , [AllowCreateAPI]
         , [AllowUpdateAPI]
         , [AllowDeleteAPI]
         , [UserViewMaxRows]
         , [__mj_CreatedAt]
         , [__mj_UpdatedAt]
      )
      VALUES (
         'a36ca73a-5a42-4001-897a-8d2aed23f7d7',
         'MJ_BizApps_Issues: Issue Comments',
         'Issue Comments',
         'Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.',
         NULL,
         'IssueComment',
         'vwIssueComments',
         '${flyway:defaultSchema}',
         1,
         1,
         0
         , 1
         , 0
         , 0
         , 0
         , 1
         , 1
         , 1
         , 1000
         , GETUTCDATE()
         , GETUTCDATE()
      );

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Comments to application ID: '6FEC12CA-2E04-47BA-89DD-3BA59075BE0A' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('6FEC12CA-2E04-47BA-89DD-3BA59075BE0A', 'a36ca73a-5a42-4001-897a-8d2aed23f7d7', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '6FEC12CA-2E04-47BA-89DD-3BA59075BE0A'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('a36ca73a-5a42-4001-897a-8d2aed23f7d7', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('a36ca73a-5a42-4001-897a-8d2aed23f7d7', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('a36ca73a-5a42-4001-897a-8d2aed23f7d7', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL text to update existing entities from schema */
EXEC [${mjSchema}].[spUpdateExistingEntitiesFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.Issue */
ALTER TABLE [${flyway:defaultSchema}].[Issue] ADD [__mj_CreatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.Issue */
UPDATE [${flyway:defaultSchema}].[Issue] SET [__mj_CreatedAt] = GETUTCDATE() WHERE [__mj_CreatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.Issue */
ALTER TABLE [${flyway:defaultSchema}].[Issue] ALTER COLUMN [__mj_CreatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.Issue */
ALTER TABLE [${flyway:defaultSchema}].[Issue] ADD CONSTRAINT [DF___mj_BizAppsIssues_Issue___mj_CreatedAt] DEFAULT GETUTCDATE() FOR [__mj_CreatedAt];
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.Issue */
ALTER TABLE [${flyway:defaultSchema}].[Issue] ADD [__mj_UpdatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.Issue */
UPDATE [${flyway:defaultSchema}].[Issue] SET [__mj_UpdatedAt] = GETUTCDATE() WHERE [__mj_UpdatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.Issue */
ALTER TABLE [${flyway:defaultSchema}].[Issue] ALTER COLUMN [__mj_UpdatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.Issue */
ALTER TABLE [${flyway:defaultSchema}].[Issue] ADD CONSTRAINT [DF___mj_BizAppsIssues_Issue___mj_UpdatedAt] DEFAULT GETUTCDATE() FOR [__mj_UpdatedAt];
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueStatus */
ALTER TABLE [${flyway:defaultSchema}].[IssueStatus] ADD [__mj_CreatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueStatus */
UPDATE [${flyway:defaultSchema}].[IssueStatus] SET [__mj_CreatedAt] = GETUTCDATE() WHERE [__mj_CreatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueStatus */
ALTER TABLE [${flyway:defaultSchema}].[IssueStatus] ALTER COLUMN [__mj_CreatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueStatus */
ALTER TABLE [${flyway:defaultSchema}].[IssueStatus] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueStatus___mj_CreatedAt] DEFAULT GETUTCDATE() FOR [__mj_CreatedAt];
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueStatus */
ALTER TABLE [${flyway:defaultSchema}].[IssueStatus] ADD [__mj_UpdatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueStatus */
UPDATE [${flyway:defaultSchema}].[IssueStatus] SET [__mj_UpdatedAt] = GETUTCDATE() WHERE [__mj_UpdatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueStatus */
ALTER TABLE [${flyway:defaultSchema}].[IssueStatus] ALTER COLUMN [__mj_UpdatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueStatus */
ALTER TABLE [${flyway:defaultSchema}].[IssueStatus] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueStatus___mj_UpdatedAt] DEFAULT GETUTCDATE() FOR [__mj_UpdatedAt];
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueComment */
ALTER TABLE [${flyway:defaultSchema}].[IssueComment] ADD [__mj_CreatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueComment */
UPDATE [${flyway:defaultSchema}].[IssueComment] SET [__mj_CreatedAt] = GETUTCDATE() WHERE [__mj_CreatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueComment */
ALTER TABLE [${flyway:defaultSchema}].[IssueComment] ALTER COLUMN [__mj_CreatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueComment */
ALTER TABLE [${flyway:defaultSchema}].[IssueComment] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueComment___mj_CreatedAt] DEFAULT GETUTCDATE() FOR [__mj_CreatedAt];
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueComment */
ALTER TABLE [${flyway:defaultSchema}].[IssueComment] ADD [__mj_UpdatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueComment */
UPDATE [${flyway:defaultSchema}].[IssueComment] SET [__mj_UpdatedAt] = GETUTCDATE() WHERE [__mj_UpdatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueComment */
ALTER TABLE [${flyway:defaultSchema}].[IssueComment] ALTER COLUMN [__mj_UpdatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueComment */
ALTER TABLE [${flyway:defaultSchema}].[IssueComment] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueComment___mj_UpdatedAt] DEFAULT GETUTCDATE() FOR [__mj_UpdatedAt];
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueType */
ALTER TABLE [${flyway:defaultSchema}].[IssueType] ADD [__mj_CreatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueType */
UPDATE [${flyway:defaultSchema}].[IssueType] SET [__mj_CreatedAt] = GETUTCDATE() WHERE [__mj_CreatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueType */
ALTER TABLE [${flyway:defaultSchema}].[IssueType] ALTER COLUMN [__mj_CreatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueType */
ALTER TABLE [${flyway:defaultSchema}].[IssueType] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueType___mj_CreatedAt] DEFAULT GETUTCDATE() FOR [__mj_CreatedAt];
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueType */
ALTER TABLE [${flyway:defaultSchema}].[IssueType] ADD [__mj_UpdatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueType */
UPDATE [${flyway:defaultSchema}].[IssueType] SET [__mj_UpdatedAt] = GETUTCDATE() WHERE [__mj_UpdatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueType */
ALTER TABLE [${flyway:defaultSchema}].[IssueType] ALTER COLUMN [__mj_UpdatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueType */
ALTER TABLE [${flyway:defaultSchema}].[IssueType] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueType___mj_UpdatedAt] DEFAULT GETUTCDATE() FOR [__mj_UpdatedAt];
GO

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '71f6fe9d-311b-4980-9ddd-a067744f70e1' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'ID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '71f6fe9d-311b-4980-9ddd-a067744f70e1',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100001,
            'ID',
            'ID',
            'Unique identifier (UUID).',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            'newsequentialid()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            1,
            0,
            0,
            1,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '07777ede-0a39-4983-a1a6-fe1d05b82570' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'Title')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '07777ede-0a39-4983-a1a6-fe1d05b82570',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100002,
            'Title',
            'Title',
            'Short, one-line summary of the issue.',
            'nvarchar',
            1000,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '1ef894ee-1e09-44c5-a2b5-e43fb5917c1d' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'Description')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '1ef894ee-1e09-44c5-a2b5-e43fb5917c1d',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100003,
            'Description',
            'Description',
            'Full description / body of the issue (Markdown or plain text).',
            'nvarchar',
            -1,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e6fffaa5-6b25-4022-a558-77e3bda590d7' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'IssueTypeID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e6fffaa5-6b25-4022-a558-77e3bda590d7',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100004,
            'IssueTypeID',
            'Issue Type ID',
            'The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            '850E81F1-4918-4621-AE33-F5143F76E848',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '746b9e26-50d4-4619-b849-f050b07c0129' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'StatusID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '746b9e26-50d4-4619-b849-f050b07c0129',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100005,
            'StatusID',
            'Status ID',
            'Current workflow status of the issue.',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e0748301-99c6-4e68-895e-b99fcc00446a' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'Severity')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e0748301-99c6-4e68-895e-b99fcc00446a',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100006,
            'Severity',
            'Severity',
            'Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.',
            'nvarchar',
            40,
            0,
            0,
            0,
            'Medium',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '406b0511-2e42-462e-b5ed-7e8a97627928' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'Priority')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '406b0511-2e42-462e-b5ed-7e8a97627928',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100007,
            'Priority',
            'Priority',
            'Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.',
            'nvarchar',
            40,
            0,
            0,
            0,
            'Medium',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '2987cfe2-3d5f-4231-8fca-67edc6adc509' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'ReporterPersonID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '2987cfe2-3d5f-4231-8fca-67edc6adc509',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100008,
            'ReporterPersonID',
            'Reporter Person ID',
            'The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e7d9dbfe-51de-4216-9d37-95cc26de6e74' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'ReporterEmail')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e7d9dbfe-51de-4216-9d37-95cc26de6e74',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100009,
            'ReporterEmail',
            'Reporter Email',
            'Email of the reporter, used when there is no linked Person (external feedback, email-in).',
            'nvarchar',
            640,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'abd84563-0aa9-4f3f-8498-1ef98134ad0e' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'AssigneeEntityID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'abd84563-0aa9-4f3f-8498-1ef98134ad0e',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100010,
            'AssigneeEntityID',
            'Assignee Entity ID',
            'Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            'E0238F34-2837-EF11-86D4-6045BDEE16E6',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5a128f28-ecf6-43e6-adb1-5f3d2a1b9901' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'AssigneeRecordID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '5a128f28-ecf6-43e6-adb1-5f3d2a1b9901',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100011,
            'AssigneeRecordID',
            'Assignee Record ID',
            'Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.',
            'nvarchar',
            900,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e0f04d98-ec61-4713-bd51-8cfdf8650792' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'SourceEntityID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e0f04d98-ec61-4713-bd51-8cfdf8650792',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100012,
            'SourceEntityID',
            'Source Entity ID',
            'Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            'E0238F34-2837-EF11-86D4-6045BDEE16E6',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '88288fb0-3981-45e3-9256-7b79e8065712' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'SourceRecordID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '88288fb0-3981-45e3-9256-7b79e8065712',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100013,
            'SourceRecordID',
            'Source Record ID',
            'Polymorphic source: the primary key (as string) of the source record within SourceEntityID.',
            'nvarchar',
            900,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '12b873b4-a829-42e0-b0c7-93e10385c080' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'AppScope')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '12b873b4-a829-42e0-b0c7-93e10385c080',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100014,
            'AppScope',
            'App Scope',
            'Which app / product this issue belongs to (free-text scope tag, e.g. ''MJC'', ''Explorer'').',
            'nvarchar',
            510,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e7875bda-e884-486b-bf86-6e9f9e11584c' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'ResolvedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e7875bda-e884-486b-bf86-6e9f9e11584c',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100015,
            'ResolvedAt',
            'Resolved At',
            'Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.',
            'datetimeoffset',
            10,
            34,
            7,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '6d798d40-cd0a-424a-aa86-676853402251' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'ClosedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '6d798d40-cd0a-424a-aa86-676853402251',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100016,
            'ClosedAt',
            'Closed At',
            'Timestamp the issue was closed (entered a terminal state). NULL while open.',
            'datetimeoffset',
            10,
            34,
            7,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e26b3c93-9b7b-464a-8db1-eec94e99c319' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'CreatedByPersonID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e26b3c93-9b7b-464a-8db1-eec94e99c319',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100017,
            'CreatedByPersonID',
            'Created By Person ID',
            'The Person who created the issue record in the system (may differ from the reporter).',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9cba23d6-c49e-4026-a47a-f0b56e62b939' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = '__mj_CreatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '9cba23d6-c49e-4026-a47a-f0b56e62b939',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100018,
            '__mj_CreatedAt',
            'Created At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'b2bac0ea-64e1-4d44-a63c-0f6a82f4d5ad' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = '__mj_UpdatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'b2bac0ea-64e1-4d44-a63c-0f6a82f4d5ad',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100019,
            '__mj_UpdatedAt',
            'Updated At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e1e7f572-5a6b-44e8-b434-0a179a36a579' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'ID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e1e7f572-5a6b-44e8-b434-0a179a36a579',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100001,
            'ID',
            'ID',
            'Unique identifier (UUID).',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            'newsequentialid()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            1,
            0,
            0,
            1,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '06623ea1-2b07-45f7-8ff3-adca8f2c4cd1' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'Name')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '06623ea1-2b07-45f7-8ff3-adca8f2c4cd1',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100002,
            'Name',
            'Name',
            'Display name of the status (unique). E.g. ''In Progress'', ''Resolved''.',
            'nvarchar',
            200,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            1,
            1,
            0,
            1,
            0,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '7c26d943-6e4e-45ae-942f-94e3d8387cc7' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'Description')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '7c26d943-6e4e-45ae-942f-94e3d8387cc7',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100003,
            'Description',
            'Description',
            'Detailed description of what this status means in the workflow.',
            'nvarchar',
            -1,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '134e0015-2bb3-44aa-9771-59b147e9b97f' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'Sequence')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '134e0015-2bb3-44aa-9771-59b147e9b97f',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100004,
            'Sequence',
            'Sequence',
            'Sort order of the status on boards and in dropdowns. Lower values appear first.',
            'int',
            4,
            10,
            0,
            0,
            '(100)',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'c2033924-ee22-4437-a604-ecde7ba5f1e1' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'IsDefault')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'c2033924-ee22-4437-a604-ecde7ba5f1e1',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100005,
            'IsDefault',
            'Is Default',
            'Whether new issues default to this status. Exactly one status should have this set.',
            'bit',
            1,
            1,
            0,
            0,
            '(0)',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e3719598-cb97-4862-b074-69d94022abc1' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'IsTerminal')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'e3719598-cb97-4862-b074-69d94022abc1',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100006,
            'IsTerminal',
            'Is Terminal',
            'Whether this is a terminal (end) state such as Closed or Won''t Fix. Terminal statuses stop SLA timers and remove the issue from active queues.',
            'bit',
            1,
            1,
            0,
            0,
            '(0)',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '61b08f55-b801-4b80-b79a-4838f602ac84' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = 'ColorCode')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '61b08f55-b801-4b80-b79a-4838f602ac84',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100007,
            'ColorCode',
            'Color Code',
            'Hex (or token) color used to render this status as a chip / board column header.',
            'nvarchar',
            40,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '130b9909-963a-4a79-88c8-09561d3e7ffd' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = '__mj_CreatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '130b9909-963a-4a79-88c8-09561d3e7ffd',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100008,
            '__mj_CreatedAt',
            'Created At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '3e19d7bf-1b59-4e54-a186-c1cb8d85abc7' OR (EntityID = '04858FB3-6827-4F81-BA45-5FE46B4FB69E' AND Name = '__mj_UpdatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '3e19d7bf-1b59-4e54-a186-c1cb8d85abc7',
            '04858FB3-6827-4F81-BA45-5FE46B4FB69E', -- Entity: MJ_BizApps_Issues: Issue Status
            100009,
            '__mj_UpdatedAt',
            'Updated At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '68d3eb31-5ace-4e90-b5f5-57d405bc8034' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'ID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '68d3eb31-5ace-4e90-b5f5-57d405bc8034',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100001,
            'ID',
            'ID',
            'Unique identifier (UUID).',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            'newsequentialid()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            1,
            0,
            0,
            1,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '68af80d5-6d2f-46ca-9dbd-6244617aa2eb' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'IssueID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '68af80d5-6d2f-46ca-9dbd-6244617aa2eb',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100002,
            'IssueID',
            'Issue ID',
            'The Issue this comment belongs to.',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '3a9f41b8-0478-439f-80bd-b68c2d8c9c9c' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'Body')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '3a9f41b8-0478-439f-80bd-b68c2d8c9c9c',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100003,
            'Body',
            'Body',
            'Comment body (Markdown or plain text).',
            'nvarchar',
            -1,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '7f55d890-e1ca-41b4-b56e-1f87d2e517f6' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'AuthorPersonID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '7f55d890-e1ca-41b4-b56e-1f87d2e517f6',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100004,
            'AuthorPersonID',
            'Author Person ID',
            'The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'a26e1507-6c80-4ff5-96ed-ddd95581aa8c' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'AuthorEmail')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'a26e1507-6c80-4ff5-96ed-ddd95581aa8c',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100005,
            'AuthorEmail',
            'Author Email',
            'Email of the comment author, used when there is no linked Person.',
            'nvarchar',
            640,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '6252dcf1-b0d7-4108-8e80-506814f0ecb8' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'Source')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '6252dcf1-b0d7-4108-8e80-506814f0ecb8',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100006,
            'Source',
            'Source',
            'Origin of the comment: ''internal'' (in-app), ''email'' (email reply), or ''external'' (reserved for v1.1 provider sync).',
            'nvarchar',
            40,
            0,
            0,
            0,
            'internal',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '85c450e7-f7ca-4668-98ab-5336954e695f' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = '__mj_CreatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '85c450e7-f7ca-4668-98ab-5336954e695f',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100007,
            '__mj_CreatedAt',
            'Created At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5150052f-93de-42e7-8f22-cef41ccf9e63' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = '__mj_UpdatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '5150052f-93de-42e7-8f22-cef41ccf9e63',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100008,
            '__mj_UpdatedAt',
            'Updated At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '3c89a64b-3e0b-4e72-9085-909a1818c6e0' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'ID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '3c89a64b-3e0b-4e72-9085-909a1818c6e0',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100001,
            'ID',
            'ID',
            'Unique identifier (UUID).',
            'uniqueidentifier',
            16,
            0,
            0,
            0,
            'newsequentialid()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            1,
            0,
            0,
            1,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'ad22030a-fd4d-40dc-a647-bc0b0e839e85' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'Name')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'ad22030a-fd4d-40dc-a647-bc0b0e839e85',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100002,
            'Name',
            'Name',
            'Display name of the issue type (unique). E.g. ''Bug'', ''Feature Request''.',
            'nvarchar',
            200,
            0,
            0,
            0,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            1,
            1,
            0,
            1,
            0,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'c684f0b6-c025-4db1-abaf-029f991b8bd5' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'Description')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'c684f0b6-c025-4db1-abaf-029f991b8bd5',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100003,
            'Description',
            'Description',
            'Detailed description of what this issue type represents and when to use it.',
            'nvarchar',
            -1,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5c6e96b3-0aa7-4d9b-b803-ac764788ed3b' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'IconClass')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '5c6e96b3-0aa7-4d9b-b803-ac764788ed3b',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100004,
            'IconClass',
            'Icon Class',
            'Font Awesome (or similar) icon class shown next to issues of this type in the UI.',
            'nvarchar',
            200,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '78993679-f837-45c2-868d-f37bfbeeed7a' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'DefaultPriority')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '78993679-f837-45c2-868d-f37bfbeeed7a',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100005,
            'DefaultPriority',
            'Default Priority',
            'Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.',
            'nvarchar',
            40,
            0,
            0,
            0,
            'Medium',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '7c1afaf7-aa86-4004-8807-c2d6da9764a8' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'DefaultTaskTypeID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '7c1afaf7-aa86-4004-8807-c2d6da9764a8',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100006,
            'DefaultTaskTypeID',
            'Default Task Type ID',
            'bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '1E30141A-826F-4278-BAA9-BBE14D29E606',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '2e69c90c-93cb-49c0-8852-0790ae26dd3a' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnCreateActionID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '2e69c90c-93cb-49c0-8852-0790ae26dd3a',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100007,
            'OnCreateActionID',
            'On Create Action ID',
            'Action fired by IssueService when an Issue of this type is created.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '38248F34-2837-EF11-86D4-6045BDEE16E6',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9af0f216-6901-471a-81c6-e16e4e7134b7' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnStatusChangeActionID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '9af0f216-6901-471a-81c6-e16e4e7134b7',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100008,
            'OnStatusChangeActionID',
            'On Status Change Action ID',
            'Action fired by IssueService when an Issue of this type changes status.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '38248F34-2837-EF11-86D4-6045BDEE16E6',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'b4fa118c-58be-4860-8688-c56234bd14ff' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnAssignActionID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'b4fa118c-58be-4860-8688-c56234bd14ff',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100009,
            'OnAssignActionID',
            'On Assign Action ID',
            'Action fired by IssueService when an Issue of this type is assigned.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '38248F34-2837-EF11-86D4-6045BDEE16E6',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'a79b29c1-56b0-4e22-8514-a4225209bdcc' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnCloseActionID')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'a79b29c1-56b0-4e22-8514-a4225209bdcc',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100010,
            'OnCloseActionID',
            'On Close Action ID',
            'Action fired by IssueService when an Issue of this type is closed.',
            'uniqueidentifier',
            16,
            0,
            0,
            1,
            NULL,
            0,
            1,
            0,
            0,
            '38248F34-2837-EF11-86D4-6045BDEE16E6',
            'ID',
            0,
            0,
            1,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'bce45a21-cc11-4db9-ab59-afc334bfee10' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'IsActive')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'bce45a21-cc11-4db9-ab59-afc334bfee10',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100011,
            'IsActive',
            'Is Active',
            'Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.',
            'bit',
            1,
            1,
            0,
            0,
            '(1)',
            0,
            1,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '1277f5be-d6f8-4040-bcaf-d50b77512978' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = '__mj_CreatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '1277f5be-d6f8-4040-bcaf-d50b77512978',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100012,
            '__mj_CreatedAt',
            'Created At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '835e0dda-0f3f-4888-9c97-8e34f3f77de3' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = '__mj_UpdatedAt')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '835e0dda-0f3f-4888-9c97-8e34f3f77de3',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100013,
            '__mj_UpdatedAt',
            'Updated At',
            NULL,
            'datetimeoffset',
            10,
            34,
            7,
            0,
            'getutcdate()',
            0,
            0,
            0,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to update existing entity fields from schema */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to insert entity field value with ID 46f64eaf-5ea9-410d-bcf9-fc67164dea8c */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('46f64eaf-5ea9-410d-bcf9-fc67164dea8c', '78993679-F837-45C2-868D-F37BFBEEED7A', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 9302270a-f1a7-4ed0-9188-92457f978c21 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('9302270a-f1a7-4ed0-9188-92457f978c21', '78993679-F837-45C2-868D-F37BFBEEED7A', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID b9092695-4636-4cdb-8379-c29c0ccafb4a */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('b9092695-4636-4cdb-8379-c29c0ccafb4a', '78993679-F837-45C2-868D-F37BFBEEED7A', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID a3dca863-2d1d-487e-ab59-765105468cf1 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('a3dca863-2d1d-487e-ab59-765105468cf1', '78993679-F837-45C2-868D-F37BFBEEED7A', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 78993679-F837-45C2-868D-F37BFBEEED7A */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='78993679-F837-45C2-868D-F37BFBEEED7A';

/* SQL text to insert entity field value with ID c3497c70-08c7-4d28-a951-f888ec22bf58 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('c3497c70-08c7-4d28-a951-f888ec22bf58', 'E0748301-99C6-4E68-895E-B99FCC00446A', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 3988caed-7284-4d1d-bfaf-dd456bd386f5 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('3988caed-7284-4d1d-bfaf-dd456bd386f5', 'E0748301-99C6-4E68-895E-B99FCC00446A', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 299ea72e-fa41-48bb-baeb-86728e26ead5 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('299ea72e-fa41-48bb-baeb-86728e26ead5', 'E0748301-99C6-4E68-895E-B99FCC00446A', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 0d9b3a22-23a3-40f4-b2c3-0358df5c6f02 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('0d9b3a22-23a3-40f4-b2c3-0358df5c6f02', 'E0748301-99C6-4E68-895E-B99FCC00446A', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID E0748301-99C6-4E68-895E-B99FCC00446A */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='E0748301-99C6-4E68-895E-B99FCC00446A';

/* SQL text to insert entity field value with ID 41536732-4c0b-4a9e-8590-2218441729de */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('41536732-4c0b-4a9e-8590-2218441729de', '406B0511-2E42-462E-B5ED-7E8A97627928', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID fef9824c-2088-4565-aecc-773993848c06 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('fef9824c-2088-4565-aecc-773993848c06', '406B0511-2E42-462E-B5ED-7E8A97627928', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 46c5a7b8-1af6-43ef-90e2-6aa765a86452 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('46c5a7b8-1af6-43ef-90e2-6aa765a86452', '406B0511-2E42-462E-B5ED-7E8A97627928', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 16c0454a-b997-48ca-b869-2060140a5f81 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('16c0454a-b997-48ca-b869-2060140a5f81', '406B0511-2E42-462E-B5ED-7E8A97627928', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 406B0511-2E42-462E-B5ED-7E8A97627928 */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='406B0511-2E42-462E-B5ED-7E8A97627928';

/* SQL text to insert entity field value with ID 8aa7465c-5c39-4853-a65d-b19492d7649c */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('8aa7465c-5c39-4853-a65d-b19492d7649c', '6252DCF1-B0D7-4108-8E80-506814F0ECB8', 1, 'email', 'email', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 2c09a922-63a3-4ff5-a371-8b4fa4210a3c */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('2c09a922-63a3-4ff5-a371-8b4fa4210a3c', '6252DCF1-B0D7-4108-8E80-506814F0ECB8', 2, 'external', 'external', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 63d9ff9a-d54b-4234-9b72-ea5354f53790 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('63d9ff9a-d54b-4234-9b72-ea5354f53790', '6252DCF1-B0D7-4108-8E80-506814F0ECB8', 3, 'internal', 'internal', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 6252DCF1-B0D7-4108-8E80-506814F0ECB8 */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='6252DCF1-B0D7-4108-8E80-506814F0ECB8';


/* Create Entity Relationship: MJ_BizApps_Issues: Issues -> MJ_BizApps_Issues: Issue Comments (One To Many via IssueID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'b713c6c8-ec03-410e-8216-3310e261777d'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('b713c6c8-ec03-410e-8216-3310e261777d', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'A36CA73A-5A42-4001-897A-8D2AED23F7D7', 'IssueID', 'One To Many', 1, 1, 1, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Issues: Issue Status -> MJ_BizApps_Issues: Issues (One To Many via StatusID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'ead3e256-ea2b-4cc5-be5b-c58329097e1c'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('ead3e256-ea2b-4cc5-be5b-c58329097e1c', '04858FB3-6827-4F81-BA45-5FE46B4FB69E', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'StatusID', 'One To Many', 1, 1, 1, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Entities -> MJ_BizApps_Issues: Issues (One To Many via AssigneeEntityID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'bfac5b0f-26b2-4073-a0a8-14f595532a98'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('bfac5b0f-26b2-4073-a0a8-14f595532a98', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'AssigneeEntityID', 'One To Many', 1, 1, 66, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Entities -> MJ_BizApps_Issues: Issues (One To Many via SourceEntityID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'f78dc82e-1d58-480a-8b8a-5a18735a563f'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('f78dc82e-1d58-480a-8b8a-5a18735a563f', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'SourceEntityID', 'One To Many', 1, 1, 67, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnCloseActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '935cb99f-6115-4d92-86ae-05f50df800ca'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('935cb99f-6115-4d92-86ae-05f50df800ca', '38248F34-2837-EF11-86D4-6045BDEE16E6', '850E81F1-4918-4621-AE33-F5143F76E848', 'OnCloseActionID', 'One To Many', 1, 1, 18, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnAssignActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '73d82aac-0d85-4f9d-8f3a-e51ee6a77385'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('73d82aac-0d85-4f9d-8f3a-e51ee6a77385', '38248F34-2837-EF11-86D4-6045BDEE16E6', '850E81F1-4918-4621-AE33-F5143F76E848', 'OnAssignActionID', 'One To Many', 1, 1, 19, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnStatusChangeActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '95e94c93-767f-4012-8d12-f3828e0090fd'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('95e94c93-767f-4012-8d12-f3828e0090fd', '38248F34-2837-EF11-86D4-6045BDEE16E6', '850E81F1-4918-4621-AE33-F5143F76E848', 'OnStatusChangeActionID', 'One To Many', 1, 1, 20, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnCreateActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'f18b3477-02f4-4199-866d-c5b6794d4fda'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('f18b3477-02f4-4199-866d-c5b6794d4fda', '38248F34-2837-EF11-86D4-6045BDEE16E6', '850E81F1-4918-4621-AE33-F5143F76E848', 'OnCreateActionID', 'One To Many', 1, 1, 21, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Tasks: Task Types -> MJ_BizApps_Issues: Issue Types (One To Many via DefaultTaskTypeID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'fa103773-76e2-4533-8d27-2f72bde306c0'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('fa103773-76e2-4533-8d27-2f72bde306c0', '1E30141A-826F-4278-BAA9-BBE14D29E606', '850E81F1-4918-4621-AE33-F5143F76E848', 'DefaultTaskTypeID', 'One To Many', 1, 1, 4, GETUTCDATE(), GETUTCDATE())
   END;


/* Create Entity Relationship: MJ_BizApps_Common: People -> MJ_BizApps_Issues: Issues (One To Many via CreatedByPersonID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'ff44bbe4-11e9-4cef-8fe7-2f9e7b06429f'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('ff44bbe4-11e9-4cef-8fe7-2f9e7b06429f', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'CreatedByPersonID', 'One To Many', 1, 1, 8, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Common: People -> MJ_BizApps_Issues: Issues (One To Many via ReporterPersonID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '9f0dfa93-ddd5-4ebc-aa16-7b9d476d91e2'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('9f0dfa93-ddd5-4ebc-aa16-7b9d476d91e2', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'ReporterPersonID', 'One To Many', 1, 1, 9, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Common: People -> MJ_BizApps_Issues: Issue Comments (One To Many via AuthorPersonID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'ea3f99fa-b5f7-4b2e-9f23-358ab705d5c1'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('ea3f99fa-b5f7-4b2e-9f23-358ab705d5c1', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', 'A36CA73A-5A42-4001-897A-8D2AED23F7D7', 'AuthorPersonID', 'One To Many', 1, 1, 10, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Issues: Issue Types -> MJ_BizApps_Issues: Issues (One To Many via IssueTypeID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'd09673ee-5e75-4f06-95fa-b0a23001f612'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('d09673ee-5e75-4f06-95fa-b0a23001f612', '850E81F1-4918-4621-AE33-F5143F76E848', 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', 'IssueTypeID', 'One To Many', 1, 1, 1, GETUTCDATE(), GETUTCDATE())
   END;

/* SQL text to sync schema info from database schemas */
EXEC [${mjSchema}].[spUpdateSchemaInfoFromDatabase] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* Index for Foreign Keys for IssueComment */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: Index for Foreign Keys
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------
-- Index for foreign key IssueID in table IssueComment
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueComment_IssueID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueComment]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueComment_IssueID ON [${flyway:defaultSchema}].[IssueComment] ([IssueID]);

-- Index for foreign key AuthorPersonID in table IssueComment
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueComment]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID ON [${flyway:defaultSchema}].[IssueComment] ([AuthorPersonID]);

/* SQL text to update entity field related entity name field map for entity field ID 7F55D890-E1CA-41B4-B56E-1F87D2E517F6 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='7F55D890-E1CA-41B4-B56E-1F87D2E517F6', @RelatedEntityNameFieldMap='AuthorPerson';

/* Index for Foreign Keys for IssueStatus */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: Index for Foreign Keys
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

/* Index for Foreign Keys for IssueType */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: Index for Foreign Keys
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------
-- Index for foreign key DefaultTaskTypeID in table IssueType
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueType_DefaultTaskTypeID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueType]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueType_DefaultTaskTypeID ON [${flyway:defaultSchema}].[IssueType] ([DefaultTaskTypeID]);

-- Index for foreign key OnCreateActionID in table IssueType
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueType_OnCreateActionID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueType]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueType_OnCreateActionID ON [${flyway:defaultSchema}].[IssueType] ([OnCreateActionID]);

-- Index for foreign key OnStatusChangeActionID in table IssueType
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueType_OnStatusChangeActionID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueType]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueType_OnStatusChangeActionID ON [${flyway:defaultSchema}].[IssueType] ([OnStatusChangeActionID]);

-- Index for foreign key OnAssignActionID in table IssueType
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueType_OnAssignActionID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueType]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueType_OnAssignActionID ON [${flyway:defaultSchema}].[IssueType] ([OnAssignActionID]);

-- Index for foreign key OnCloseActionID in table IssueType
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueType_OnCloseActionID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueType]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueType_OnCloseActionID ON [${flyway:defaultSchema}].[IssueType] ([OnCloseActionID]);

/* SQL text to update entity field related entity name field map for entity field ID 7C1AFAF7-AA86-4004-8807-C2D6DA9764A8 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='7C1AFAF7-AA86-4004-8807-C2D6DA9764A8', @RelatedEntityNameFieldMap='DefaultTaskType';

/* Index for Foreign Keys for Issue */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: Index for Foreign Keys
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------
-- Index for foreign key IssueTypeID in table Issue
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_Issue_IssueTypeID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[Issue]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_Issue_IssueTypeID ON [${flyway:defaultSchema}].[Issue] ([IssueTypeID]);

-- Index for foreign key StatusID in table Issue
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_Issue_StatusID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[Issue]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_Issue_StatusID ON [${flyway:defaultSchema}].[Issue] ([StatusID]);

-- Index for foreign key ReporterPersonID in table Issue
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_Issue_ReporterPersonID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[Issue]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_Issue_ReporterPersonID ON [${flyway:defaultSchema}].[Issue] ([ReporterPersonID]);

-- Index for foreign key AssigneeEntityID in table Issue
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_Issue_AssigneeEntityID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[Issue]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_Issue_AssigneeEntityID ON [${flyway:defaultSchema}].[Issue] ([AssigneeEntityID]);

-- Index for foreign key SourceEntityID in table Issue
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_Issue_SourceEntityID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[Issue]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_Issue_SourceEntityID ON [${flyway:defaultSchema}].[Issue] ([SourceEntityID]);

-- Index for foreign key CreatedByPersonID in table Issue
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_Issue_CreatedByPersonID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[Issue]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_Issue_CreatedByPersonID ON [${flyway:defaultSchema}].[Issue] ([CreatedByPersonID]);

/* SQL text to update entity field related entity name field map for entity field ID E6FFFAA5-6B25-4022-A558-77E3BDA590D7 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='E6FFFAA5-6B25-4022-A558-77E3BDA590D7', @RelatedEntityNameFieldMap='IssueType';

/* Base View SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: vwIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Status
-----               SCHEMA:      ${flyway:defaultSchema}
-----               BASE TABLE:  IssueStatus
-----               PRIMARY KEY: ID
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssueStatus]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssueStatus];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssueStatus]
AS
SELECT
    i.*
FROM
    [${flyway:defaultSchema}].[IssueStatus] AS i
GO
GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueStatus] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: Permissions for vwIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueStatus] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: spCreateIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueStatus
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spCreateIssueStatus]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spCreateIssueStatus];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spCreateIssueStatus]
    @ID uniqueidentifier = NULL,
    @Name nvarchar(100),
    @Description_Clear bit = 0,
    @Description nvarchar(MAX) = NULL,
    @Sequence int = NULL,
    @IsDefault bit = NULL,
    @IsTerminal bit = NULL,
    @ColorCode_Clear bit = 0,
    @ColorCode nvarchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @InsertedRow TABLE ([ID] UNIQUEIDENTIFIER)
    
    IF @ID IS NOT NULL
    BEGIN
        -- User provided a value, use it
        INSERT INTO [${flyway:defaultSchema}].[IssueStatus]
            (
                [ID],
                [Name],
                [Description],
                [Sequence],
                [IsDefault],
                [IsTerminal],
                [ColorCode]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @ID,
                @Name,
                CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, NULL) END,
                ISNULL(@Sequence, 100),
                ISNULL(@IsDefault, 0),
                ISNULL(@IsTerminal, 0),
                CASE WHEN @ColorCode_Clear = 1 THEN NULL ELSE ISNULL(@ColorCode, NULL) END
            )
    END
    ELSE
    BEGIN
        -- No value provided, let database use its default (e.g., NEWSEQUENTIALID())
        INSERT INTO [${flyway:defaultSchema}].[IssueStatus]
            (
                [Name],
                [Description],
                [Sequence],
                [IsDefault],
                [IsTerminal],
                [ColorCode]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @Name,
                CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, NULL) END,
                ISNULL(@Sequence, 100),
                ISNULL(@IsDefault, 0),
                ISNULL(@IsTerminal, 0),
                CASE WHEN @ColorCode_Clear = 1 THEN NULL ELSE ISNULL(@ColorCode, NULL) END
            )
    END
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssueStatus] WHERE [ID] = (SELECT [ID] FROM @InsertedRow)
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueStatus] TO [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issue Status */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueStatus] TO [cdp_Developer], [cdp_Integration];

/* spUpdate SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: spUpdateIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueStatus
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spUpdateIssueStatus]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueStatus];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueStatus]
    @ID uniqueidentifier,
    @Name nvarchar(100) = NULL,
    @Description_Clear bit = 0,
    @Description nvarchar(MAX) = NULL,
    @Sequence int = NULL,
    @IsDefault bit = NULL,
    @IsTerminal bit = NULL,
    @ColorCode_Clear bit = 0,
    @ColorCode nvarchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueStatus]
    SET
        [Name] = ISNULL(@Name, [Name]),
        [Description] = CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, [Description]) END,
        [Sequence] = ISNULL(@Sequence, [Sequence]),
        [IsDefault] = ISNULL(@IsDefault, [IsDefault]),
        [IsTerminal] = ISNULL(@IsTerminal, [IsTerminal]),
        [ColorCode] = CASE WHEN @ColorCode_Clear = 1 THEN NULL ELSE ISNULL(@ColorCode, [ColorCode]) END
    WHERE
        [ID] = @ID

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
        -- Nothing was updated, return no rows, but column structure from base view intact, semantically correct this way.
        SELECT TOP 0 * FROM [${flyway:defaultSchema}].[vwIssueStatus] WHERE 1=0
    ELSE
        -- Return the updated record so the caller can see the updated values and any calculated fields
        SELECT
                                        *
                                    FROM
                                        [${flyway:defaultSchema}].[vwIssueStatus]
                                    WHERE
                                        [ID] = @ID
                                    
END
GO

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueStatus] TO [cdp_Developer], [cdp_Integration]
GO

------------------------------------------------------------
----- TRIGGER FOR __mj_UpdatedAt field for the IssueStatus table
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[trgUpdateIssueStatus]', 'TR') IS NOT NULL
    DROP TRIGGER [${flyway:defaultSchema}].[trgUpdateIssueStatus];
GO
CREATE TRIGGER [${flyway:defaultSchema}].trgUpdateIssueStatus
ON [${flyway:defaultSchema}].[IssueStatus]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueStatus]
    SET
        __mj_UpdatedAt = GETUTCDATE()
    FROM
        [${flyway:defaultSchema}].[IssueStatus] AS _organicTable
    INNER JOIN
        INSERTED AS I ON
        _organicTable.[ID] = I.[ID];
END;
GO

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Status */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueStatus] TO [cdp_Developer], [cdp_Integration];

/* spDelete SQL for MJ_BizApps_Issues: Issue Status */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Status
-- Item: spDeleteIssueStatus
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueStatus
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spDeleteIssueStatus]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueStatus];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueStatus]
    @ID uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM
        [${flyway:defaultSchema}].[IssueStatus]
    WHERE
        [ID] = @ID


    -- Check if the delete was successful
    IF @@ROWCOUNT = 0
        SELECT NULL AS [ID] -- Return NULL for all primary key fields to indicate no record was deleted
    ELSE
        SELECT @ID AS [ID] -- Return the primary key values to indicate we successfully deleted the record
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueStatus] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issue Status */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueStatus] TO [cdp_Developer], [cdp_Integration];

/* Base View SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Comments
-----               SCHEMA:      ${flyway:defaultSchema}
-----               BASE TABLE:  IssueComment
-----               PRIMARY KEY: ID
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssueComments]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssueComments];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssueComments]
AS
SELECT
    i.*,
    mjBizAppsCommonPerson_AuthorPersonID.[DisplayName] AS [AuthorPerson]
FROM
    [${flyway:defaultSchema}].[IssueComment] AS i
LEFT OUTER JOIN
    [${mjSchema}_BizAppsCommon].[Person] AS mjBizAppsCommonPerson_AuthorPersonID
  ON
    [i].[AuthorPersonID] = mjBizAppsCommonPerson_AuthorPersonID.[ID]
GO
GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueComments] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: Permissions for vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueComments] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spCreateIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueComment
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spCreateIssueComment]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spCreateIssueComment];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spCreateIssueComment]
    @ID uniqueidentifier = NULL,
    @IssueID uniqueidentifier,
    @Body nvarchar(MAX),
    @AuthorPersonID_Clear bit = 0,
    @AuthorPersonID uniqueidentifier = NULL,
    @AuthorEmail_Clear bit = 0,
    @AuthorEmail nvarchar(320) = NULL,
    @Source nvarchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @InsertedRow TABLE ([ID] UNIQUEIDENTIFIER)
    
    IF @ID IS NOT NULL
    BEGIN
        -- User provided a value, use it
        INSERT INTO [${flyway:defaultSchema}].[IssueComment]
            (
                [ID],
                [IssueID],
                [Body],
                [AuthorPersonID],
                [AuthorEmail],
                [Source]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @ID,
                @IssueID,
                @Body,
                CASE WHEN @AuthorPersonID_Clear = 1 THEN NULL ELSE ISNULL(@AuthorPersonID, NULL) END,
                CASE WHEN @AuthorEmail_Clear = 1 THEN NULL ELSE ISNULL(@AuthorEmail, NULL) END,
                ISNULL(@Source, 'internal')
            )
    END
    ELSE
    BEGIN
        -- No value provided, let database use its default (e.g., NEWSEQUENTIALID())
        INSERT INTO [${flyway:defaultSchema}].[IssueComment]
            (
                [IssueID],
                [Body],
                [AuthorPersonID],
                [AuthorEmail],
                [Source]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @IssueID,
                @Body,
                CASE WHEN @AuthorPersonID_Clear = 1 THEN NULL ELSE ISNULL(@AuthorPersonID, NULL) END,
                CASE WHEN @AuthorEmail_Clear = 1 THEN NULL ELSE ISNULL(@AuthorEmail, NULL) END,
                ISNULL(@Source, 'internal')
            )
    END
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssueComments] WHERE [ID] = (SELECT [ID] FROM @InsertedRow)
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issue Comments */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spUpdate SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spUpdateIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueComment
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spUpdateIssueComment]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueComment];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueComment]
    @ID uniqueidentifier,
    @IssueID uniqueidentifier = NULL,
    @Body nvarchar(MAX) = NULL,
    @AuthorPersonID_Clear bit = 0,
    @AuthorPersonID uniqueidentifier = NULL,
    @AuthorEmail_Clear bit = 0,
    @AuthorEmail nvarchar(320) = NULL,
    @Source nvarchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueComment]
    SET
        [IssueID] = ISNULL(@IssueID, [IssueID]),
        [Body] = ISNULL(@Body, [Body]),
        [AuthorPersonID] = CASE WHEN @AuthorPersonID_Clear = 1 THEN NULL ELSE ISNULL(@AuthorPersonID, [AuthorPersonID]) END,
        [AuthorEmail] = CASE WHEN @AuthorEmail_Clear = 1 THEN NULL ELSE ISNULL(@AuthorEmail, [AuthorEmail]) END,
        [Source] = ISNULL(@Source, [Source])
    WHERE
        [ID] = @ID

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
        -- Nothing was updated, return no rows, but column structure from base view intact, semantically correct this way.
        SELECT TOP 0 * FROM [${flyway:defaultSchema}].[vwIssueComments] WHERE 1=0
    ELSE
        -- Return the updated record so the caller can see the updated values and any calculated fields
        SELECT
                                        *
                                    FROM
                                        [${flyway:defaultSchema}].[vwIssueComments]
                                    WHERE
                                        [ID] = @ID
                                    
END
GO

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueComment] TO [cdp_Developer], [cdp_Integration]
GO

------------------------------------------------------------
----- TRIGGER FOR __mj_UpdatedAt field for the IssueComment table
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[trgUpdateIssueComment]', 'TR') IS NOT NULL
    DROP TRIGGER [${flyway:defaultSchema}].[trgUpdateIssueComment];
GO
CREATE TRIGGER [${flyway:defaultSchema}].trgUpdateIssueComment
ON [${flyway:defaultSchema}].[IssueComment]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueComment]
    SET
        __mj_UpdatedAt = GETUTCDATE()
    FROM
        [${flyway:defaultSchema}].[IssueComment] AS _organicTable
    INNER JOIN
        INSERTED AS I ON
        _organicTable.[ID] = I.[ID];
END;
GO

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Comments */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spDelete SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spDeleteIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueComment
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spDeleteIssueComment]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueComment];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueComment]
    @ID uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM
        [${flyway:defaultSchema}].[IssueComment]
    WHERE
        [ID] = @ID


    -- Check if the delete was successful
    IF @@ROWCOUNT = 0
        SELECT NULL AS [ID] -- Return NULL for all primary key fields to indicate no record was deleted
    ELSE
        SELECT @ID AS [ID] -- Return the primary key values to indicate we successfully deleted the record
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issue Comments */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueComment] TO [cdp_Developer], [cdp_Integration];

/* SQL text to update entity field related entity name field map for entity field ID 2E69C90C-93CB-49C0-8852-0790AE26DD3A */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='2E69C90C-93CB-49C0-8852-0790AE26DD3A', @RelatedEntityNameFieldMap='OnCreateAction';

/* SQL text to update entity field related entity name field map for entity field ID 746B9E26-50D4-4619-B849-F050B07C0129 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='746B9E26-50D4-4619-B849-F050B07C0129', @RelatedEntityNameFieldMap='Status';

/* SQL text to update entity field related entity name field map for entity field ID 9AF0F216-6901-471A-81C6-E16E4E7134B7 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='9AF0F216-6901-471A-81C6-E16E4E7134B7', @RelatedEntityNameFieldMap='OnStatusChangeAction';

/* SQL text to update entity field related entity name field map for entity field ID 2987CFE2-3D5F-4231-8FCA-67EDC6ADC509 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='2987CFE2-3D5F-4231-8FCA-67EDC6ADC509', @RelatedEntityNameFieldMap='ReporterPerson';

/* SQL text to update entity field related entity name field map for entity field ID B4FA118C-58BE-4860-8688-C56234BD14FF */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='B4FA118C-58BE-4860-8688-C56234BD14FF', @RelatedEntityNameFieldMap='OnAssignAction';

/* SQL text to update entity field related entity name field map for entity field ID ABD84563-0AA9-4F3F-8498-1EF98134AD0E */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='ABD84563-0AA9-4F3F-8498-1EF98134AD0E', @RelatedEntityNameFieldMap='AssigneeEntity';

/* SQL text to update entity field related entity name field map for entity field ID A79B29C1-56B0-4E22-8514-A4225209BDCC */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='A79B29C1-56B0-4E22-8514-A4225209BDCC', @RelatedEntityNameFieldMap='OnCloseAction';

/* Base View SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: vwIssueTypes
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Types
-----               SCHEMA:      ${flyway:defaultSchema}
-----               BASE TABLE:  IssueType
-----               PRIMARY KEY: ID
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssueTypes]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssueTypes];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssueTypes]
AS
SELECT
    i.*,
    mjBizAppsTasksTaskType_DefaultTaskTypeID.[Name] AS [DefaultTaskType],
    MJAction_OnCreateActionID.[Name] AS [OnCreateAction],
    MJAction_OnStatusChangeActionID.[Name] AS [OnStatusChangeAction],
    MJAction_OnAssignActionID.[Name] AS [OnAssignAction],
    MJAction_OnCloseActionID.[Name] AS [OnCloseAction]
FROM
    [${flyway:defaultSchema}].[IssueType] AS i
LEFT OUTER JOIN
    [${mjSchema}_BizAppsTasks].[TaskType] AS mjBizAppsTasksTaskType_DefaultTaskTypeID
  ON
    [i].[DefaultTaskTypeID] = mjBizAppsTasksTaskType_DefaultTaskTypeID.[ID]
LEFT OUTER JOIN
    [${mjSchema}].[Action] AS MJAction_OnCreateActionID
  ON
    [i].[OnCreateActionID] = MJAction_OnCreateActionID.[ID]
LEFT OUTER JOIN
    [${mjSchema}].[Action] AS MJAction_OnStatusChangeActionID
  ON
    [i].[OnStatusChangeActionID] = MJAction_OnStatusChangeActionID.[ID]
LEFT OUTER JOIN
    [${mjSchema}].[Action] AS MJAction_OnAssignActionID
  ON
    [i].[OnAssignActionID] = MJAction_OnAssignActionID.[ID]
LEFT OUTER JOIN
    [${mjSchema}].[Action] AS MJAction_OnCloseActionID
  ON
    [i].[OnCloseActionID] = MJAction_OnCloseActionID.[ID]
GO
GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueTypes] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: Permissions for vwIssueTypes
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueTypes] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: spCreateIssueType
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueType
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spCreateIssueType]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spCreateIssueType];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spCreateIssueType]
    @ID uniqueidentifier = NULL,
    @Name nvarchar(100),
    @Description_Clear bit = 0,
    @Description nvarchar(MAX) = NULL,
    @IconClass_Clear bit = 0,
    @IconClass nvarchar(100) = NULL,
    @DefaultPriority nvarchar(20) = NULL,
    @DefaultTaskTypeID_Clear bit = 0,
    @DefaultTaskTypeID uniqueidentifier = NULL,
    @OnCreateActionID_Clear bit = 0,
    @OnCreateActionID uniqueidentifier = NULL,
    @OnStatusChangeActionID_Clear bit = 0,
    @OnStatusChangeActionID uniqueidentifier = NULL,
    @OnAssignActionID_Clear bit = 0,
    @OnAssignActionID uniqueidentifier = NULL,
    @OnCloseActionID_Clear bit = 0,
    @OnCloseActionID uniqueidentifier = NULL,
    @IsActive bit = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @InsertedRow TABLE ([ID] UNIQUEIDENTIFIER)
    
    IF @ID IS NOT NULL
    BEGIN
        -- User provided a value, use it
        INSERT INTO [${flyway:defaultSchema}].[IssueType]
            (
                [ID],
                [Name],
                [Description],
                [IconClass],
                [DefaultPriority],
                [DefaultTaskTypeID],
                [OnCreateActionID],
                [OnStatusChangeActionID],
                [OnAssignActionID],
                [OnCloseActionID],
                [IsActive]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @ID,
                @Name,
                CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, NULL) END,
                CASE WHEN @IconClass_Clear = 1 THEN NULL ELSE ISNULL(@IconClass, NULL) END,
                ISNULL(@DefaultPriority, 'Medium'),
                CASE WHEN @DefaultTaskTypeID_Clear = 1 THEN NULL ELSE ISNULL(@DefaultTaskTypeID, NULL) END,
                CASE WHEN @OnCreateActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnCreateActionID, NULL) END,
                CASE WHEN @OnStatusChangeActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnStatusChangeActionID, NULL) END,
                CASE WHEN @OnAssignActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnAssignActionID, NULL) END,
                CASE WHEN @OnCloseActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnCloseActionID, NULL) END,
                ISNULL(@IsActive, 1)
            )
    END
    ELSE
    BEGIN
        -- No value provided, let database use its default (e.g., NEWSEQUENTIALID())
        INSERT INTO [${flyway:defaultSchema}].[IssueType]
            (
                [Name],
                [Description],
                [IconClass],
                [DefaultPriority],
                [DefaultTaskTypeID],
                [OnCreateActionID],
                [OnStatusChangeActionID],
                [OnAssignActionID],
                [OnCloseActionID],
                [IsActive]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @Name,
                CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, NULL) END,
                CASE WHEN @IconClass_Clear = 1 THEN NULL ELSE ISNULL(@IconClass, NULL) END,
                ISNULL(@DefaultPriority, 'Medium'),
                CASE WHEN @DefaultTaskTypeID_Clear = 1 THEN NULL ELSE ISNULL(@DefaultTaskTypeID, NULL) END,
                CASE WHEN @OnCreateActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnCreateActionID, NULL) END,
                CASE WHEN @OnStatusChangeActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnStatusChangeActionID, NULL) END,
                CASE WHEN @OnAssignActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnAssignActionID, NULL) END,
                CASE WHEN @OnCloseActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnCloseActionID, NULL) END,
                ISNULL(@IsActive, 1)
            )
    END
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssueTypes] WHERE [ID] = (SELECT [ID] FROM @InsertedRow)
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueType] TO [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issue Types */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueType] TO [cdp_Developer], [cdp_Integration];

/* spUpdate SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: spUpdateIssueType
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueType
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spUpdateIssueType]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueType];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueType]
    @ID uniqueidentifier,
    @Name nvarchar(100) = NULL,
    @Description_Clear bit = 0,
    @Description nvarchar(MAX) = NULL,
    @IconClass_Clear bit = 0,
    @IconClass nvarchar(100) = NULL,
    @DefaultPriority nvarchar(20) = NULL,
    @DefaultTaskTypeID_Clear bit = 0,
    @DefaultTaskTypeID uniqueidentifier = NULL,
    @OnCreateActionID_Clear bit = 0,
    @OnCreateActionID uniqueidentifier = NULL,
    @OnStatusChangeActionID_Clear bit = 0,
    @OnStatusChangeActionID uniqueidentifier = NULL,
    @OnAssignActionID_Clear bit = 0,
    @OnAssignActionID uniqueidentifier = NULL,
    @OnCloseActionID_Clear bit = 0,
    @OnCloseActionID uniqueidentifier = NULL,
    @IsActive bit = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueType]
    SET
        [Name] = ISNULL(@Name, [Name]),
        [Description] = CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, [Description]) END,
        [IconClass] = CASE WHEN @IconClass_Clear = 1 THEN NULL ELSE ISNULL(@IconClass, [IconClass]) END,
        [DefaultPriority] = ISNULL(@DefaultPriority, [DefaultPriority]),
        [DefaultTaskTypeID] = CASE WHEN @DefaultTaskTypeID_Clear = 1 THEN NULL ELSE ISNULL(@DefaultTaskTypeID, [DefaultTaskTypeID]) END,
        [OnCreateActionID] = CASE WHEN @OnCreateActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnCreateActionID, [OnCreateActionID]) END,
        [OnStatusChangeActionID] = CASE WHEN @OnStatusChangeActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnStatusChangeActionID, [OnStatusChangeActionID]) END,
        [OnAssignActionID] = CASE WHEN @OnAssignActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnAssignActionID, [OnAssignActionID]) END,
        [OnCloseActionID] = CASE WHEN @OnCloseActionID_Clear = 1 THEN NULL ELSE ISNULL(@OnCloseActionID, [OnCloseActionID]) END,
        [IsActive] = ISNULL(@IsActive, [IsActive])
    WHERE
        [ID] = @ID

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
        -- Nothing was updated, return no rows, but column structure from base view intact, semantically correct this way.
        SELECT TOP 0 * FROM [${flyway:defaultSchema}].[vwIssueTypes] WHERE 1=0
    ELSE
        -- Return the updated record so the caller can see the updated values and any calculated fields
        SELECT
                                        *
                                    FROM
                                        [${flyway:defaultSchema}].[vwIssueTypes]
                                    WHERE
                                        [ID] = @ID
                                    
END
GO

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueType] TO [cdp_Developer], [cdp_Integration]
GO

------------------------------------------------------------
----- TRIGGER FOR __mj_UpdatedAt field for the IssueType table
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[trgUpdateIssueType]', 'TR') IS NOT NULL
    DROP TRIGGER [${flyway:defaultSchema}].[trgUpdateIssueType];
GO
CREATE TRIGGER [${flyway:defaultSchema}].trgUpdateIssueType
ON [${flyway:defaultSchema}].[IssueType]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueType]
    SET
        __mj_UpdatedAt = GETUTCDATE()
    FROM
        [${flyway:defaultSchema}].[IssueType] AS _organicTable
    INNER JOIN
        INSERTED AS I ON
        _organicTable.[ID] = I.[ID];
END;
GO

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Types */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueType] TO [cdp_Developer], [cdp_Integration];

/* spDelete SQL for MJ_BizApps_Issues: Issue Types */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Types
-- Item: spDeleteIssueType
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueType
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spDeleteIssueType]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueType];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueType]
    @ID uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM
        [${flyway:defaultSchema}].[IssueType]
    WHERE
        [ID] = @ID


    -- Check if the delete was successful
    IF @@ROWCOUNT = 0
        SELECT NULL AS [ID] -- Return NULL for all primary key fields to indicate no record was deleted
    ELSE
        SELECT @ID AS [ID] -- Return the primary key values to indicate we successfully deleted the record
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueType] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issue Types */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueType] TO [cdp_Developer], [cdp_Integration];

/* SQL text to update entity field related entity name field map for entity field ID E0F04D98-EC61-4713-BD51-8CFDF8650792 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='E0F04D98-EC61-4713-BD51-8CFDF8650792', @RelatedEntityNameFieldMap='SourceEntity';

/* SQL text to update entity field related entity name field map for entity field ID E26B3C93-9B7B-464A-8DB1-EEC94E99C319 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='E26B3C93-9B7B-464A-8DB1-EEC94E99C319', @RelatedEntityNameFieldMap='CreatedByPerson';

/* Base View SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: vwIssues
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issues
-----               SCHEMA:      ${flyway:defaultSchema}
-----               BASE TABLE:  Issue
-----               PRIMARY KEY: ID
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssues]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssues];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssues]
AS
SELECT
    i.*,
    mjBizAppsIssuesIssueType_IssueTypeID.[Name] AS [IssueType],
    mjBizAppsIssuesIssueStatus_StatusID.[Name] AS [Status],
    mjBizAppsCommonPerson_ReporterPersonID.[DisplayName] AS [ReporterPerson],
    MJEntity_AssigneeEntityID.[Name] AS [AssigneeEntity],
    MJEntity_SourceEntityID.[Name] AS [SourceEntity],
    mjBizAppsCommonPerson_CreatedByPersonID.[DisplayName] AS [CreatedByPerson]
FROM
    [${flyway:defaultSchema}].[Issue] AS i
INNER JOIN
    [${flyway:defaultSchema}].[IssueType] AS mjBizAppsIssuesIssueType_IssueTypeID
  ON
    [i].[IssueTypeID] = mjBizAppsIssuesIssueType_IssueTypeID.[ID]
INNER JOIN
    [${flyway:defaultSchema}].[IssueStatus] AS mjBizAppsIssuesIssueStatus_StatusID
  ON
    [i].[StatusID] = mjBizAppsIssuesIssueStatus_StatusID.[ID]
LEFT OUTER JOIN
    [${mjSchema}_BizAppsCommon].[Person] AS mjBizAppsCommonPerson_ReporterPersonID
  ON
    [i].[ReporterPersonID] = mjBizAppsCommonPerson_ReporterPersonID.[ID]
LEFT OUTER JOIN
    [${mjSchema}].[Entity] AS MJEntity_AssigneeEntityID
  ON
    [i].[AssigneeEntityID] = MJEntity_AssigneeEntityID.[ID]
LEFT OUTER JOIN
    [${mjSchema}].[Entity] AS MJEntity_SourceEntityID
  ON
    [i].[SourceEntityID] = MJEntity_SourceEntityID.[ID]
LEFT OUTER JOIN
    [${mjSchema}_BizAppsCommon].[Person] AS mjBizAppsCommonPerson_CreatedByPersonID
  ON
    [i].[CreatedByPersonID] = mjBizAppsCommonPerson_CreatedByPersonID.[ID]
GO
GRANT SELECT ON [${flyway:defaultSchema}].[vwIssues] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* Base View Permissions SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: Permissions for vwIssues
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

GRANT SELECT ON [${flyway:defaultSchema}].[vwIssues] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: spCreateIssue
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR Issue
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spCreateIssue]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spCreateIssue];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spCreateIssue]
    @ID uniqueidentifier = NULL,
    @Title nvarchar(500),
    @Description_Clear bit = 0,
    @Description nvarchar(MAX) = NULL,
    @IssueTypeID uniqueidentifier,
    @StatusID uniqueidentifier,
    @Severity nvarchar(20) = NULL,
    @Priority nvarchar(20) = NULL,
    @ReporterPersonID_Clear bit = 0,
    @ReporterPersonID uniqueidentifier = NULL,
    @ReporterEmail_Clear bit = 0,
    @ReporterEmail nvarchar(320) = NULL,
    @AssigneeEntityID_Clear bit = 0,
    @AssigneeEntityID uniqueidentifier = NULL,
    @AssigneeRecordID_Clear bit = 0,
    @AssigneeRecordID nvarchar(450) = NULL,
    @SourceEntityID_Clear bit = 0,
    @SourceEntityID uniqueidentifier = NULL,
    @SourceRecordID_Clear bit = 0,
    @SourceRecordID nvarchar(450) = NULL,
    @AppScope_Clear bit = 0,
    @AppScope nvarchar(255) = NULL,
    @ResolvedAt_Clear bit = 0,
    @ResolvedAt datetimeoffset = NULL,
    @ClosedAt_Clear bit = 0,
    @ClosedAt datetimeoffset = NULL,
    @CreatedByPersonID_Clear bit = 0,
    @CreatedByPersonID uniqueidentifier = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @InsertedRow TABLE ([ID] UNIQUEIDENTIFIER)
    
    IF @ID IS NOT NULL
    BEGIN
        -- User provided a value, use it
        INSERT INTO [${flyway:defaultSchema}].[Issue]
            (
                [ID],
                [Title],
                [Description],
                [IssueTypeID],
                [StatusID],
                [Severity],
                [Priority],
                [ReporterPersonID],
                [ReporterEmail],
                [AssigneeEntityID],
                [AssigneeRecordID],
                [SourceEntityID],
                [SourceRecordID],
                [AppScope],
                [ResolvedAt],
                [ClosedAt],
                [CreatedByPersonID]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @ID,
                @Title,
                CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, NULL) END,
                @IssueTypeID,
                @StatusID,
                ISNULL(@Severity, 'Medium'),
                ISNULL(@Priority, 'Medium'),
                CASE WHEN @ReporterPersonID_Clear = 1 THEN NULL ELSE ISNULL(@ReporterPersonID, NULL) END,
                CASE WHEN @ReporterEmail_Clear = 1 THEN NULL ELSE ISNULL(@ReporterEmail, NULL) END,
                CASE WHEN @AssigneeEntityID_Clear = 1 THEN NULL ELSE ISNULL(@AssigneeEntityID, NULL) END,
                CASE WHEN @AssigneeRecordID_Clear = 1 THEN NULL ELSE ISNULL(@AssigneeRecordID, NULL) END,
                CASE WHEN @SourceEntityID_Clear = 1 THEN NULL ELSE ISNULL(@SourceEntityID, NULL) END,
                CASE WHEN @SourceRecordID_Clear = 1 THEN NULL ELSE ISNULL(@SourceRecordID, NULL) END,
                CASE WHEN @AppScope_Clear = 1 THEN NULL ELSE ISNULL(@AppScope, NULL) END,
                CASE WHEN @ResolvedAt_Clear = 1 THEN NULL ELSE ISNULL(@ResolvedAt, NULL) END,
                CASE WHEN @ClosedAt_Clear = 1 THEN NULL ELSE ISNULL(@ClosedAt, NULL) END,
                CASE WHEN @CreatedByPersonID_Clear = 1 THEN NULL ELSE ISNULL(@CreatedByPersonID, NULL) END
            )
    END
    ELSE
    BEGIN
        -- No value provided, let database use its default (e.g., NEWSEQUENTIALID())
        INSERT INTO [${flyway:defaultSchema}].[Issue]
            (
                [Title],
                [Description],
                [IssueTypeID],
                [StatusID],
                [Severity],
                [Priority],
                [ReporterPersonID],
                [ReporterEmail],
                [AssigneeEntityID],
                [AssigneeRecordID],
                [SourceEntityID],
                [SourceRecordID],
                [AppScope],
                [ResolvedAt],
                [ClosedAt],
                [CreatedByPersonID]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @Title,
                CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, NULL) END,
                @IssueTypeID,
                @StatusID,
                ISNULL(@Severity, 'Medium'),
                ISNULL(@Priority, 'Medium'),
                CASE WHEN @ReporterPersonID_Clear = 1 THEN NULL ELSE ISNULL(@ReporterPersonID, NULL) END,
                CASE WHEN @ReporterEmail_Clear = 1 THEN NULL ELSE ISNULL(@ReporterEmail, NULL) END,
                CASE WHEN @AssigneeEntityID_Clear = 1 THEN NULL ELSE ISNULL(@AssigneeEntityID, NULL) END,
                CASE WHEN @AssigneeRecordID_Clear = 1 THEN NULL ELSE ISNULL(@AssigneeRecordID, NULL) END,
                CASE WHEN @SourceEntityID_Clear = 1 THEN NULL ELSE ISNULL(@SourceEntityID, NULL) END,
                CASE WHEN @SourceRecordID_Clear = 1 THEN NULL ELSE ISNULL(@SourceRecordID, NULL) END,
                CASE WHEN @AppScope_Clear = 1 THEN NULL ELSE ISNULL(@AppScope, NULL) END,
                CASE WHEN @ResolvedAt_Clear = 1 THEN NULL ELSE ISNULL(@ResolvedAt, NULL) END,
                CASE WHEN @ClosedAt_Clear = 1 THEN NULL ELSE ISNULL(@ClosedAt, NULL) END,
                CASE WHEN @CreatedByPersonID_Clear = 1 THEN NULL ELSE ISNULL(@CreatedByPersonID, NULL) END
            )
    END
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssues] WHERE [ID] = (SELECT [ID] FROM @InsertedRow)
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] TO [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issues */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] TO [cdp_Developer], [cdp_Integration];

/* spUpdate SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: spUpdateIssue
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR Issue
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spUpdateIssue]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spUpdateIssue];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spUpdateIssue]
    @ID uniqueidentifier,
    @Title nvarchar(500) = NULL,
    @Description_Clear bit = 0,
    @Description nvarchar(MAX) = NULL,
    @IssueTypeID uniqueidentifier = NULL,
    @StatusID uniqueidentifier = NULL,
    @Severity nvarchar(20) = NULL,
    @Priority nvarchar(20) = NULL,
    @ReporterPersonID_Clear bit = 0,
    @ReporterPersonID uniqueidentifier = NULL,
    @ReporterEmail_Clear bit = 0,
    @ReporterEmail nvarchar(320) = NULL,
    @AssigneeEntityID_Clear bit = 0,
    @AssigneeEntityID uniqueidentifier = NULL,
    @AssigneeRecordID_Clear bit = 0,
    @AssigneeRecordID nvarchar(450) = NULL,
    @SourceEntityID_Clear bit = 0,
    @SourceEntityID uniqueidentifier = NULL,
    @SourceRecordID_Clear bit = 0,
    @SourceRecordID nvarchar(450) = NULL,
    @AppScope_Clear bit = 0,
    @AppScope nvarchar(255) = NULL,
    @ResolvedAt_Clear bit = 0,
    @ResolvedAt datetimeoffset = NULL,
    @ClosedAt_Clear bit = 0,
    @ClosedAt datetimeoffset = NULL,
    @CreatedByPersonID_Clear bit = 0,
    @CreatedByPersonID uniqueidentifier = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[Issue]
    SET
        [Title] = ISNULL(@Title, [Title]),
        [Description] = CASE WHEN @Description_Clear = 1 THEN NULL ELSE ISNULL(@Description, [Description]) END,
        [IssueTypeID] = ISNULL(@IssueTypeID, [IssueTypeID]),
        [StatusID] = ISNULL(@StatusID, [StatusID]),
        [Severity] = ISNULL(@Severity, [Severity]),
        [Priority] = ISNULL(@Priority, [Priority]),
        [ReporterPersonID] = CASE WHEN @ReporterPersonID_Clear = 1 THEN NULL ELSE ISNULL(@ReporterPersonID, [ReporterPersonID]) END,
        [ReporterEmail] = CASE WHEN @ReporterEmail_Clear = 1 THEN NULL ELSE ISNULL(@ReporterEmail, [ReporterEmail]) END,
        [AssigneeEntityID] = CASE WHEN @AssigneeEntityID_Clear = 1 THEN NULL ELSE ISNULL(@AssigneeEntityID, [AssigneeEntityID]) END,
        [AssigneeRecordID] = CASE WHEN @AssigneeRecordID_Clear = 1 THEN NULL ELSE ISNULL(@AssigneeRecordID, [AssigneeRecordID]) END,
        [SourceEntityID] = CASE WHEN @SourceEntityID_Clear = 1 THEN NULL ELSE ISNULL(@SourceEntityID, [SourceEntityID]) END,
        [SourceRecordID] = CASE WHEN @SourceRecordID_Clear = 1 THEN NULL ELSE ISNULL(@SourceRecordID, [SourceRecordID]) END,
        [AppScope] = CASE WHEN @AppScope_Clear = 1 THEN NULL ELSE ISNULL(@AppScope, [AppScope]) END,
        [ResolvedAt] = CASE WHEN @ResolvedAt_Clear = 1 THEN NULL ELSE ISNULL(@ResolvedAt, [ResolvedAt]) END,
        [ClosedAt] = CASE WHEN @ClosedAt_Clear = 1 THEN NULL ELSE ISNULL(@ClosedAt, [ClosedAt]) END,
        [CreatedByPersonID] = CASE WHEN @CreatedByPersonID_Clear = 1 THEN NULL ELSE ISNULL(@CreatedByPersonID, [CreatedByPersonID]) END
    WHERE
        [ID] = @ID

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
        -- Nothing was updated, return no rows, but column structure from base view intact, semantically correct this way.
        SELECT TOP 0 * FROM [${flyway:defaultSchema}].[vwIssues] WHERE 1=0
    ELSE
        -- Return the updated record so the caller can see the updated values and any calculated fields
        SELECT
                                        *
                                    FROM
                                        [${flyway:defaultSchema}].[vwIssues]
                                    WHERE
                                        [ID] = @ID
                                    
END
GO

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] TO [cdp_Developer], [cdp_Integration]
GO

------------------------------------------------------------
----- TRIGGER FOR __mj_UpdatedAt field for the Issue table
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[trgUpdateIssue]', 'TR') IS NOT NULL
    DROP TRIGGER [${flyway:defaultSchema}].[trgUpdateIssue];
GO
CREATE TRIGGER [${flyway:defaultSchema}].trgUpdateIssue
ON [${flyway:defaultSchema}].[Issue]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[Issue]
    SET
        __mj_UpdatedAt = GETUTCDATE()
    FROM
        [${flyway:defaultSchema}].[Issue] AS _organicTable
    INNER JOIN
        INSERTED AS I ON
        _organicTable.[ID] = I.[ID];
END;
GO

/* spUpdate Permissions for MJ_BizApps_Issues: Issues */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] TO [cdp_Developer], [cdp_Integration];

/* spDelete SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: spDeleteIssue
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR Issue
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spDeleteIssue]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spDeleteIssue];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spDeleteIssue]
    @ID uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM
        [${flyway:defaultSchema}].[Issue]
    WHERE
        [ID] = @ID


    -- Check if the delete was successful
    IF @@ROWCOUNT = 0
        SELECT NULL AS [ID] -- Return NULL for all primary key fields to indicate no record was deleted
    ELSE
        SELECT @ID AS [ID] -- Return the primary key values to indicate we successfully deleted the record
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issues */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] TO [cdp_Developer], [cdp_Integration];

/* SQL text to delete unneeded entity fields (4 scoped entities) */
EXEC [${mjSchema}].[spDeleteUnneededEntityFields] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks', @EntityIDs='850E81F1-4918-4621-AE33-F5143F76E848,04858FB3-6827-4F81-BA45-5FE46B4FB69E,B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1,A36CA73A-5A42-4001-897A-8D2AED23F7D7';

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'febce0ae-971c-4681-8269-1eac104458b1' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'IssueType')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'febce0ae-971c-4681-8269-1eac104458b1',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100039,
            'IssueType',
            'Issue Type',
            NULL,
            'nvarchar',
            200,
            0,
            0,
            0,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '59a52f4b-aef9-4f17-9c7e-7e3130701267' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'Status')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '59a52f4b-aef9-4f17-9c7e-7e3130701267',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100040,
            'Status',
            'Status',
            NULL,
            'nvarchar',
            200,
            0,
            0,
            0,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '4d79151d-3797-4fa5-8595-75c6ecf2641d' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'ReporterPerson')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '4d79151d-3797-4fa5-8595-75c6ecf2641d',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100041,
            'ReporterPerson',
            'Reporter Person',
            NULL,
            'nvarchar',
            402,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '60fa8e9e-a49a-4155-8d9e-f783982afa5d' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'AssigneeEntity')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '60fa8e9e-a49a-4155-8d9e-f783982afa5d',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100042,
            'AssigneeEntity',
            'Assignee Entity',
            NULL,
            'nvarchar',
            510,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'f458312b-9b17-4fcd-9509-0b83dd129f24' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'SourceEntity')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'f458312b-9b17-4fcd-9509-0b83dd129f24',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100043,
            'SourceEntity',
            'Source Entity',
            NULL,
            'nvarchar',
            510,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '862b9f75-3f89-4d78-a765-16470952ffe0' OR (EntityID = 'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1' AND Name = 'CreatedByPerson')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '862b9f75-3f89-4d78-a765-16470952ffe0',
            'B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1', -- Entity: MJ_BizApps_Issues: Issues
            100044,
            'CreatedByPerson',
            'Created By Person',
            NULL,
            'nvarchar',
            402,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'eec0a26b-9529-4f7a-98c0-029b21c7c0a2' OR (EntityID = 'A36CA73A-5A42-4001-897A-8D2AED23F7D7' AND Name = 'AuthorPerson')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'eec0a26b-9529-4f7a-98c0-029b21c7c0a2',
            'A36CA73A-5A42-4001-897A-8D2AED23F7D7', -- Entity: MJ_BizApps_Issues: Issue Comments
            100017,
            'AuthorPerson',
            'Author Person',
            NULL,
            'nvarchar',
            402,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'd65669b6-54d3-42fc-9158-ad9356f7164b' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'DefaultTaskType')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'd65669b6-54d3-42fc-9158-ad9356f7164b',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100027,
            'DefaultTaskType',
            'Default Task Type',
            NULL,
            'nvarchar',
            200,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'b03ec0cc-07f6-4393-9101-d9f5b8e26d1c' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnCreateAction')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            'b03ec0cc-07f6-4393-9101-d9f5b8e26d1c',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100028,
            'OnCreateAction',
            'On Create Action',
            NULL,
            'nvarchar',
            850,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '77a546ce-84a1-443b-80b4-8afad8a44a7f' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnStatusChangeAction')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '77a546ce-84a1-443b-80b4-8afad8a44a7f',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100029,
            'OnStatusChangeAction',
            'On Status Change Action',
            NULL,
            'nvarchar',
            850,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '22e22d5b-4ad7-435c-84bc-ec79ba78a0cb' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnAssignAction')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '22e22d5b-4ad7-435c-84bc-ec79ba78a0cb',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100030,
            'OnAssignAction',
            'On Assign Action',
            NULL,
            'nvarchar',
            850,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '81c211b4-8636-47a3-9ce4-3bc7867896f6' OR (EntityID = '850E81F1-4918-4621-AE33-F5143F76E848' AND Name = 'OnCloseAction')) BEGIN
         INSERT INTO [${mjSchema}].[EntityField]
         (
            [ID],
            [EntityID],
            [Sequence],
            [Name],
            [DisplayName],
            [Description],
            [Type],
            [Length],
            [Precision],
            [Scale],
            [AllowsNull],
            [DefaultValue],
            [AutoIncrement],
            [AllowUpdateAPI],
            [IsVirtual],
            [IsComputed],
            [RelatedEntityID],
            [RelatedEntityFieldName],
            [IsNameField],
            [IncludeInUserSearchAPI],
            [IncludeRelatedEntityNameFieldInBaseView],
            [DefaultInView],
            [IsPrimaryKey],
            [IsUnique],
            [RelatedEntityDisplayType],
            [__mj_CreatedAt],
            [__mj_UpdatedAt]
         )
         VALUES
         (
            '81c211b4-8636-47a3-9ce4-3bc7867896f6',
            '850E81F1-4918-4621-AE33-F5143F76E848', -- Entity: MJ_BizApps_Issues: Issue Types
            100031,
            'OnCloseAction',
            'On Close Action',
            NULL,
            'nvarchar',
            850,
            0,
            0,
            1,
            NULL,
            0,
            0,
            1,
            0,
            NULL,
            NULL,
            0,
            0,
            0,
            0,
            0,
            0,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to update existing entity fields from schema (4 scoped entities) */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks', @EntityIDs='850E81F1-4918-4621-AE33-F5143F76E848,04858FB3-6827-4F81-BA45-5FE46B4FB69E,B6AAD5F4-938C-441E-A2A7-27B0DBAE61D1,A36CA73A-5A42-4001-897A-8D2AED23F7D7';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

