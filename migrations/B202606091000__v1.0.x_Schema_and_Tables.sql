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
    IssueNumber NVARCHAR(50) NULL,
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
    CONSTRAINT UQ_Issue_IssueNumber UNIQUE (IssueNumber),
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

---------------------------------------------------------------------------
-- 2.5 IssueNumberSequence — per-scope gap-free counter backing the
--     human-readable Issue.IssueNumber. ScopeCode is the NORMALIZED
--     (trimmed/uppercased) AppScope, or 'ISS' when an issue has no AppScope.
--     Maintained ONLY by spAssignNextIssueNumber — never write directly.
---------------------------------------------------------------------------
CREATE TABLE ${flyway:defaultSchema}.IssueNumberSequence (
    ScopeCode NVARCHAR(50) NOT NULL,
    NextSequenceNumber INT NOT NULL DEFAULT 1,
    CONSTRAINT PK_IssueNumberSequence PRIMARY KEY (ScopeCode),
    CONSTRAINT CK_IssueNumberSequence_NextSeq CHECK (NextSequenceNumber > 0)
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
-- 4. STORED PROCEDURES — custom business logic (NOT CRUD; CodeGen owns spCreate/
--    spUpdate/spDelete). Hand-written here, mirroring bizapps-accounting's
--    spAssignNextBatchNumber pattern.
-- =============================================================================

---------------------------------------------------------------------------
-- 4.1 spAssignNextIssueNumber — assigns the next human-readable IssueNumber
--     for a scope. Normalizes scope (trim/UPPER, null/blank → 'ISS'),
--     atomically increments the per-scope counter under UPDLOCK/HOLDLOCK, and
--     returns the formatted unpadded {SCOPE}-{seq} (e.g. MJC-42). Called from
--     IssueEntityServer.Save() on insert. A number is consumed when this runs;
--     if the subsequent insert rolls back the number is skipped (standard
--     sequence behavior — unique + monotonic, occasional cosmetic gaps accepted).
---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE ${flyway:defaultSchema}.spAssignNextIssueNumber
    @AppScope NVARCHAR(255) = NULL,
    @IssueNumber NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Scope NVARCHAR(50) = NULLIF(LTRIM(RTRIM(UPPER(@AppScope))), N'');
    IF @Scope IS NULL SET @Scope = N'ISS';

    DECLARE @Seq INT;

    BEGIN TRAN;
        UPDATE ${flyway:defaultSchema}.IssueNumberSequence WITH (UPDLOCK, HOLDLOCK)
            SET @Seq = NextSequenceNumber, NextSequenceNumber = NextSequenceNumber + 1
            WHERE ScopeCode = @Scope;

        IF @@ROWCOUNT = 0
        BEGIN
            INSERT ${flyway:defaultSchema}.IssueNumberSequence (ScopeCode, NextSequenceNumber)
                VALUES (@Scope, 2);
            SET @Seq = 1;
        END
    COMMIT;

    SET @IssueNumber = @Scope + N'-' + CAST(@Seq AS NVARCHAR(20));   -- unpadded, e.g. MJC-42
END;
GO

-- =============================================================================
-- 5. EXTENDED PROPERTIES (MS_Description) — schema, tables, and every column
-- =============================================================================

-- Schema
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'BizApps Issues: reusable case / issue / ticket primitives. The shared foundation for ticketing UX (Izzy) and the destination for MJ cloud feedback.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}';
GO

---------------------------------------------------------------------------
-- 5.1 IssueType
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
-- 5.2 IssueStatus
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
-- 5.3 Issue
---------------------------------------------------------------------------
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier (UUID).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'ID';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Human-readable case identifier, format {SCOPE}-{seq} (e.g. ''MJC-42''), where SCOPE is the normalized (trim/UPPER) AppScope or ''ISS'' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'Issue', @level2type = N'COLUMN', @level2name = N'IssueNumber';
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
-- 5.4 IssueComment
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

---------------------------------------------------------------------------
-- 5.5 IssueNumberSequence
---------------------------------------------------------------------------
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Per-scope gap-free counter backing the human-readable Issue.IssueNumber. One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueNumberSequence';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The normalized (trim/UPPER) AppScope this counter is for, or ''ISS'' when an issue has no AppScope. Primary key.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueNumberSequence', @level2type = N'COLUMN', @level2name = N'ScopeCode';
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueNumberSequence', @level2type = N'COLUMN', @level2name = N'NextSequenceNumber';
GO




















































































/*---------------------------------------CODEGEN-----------------------------------*/
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
         'b08fb976-cc72-4dac-b950-a5c86dd04267',
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
                       VALUES ('7cc8c510-249d-4a54-a96d-198be952ef11', '${flyway:defaultSchema}', 'Generated for schema', '${flyway:defaultSchema}', 'mjbizappsissues', 1);

/* Adding role UI to application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[ApplicationRole]
                                 ([ApplicationID], [RoleID], [CanAccess], [CanAdmin]) VALUES
                                 ('7cc8c510-249d-4a54-a96d-198be952ef11', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0);

/* Adding role Developer to application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[ApplicationRole]
                                 ([ApplicationID], [RoleID], [CanAccess], [CanAdmin]) VALUES
                                 ('7cc8c510-249d-4a54-a96d-198be952ef11', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1);

/* Adding role Integration to application ${flyway:defaultSchema} */
INSERT INTO [${mjSchema}].[ApplicationRole]
                                 ([ApplicationID], [RoleID], [CanAccess], [CanAdmin]) VALUES
                                 ('7cc8c510-249d-4a54-a96d-198be952ef11', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0);

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Types to application ID: '7cc8c510-249d-4a54-a96d-198be952ef11' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('7cc8c510-249d-4a54-a96d-198be952ef11', 'b08fb976-cc72-4dac-b950-a5c86dd04267', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '7cc8c510-249d-4a54-a96d-198be952ef11'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('b08fb976-cc72-4dac-b950-a5c86dd04267', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('b08fb976-cc72-4dac-b950-a5c86dd04267', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Types for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('b08fb976-cc72-4dac-b950-a5c86dd04267', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

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
         '07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4',
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

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Status to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '7CC8C510-249D-4A54-A96D-198BE952EF11'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Status for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('07e2bd79-ba8a-4b9c-8d45-4ea3a9922de4', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

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
         '65e7dad5-9930-4140-9a38-2184eb0097da',
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

/* SQL generated to add new entity MJ_BizApps_Issues: Issues to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '65e7dad5-9930-4140-9a38-2184eb0097da', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '7CC8C510-249D-4A54-A96D-198BE952EF11'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('65e7dad5-9930-4140-9a38-2184eb0097da', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('65e7dad5-9930-4140-9a38-2184eb0097da', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issues for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('65e7dad5-9930-4140-9a38-2184eb0097da', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

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
         '7124a46d-ea35-4c8b-bbbb-f19287ed0f9b',
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

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Comments to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '7CC8C510-249D-4A54-A96D-198BE952EF11'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Comments for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('7124a46d-ea35-4c8b-bbbb-f19287ed0f9b', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to create new entity MJ_BizApps_Issues: Issue Number Sequences */

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
         '595e3981-ee66-4b41-8579-2255a0c7610c',
         'MJ_BizApps_Issues: Issue Number Sequences',
         'Issue Number Sequences',
         'Per-scope gap-free counter backing the human-readable Issue.IssueNumber. One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.',
         NULL,
         'IssueNumberSequence',
         'vwIssueNumberSequences',
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

/* SQL generated to add new entity MJ_BizApps_Issues: Issue Number Sequences to application ID: '7CC8C510-249D-4A54-A96D-198BE952EF11' */
INSERT INTO [${mjSchema}].[ApplicationEntity]
                                       ([ApplicationID], [EntityID], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                       ('7CC8C510-249D-4A54-A96D-198BE952EF11', '595e3981-ee66-4b41-8579-2255a0c7610c', (SELECT COALESCE(MAX([Sequence]),0)+1 FROM [${mjSchema}].[ApplicationEntity] WHERE [ApplicationID] = '7CC8C510-249D-4A54-A96D-198BE952EF11'), GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Number Sequences for role UI */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('595e3981-ee66-4b41-8579-2255a0c7610c', 'E0AFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 0, 0, 0, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Number Sequences for role Developer */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('595e3981-ee66-4b41-8579-2255a0c7610c', 'DEAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

/* SQL generated to add new permission for entity MJ_BizApps_Issues: Issue Number Sequences for role Integration */
INSERT INTO [${mjSchema}].[EntityPermission]
                                                   ([EntityID], [RoleID], [CanRead], [CanCreate], [CanUpdate], [CanDelete], [__mj_CreatedAt], [__mj_UpdatedAt]) VALUES
                                                   ('595e3981-ee66-4b41-8579-2255a0c7610c', 'DFAFCCEC-6A37-EF11-86D4-000D3A4E707E', 1, 1, 1, 1, GETUTCDATE(), GETUTCDATE());

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

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
ALTER TABLE [${flyway:defaultSchema}].[IssueNumberSequence] ADD [__mj_CreatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
UPDATE [${flyway:defaultSchema}].[IssueNumberSequence] SET [__mj_CreatedAt] = GETUTCDATE() WHERE [__mj_CreatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
ALTER TABLE [${flyway:defaultSchema}].[IssueNumberSequence] ALTER COLUMN [__mj_CreatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_CreatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
ALTER TABLE [${flyway:defaultSchema}].[IssueNumberSequence] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueNumberSequence___mj_CreatedAt] DEFAULT GETUTCDATE() FOR [__mj_CreatedAt];
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
ALTER TABLE [${flyway:defaultSchema}].[IssueNumberSequence] ADD [__mj_UpdatedAt] DATETIMEOFFSET NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
UPDATE [${flyway:defaultSchema}].[IssueNumberSequence] SET [__mj_UpdatedAt] = GETUTCDATE() WHERE [__mj_UpdatedAt] IS NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
ALTER TABLE [${flyway:defaultSchema}].[IssueNumberSequence] ALTER COLUMN [__mj_UpdatedAt] DATETIMEOFFSET NOT NULL;
GO

/* SQL text to add special date field __mj_UpdatedAt to entity ${flyway:defaultSchema}.IssueNumberSequence */
ALTER TABLE [${flyway:defaultSchema}].[IssueNumberSequence] ADD CONSTRAINT [DF___mj_BizAppsIssues_IssueNumberSequence___mj_UpdatedAt] DEFAULT GETUTCDATE() FOR [__mj_UpdatedAt];
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

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'd3cf7eac-3527-47dd-87dd-da8744cda808' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'ID')) BEGIN
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
            'd3cf7eac-3527-47dd-87dd-da8744cda808',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'adddcc67-6c31-4e40-8c22-aaaf2e9eb165' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'IssueNumber')) BEGIN
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
            'adddcc67-6c31-4e40-8c22-aaaf2e9eb165',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100002,
            'IssueNumber',
            'Issue Number',
            'Human-readable case identifier, format {SCOPE}-{seq} (e.g. ''MJC-42''), where SCOPE is the normalized (trim/UPPER) AppScope or ''ISS'' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.',
            'nvarchar',
            100,
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
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'fbda77b7-3edb-4d32-a7d4-06fe401457be' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'Title')) BEGIN
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
            'fbda77b7-3edb-4d32-a7d4-06fe401457be',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100003,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '1ce66015-9e1b-4e20-be02-922d1d91a619' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'Description')) BEGIN
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
            '1ce66015-9e1b-4e20-be02-922d1d91a619',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100004,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e4408976-8a26-42d6-9b2d-81216476ad9c' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'IssueTypeID')) BEGIN
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
            'e4408976-8a26-42d6-9b2d-81216476ad9c',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100005,
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
            'B08FB976-CC72-4DAC-B950-A5C86DD04267',
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '2963d2bc-0473-47a0-be0a-0e1bd925928b' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'StatusID')) BEGIN
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
            '2963d2bc-0473-47a0-be0a-0e1bd925928b',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100006,
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
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4',
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '99c48bc4-c15e-440a-a577-ec5ba8f9e48b' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'Severity')) BEGIN
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
            '99c48bc4-c15e-440a-a577-ec5ba8f9e48b',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100007,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '7c48ec27-0691-4ce9-b990-f554caf50864' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'Priority')) BEGIN
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
            '7c48ec27-0691-4ce9-b990-f554caf50864',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100008,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '06ed94d8-4607-4061-888e-788ffafca023' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'ReporterPersonID')) BEGIN
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
            '06ed94d8-4607-4061-888e-788ffafca023',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100009,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '65c94b3c-a5bf-4d2d-bbff-289a0c041047' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'ReporterEmail')) BEGIN
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
            '65c94b3c-a5bf-4d2d-bbff-289a0c041047',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100010,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5d649c62-6589-43f0-affd-e3f9e3268cc8' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'AssigneeEntityID')) BEGIN
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
            '5d649c62-6589-43f0-affd-e3f9e3268cc8',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100011,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '24653d3b-faed-4a91-bd7f-8c903b8ad018' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'AssigneeRecordID')) BEGIN
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
            '24653d3b-faed-4a91-bd7f-8c903b8ad018',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100012,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9d602c66-9fb5-4514-9ed6-7b530012ae3a' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'SourceEntityID')) BEGIN
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
            '9d602c66-9fb5-4514-9ed6-7b530012ae3a',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100013,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5e4d5272-5f71-4e7f-99b0-f0d9de5c3641' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'SourceRecordID')) BEGIN
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
            '5e4d5272-5f71-4e7f-99b0-f0d9de5c3641',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100014,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'bdc175d9-3f7b-4818-af86-801d821b9276' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'AppScope')) BEGIN
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
            'bdc175d9-3f7b-4818-af86-801d821b9276',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100015,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'd50b709a-c90f-4771-abef-9a108002a341' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'ResolvedAt')) BEGIN
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
            'd50b709a-c90f-4771-abef-9a108002a341',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100016,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9ab132e0-fb1a-410a-a736-ddfbb0388f7e' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'ClosedAt')) BEGIN
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
            '9ab132e0-fb1a-410a-a736-ddfbb0388f7e',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100017,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '2bdfb21a-baf7-482d-98c5-4dfd03ff45ee' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'CreatedByPersonID')) BEGIN
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
            '2bdfb21a-baf7-482d-98c5-4dfd03ff45ee',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100018,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'd6995810-5f0a-4775-8e81-9bd304dca9e0' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = '__mj_CreatedAt')) BEGIN
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
            'd6995810-5f0a-4775-8e81-9bd304dca9e0',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100019,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '77f34775-1c61-4921-ac99-045d0a20b9bf' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = '__mj_UpdatedAt')) BEGIN
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
            '77f34775-1c61-4921-ac99-045d0a20b9bf',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100020,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '3737e78f-3cab-49cf-ab9e-635da764e876' OR (EntityID = '595E3981-EE66-4B41-8579-2255A0C7610C' AND Name = 'ScopeCode')) BEGIN
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
            '3737e78f-3cab-49cf-ab9e-635da764e876',
            '595E3981-EE66-4B41-8579-2255A0C7610C', -- Entity: MJ_BizApps_Issues: Issue Number Sequences
            100001,
            'ScopeCode',
            'Scope Code',
            'The normalized (trim/UPPER) AppScope this counter is for, or ''ISS'' when an issue has no AppScope. Primary key.',
            'nvarchar',
            100,
            0,
            0,
            0,
            NULL,
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
            1,
            1,
            'Search',
            GETUTCDATE(),
            GETUTCDATE()
         )
      END;

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '219d0d34-f277-4222-b9a1-f5a9f155abca' OR (EntityID = '595E3981-EE66-4B41-8579-2255A0C7610C' AND Name = 'NextSequenceNumber')) BEGIN
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
            '219d0d34-f277-4222-b9a1-f5a9f155abca',
            '595E3981-EE66-4B41-8579-2255A0C7610C', -- Entity: MJ_BizApps_Issues: Issue Number Sequences
            100002,
            'NextSequenceNumber',
            'Next Sequence Number',
            'The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.',
            'int',
            4,
            10,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'ee76be39-ba96-4c56-849b-d92c27504b43' OR (EntityID = '595E3981-EE66-4B41-8579-2255A0C7610C' AND Name = '__mj_CreatedAt')) BEGIN
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
            'ee76be39-ba96-4c56-849b-d92c27504b43',
            '595E3981-EE66-4B41-8579-2255A0C7610C', -- Entity: MJ_BizApps_Issues: Issue Number Sequences
            100003,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '30118bfc-fe8a-4fe4-903c-79184edce894' OR (EntityID = '595E3981-EE66-4B41-8579-2255A0C7610C' AND Name = '__mj_UpdatedAt')) BEGIN
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
            '30118bfc-fe8a-4fe4-903c-79184edce894',
            '595E3981-EE66-4B41-8579-2255A0C7610C', -- Entity: MJ_BizApps_Issues: Issue Number Sequences
            100004,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '53331d4b-d295-4df9-a97b-9f63bce62e71' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'ID')) BEGIN
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
            '53331d4b-d295-4df9-a97b-9f63bce62e71',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '71b2f634-7594-490a-9bfd-d130b8193c5e' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'Name')) BEGIN
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
            '71b2f634-7594-490a-9bfd-d130b8193c5e',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9487b754-90b9-42f9-ae1c-b59b0becfb2c' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'Description')) BEGIN
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
            '9487b754-90b9-42f9-ae1c-b59b0becfb2c',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'da13598b-b481-48a7-969d-ac8cc80af61a' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'Sequence')) BEGIN
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
            'da13598b-b481-48a7-969d-ac8cc80af61a',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e66776d3-0318-4c92-b30a-373fb4d64d9d' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'IsDefault')) BEGIN
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
            'e66776d3-0318-4c92-b30a-373fb4d64d9d',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '04aa5244-2c13-4768-826b-94f72805efd5' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'IsTerminal')) BEGIN
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
            '04aa5244-2c13-4768-826b-94f72805efd5',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '796866ab-7cae-4ce7-9e17-2b7a38e86639' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = 'ColorCode')) BEGIN
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
            '796866ab-7cae-4ce7-9e17-2b7a38e86639',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '29e0d51a-6e88-44f6-b2c5-6156bc4fafca' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = '__mj_CreatedAt')) BEGIN
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
            '29e0d51a-6e88-44f6-b2c5-6156bc4fafca',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'a40692e4-de3e-41bf-acbd-d1cb45d4d1ab' OR (EntityID = '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4' AND Name = '__mj_UpdatedAt')) BEGIN
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
            'a40692e4-de3e-41bf-acbd-d1cb45d4d1ab',
            '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', -- Entity: MJ_BizApps_Issues: Issue Status
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e6f9e9bb-4c8a-45b7-94db-452b255dc1a1' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'ID')) BEGIN
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
            'e6f9e9bb-4c8a-45b7-94db-452b255dc1a1',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '1b4a00a6-7843-49c4-93f3-d5c13272070b' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'Name')) BEGIN
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
            '1b4a00a6-7843-49c4-93f3-d5c13272070b',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '0e58fdbe-c30e-41c9-abc2-51de6b1bd2d6' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'Description')) BEGIN
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
            '0e58fdbe-c30e-41c9-abc2-51de6b1bd2d6',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'f06f4ff7-111b-407b-99f0-0b551c656f43' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'IconClass')) BEGIN
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
            'f06f4ff7-111b-407b-99f0-0b551c656f43',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'efb68536-dc99-4f27-a77a-bf23a026ea67' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'DefaultPriority')) BEGIN
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
            'efb68536-dc99-4f27-a77a-bf23a026ea67',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '6c0b349f-4042-42b6-b8f9-b9d4a681de80' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'DefaultTaskTypeID')) BEGIN
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
            '6c0b349f-4042-42b6-b8f9-b9d4a681de80',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '86b9ec44-d8da-4540-9638-db50f4d92bc4' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnCreateActionID')) BEGIN
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
            '86b9ec44-d8da-4540-9638-db50f4d92bc4',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '7d858a44-3534-468d-9e48-be4c8dc93052' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnStatusChangeActionID')) BEGIN
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
            '7d858a44-3534-468d-9e48-be4c8dc93052',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'ae7027e2-994b-45ec-9f35-220a7664ab85' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnAssignActionID')) BEGIN
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
            'ae7027e2-994b-45ec-9f35-220a7664ab85',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '569d75f7-f081-4bc2-8990-321b8b9d92b6' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnCloseActionID')) BEGIN
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
            '569d75f7-f081-4bc2-8990-321b8b9d92b6',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '4fea107e-b189-4bad-85a6-7ecfabbf9b15' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'IsActive')) BEGIN
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
            '4fea107e-b189-4bad-85a6-7ecfabbf9b15',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e8f4cc38-d394-442e-a438-e30e70f07a5d' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = '__mj_CreatedAt')) BEGIN
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
            'e8f4cc38-d394-442e-a438-e30e70f07a5d',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'f09b3838-633a-4b51-88ca-5ab6e5e0af5d' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = '__mj_UpdatedAt')) BEGIN
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
            'f09b3838-633a-4b51-88ca-5ab6e5e0af5d',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '56419321-e23c-44ae-92e5-60060382f4fa' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'ID')) BEGIN
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
            '56419321-e23c-44ae-92e5-60060382f4fa',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'bb65e98f-c7c3-41bc-a268-5added0d5f5f' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'IssueID')) BEGIN
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
            'bb65e98f-c7c3-41bc-a268-5added0d5f5f',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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
            '65E7DAD5-9930-4140-9A38-2184EB0097DA',
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '4fb78308-1867-468d-916a-8118960e8c55' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'Body')) BEGIN
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
            '4fb78308-1867-468d-916a-8118960e8c55',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '31762b00-ece7-4760-ac10-b11d53793fbc' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'AuthorPersonID')) BEGIN
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
            '31762b00-ece7-4760-ac10-b11d53793fbc',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '0b6ee56c-7364-491f-bc0b-de8b0d69d271' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'AuthorEmail')) BEGIN
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
            '0b6ee56c-7364-491f-bc0b-de8b0d69d271',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '89d0ecae-49f6-4730-b9e4-1f0cfe373571' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'Source')) BEGIN
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
            '89d0ecae-49f6-4730-b9e4-1f0cfe373571',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'ef200acb-07a0-44be-9c7a-d14f4a72dcd2' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = '__mj_CreatedAt')) BEGIN
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
            'ef200acb-07a0-44be-9c7a-d14f4a72dcd2',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '84fda08a-9365-4e56-8129-9808d2de19cd' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = '__mj_UpdatedAt')) BEGIN
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
            '84fda08a-9365-4e56-8129-9808d2de19cd',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

/* SQL text to update existing entity fields from schema */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to insert entity field value with ID f4da53b8-1f68-4b47-9fed-9b1c6b994e2e */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('f4da53b8-1f68-4b47-9fed-9b1c6b994e2e', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID b270a0e0-c7be-4501-b286-86cc2e283687 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('b270a0e0-c7be-4501-b286-86cc2e283687', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 813067f5-4b0e-40a6-b520-a2a3aa625a5f */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('813067f5-4b0e-40a6-b520-a2a3aa625a5f', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 65f40fc7-4e6a-47e0-b9b7-fb50af4ba974 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('65f40fc7-4e6a-47e0-b9b7-fb50af4ba974', 'EFB68536-DC99-4F27-A77A-BF23A026EA67', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID EFB68536-DC99-4F27-A77A-BF23A026EA67 */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='EFB68536-DC99-4F27-A77A-BF23A026EA67';

/* SQL text to insert entity field value with ID ca6fc02c-b8cb-4d23-beea-e6723b62819c */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('ca6fc02c-b8cb-4d23-beea-e6723b62819c', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID fab9481d-7b62-43a9-b877-de9e64384e9b */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('fab9481d-7b62-43a9-b877-de9e64384e9b', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 6df6d410-ec3b-4bb8-a516-7e1503239c95 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('6df6d410-ec3b-4bb8-a516-7e1503239c95', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID e2894566-56a3-447a-862d-991ef022c901 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('e2894566-56a3-447a-862d-991ef022c901', '99C48BC4-C15E-440A-A577-EC5BA8F9E48B', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 99C48BC4-C15E-440A-A577-EC5BA8F9E48B */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='99C48BC4-C15E-440A-A577-EC5BA8F9E48B';

/* SQL text to insert entity field value with ID 5528e199-3685-4c18-9111-5317317eef89 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('5528e199-3685-4c18-9111-5317317eef89', '7C48EC27-0691-4CE9-B990-F554CAF50864', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 841e073d-a57c-4955-8564-c0ada179919b */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('841e073d-a57c-4955-8564-c0ada179919b', '7C48EC27-0691-4CE9-B990-F554CAF50864', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID f597c29a-597c-401a-81dd-121b5d78fa3c */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('f597c29a-597c-401a-81dd-121b5d78fa3c', '7C48EC27-0691-4CE9-B990-F554CAF50864', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 736dc174-b083-4377-9095-536851653c53 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('736dc174-b083-4377-9095-536851653c53', '7C48EC27-0691-4CE9-B990-F554CAF50864', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 7C48EC27-0691-4CE9-B990-F554CAF50864 */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='7C48EC27-0691-4CE9-B990-F554CAF50864';

/* SQL text to insert entity field value with ID e875c064-3d9d-407e-a4e5-c27c1f793206 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('e875c064-3d9d-407e-a4e5-c27c1f793206', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 1, 'email', 'email', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID d954ba16-f348-4746-a7a7-5273c3ef3834 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('d954ba16-f348-4746-a7a7-5273c3ef3834', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 2, 'external', 'external', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID cb674c9d-5dc8-42b4-b37b-59cb1cc1a81c */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('cb674c9d-5dc8-42b4-b37b-59cb1cc1a81c', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 3, 'internal', 'internal', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 89D0ECAE-49F6-4730-B9E4-1F0CFE373571 */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='89D0ECAE-49F6-4730-B9E4-1F0CFE373571';


/* Create Entity Relationship: MJ_BizApps_Issues: Issues -> MJ_BizApps_Issues: Issue Comments (One To Many via IssueID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'cae6eb89-1cb9-4391-81d9-124bbac74644'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('cae6eb89-1cb9-4391-81d9-124bbac74644', '65E7DAD5-9930-4140-9A38-2184EB0097DA', '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', 'IssueID', 'One To Many', 1, 1, 1, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Issues: Issue Status -> MJ_BizApps_Issues: Issues (One To Many via StatusID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '74a84bb4-67d9-4e29-89a2-0818b142b9ec'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('74a84bb4-67d9-4e29-89a2-0818b142b9ec', '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'StatusID', 'One To Many', 1, 1, 1, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Entities -> MJ_BizApps_Issues: Issues (One To Many via SourceEntityID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'd3c32ecd-b2f2-4cc5-8878-b62e6d4b5945'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('d3c32ecd-b2f2-4cc5-8878-b62e6d4b5945', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'SourceEntityID', 'One To Many', 1, 1, 66, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Entities -> MJ_BizApps_Issues: Issues (One To Many via AssigneeEntityID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '6c76d6fc-300b-408d-81bc-055f26e11997'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('6c76d6fc-300b-408d-81bc-055f26e11997', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'AssigneeEntityID', 'One To Many', 1, 1, 67, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnStatusChangeActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '409edb50-0922-498b-95f5-3078b69ce6a9'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('409edb50-0922-498b-95f5-3078b69ce6a9', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnStatusChangeActionID', 'One To Many', 1, 1, 18, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnCreateActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '2bca9ab1-1522-4ded-9ac7-73691b84cfd2'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('2bca9ab1-1522-4ded-9ac7-73691b84cfd2', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnCreateActionID', 'One To Many', 1, 1, 19, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnAssignActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '5bf4718b-8311-4eec-a0c0-e31a80533301'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('5bf4718b-8311-4eec-a0c0-e31a80533301', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnAssignActionID', 'One To Many', 1, 1, 20, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ: Actions -> MJ_BizApps_Issues: Issue Types (One To Many via OnCloseActionID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '78969fa0-3215-4fff-8316-83954d959dd6'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('78969fa0-3215-4fff-8316-83954d959dd6', '38248F34-2837-EF11-86D4-6045BDEE16E6', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'OnCloseActionID', 'One To Many', 1, 1, 21, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Issues: Issue Types -> MJ_BizApps_Issues: Issues (One To Many via IssueTypeID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '04d5ab9f-1427-4a04-8113-217200288689'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('04d5ab9f-1427-4a04-8113-217200288689', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'IssueTypeID', 'One To Many', 1, 1, 1, GETUTCDATE(), GETUTCDATE())
   END;


/* Create Entity Relationship: MJ_BizApps_Tasks: Task Types -> MJ_BizApps_Issues: Issue Types (One To Many via DefaultTaskTypeID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = 'bbb1c55f-49e2-48ad-9e4a-666ee656741b'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('bbb1c55f-49e2-48ad-9e4a-666ee656741b', '1E30141A-826F-4278-BAA9-BBE14D29E606', 'B08FB976-CC72-4DAC-B950-A5C86DD04267', 'DefaultTaskTypeID', 'One To Many', 1, 1, 4, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Common: People -> MJ_BizApps_Issues: Issue Comments (One To Many via AuthorPersonID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '2c0b564a-d076-4591-9687-f62fefbb3f75'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('2c0b564a-d076-4591-9687-f62fefbb3f75', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', 'AuthorPersonID', 'One To Many', 1, 1, 8, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Common: People -> MJ_BizApps_Issues: Issues (One To Many via ReporterPersonID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '1ce94364-82a1-44ef-8feb-0f8785691ab4'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('1ce94364-82a1-44ef-8feb-0f8785691ab4', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'ReporterPersonID', 'One To Many', 1, 1, 9, GETUTCDATE(), GETUTCDATE())
   END;
                    
/* Create Entity Relationship: MJ_BizApps_Common: People -> MJ_BizApps_Issues: Issues (One To Many via CreatedByPersonID) */
   IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntityRelationship] WHERE [ID] = '50190acd-091e-41d6-8738-aeabcc020ddb'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntityRelationship] ([ID], [EntityID], [RelatedEntityID], [RelatedEntityJoinField], [Type], [BundleInAPI], [DisplayInForm], [Sequence], [__mj_CreatedAt], [__mj_UpdatedAt])
                    VALUES ('50190acd-091e-41d6-8738-aeabcc020ddb', '7A94ADA9-7880-4FAE-97D8-DB0E934C3F5F', '65E7DAD5-9930-4140-9A38-2184EB0097DA', 'CreatedByPersonID', 'One To Many', 1, 1, 10, GETUTCDATE(), GETUTCDATE())
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

/* SQL text to update entity field related entity name field map for entity field ID 31762B00-ECE7-4760-AC10-B11D53793FBC */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='31762B00-ECE7-4760-AC10-B11D53793FBC', @RelatedEntityNameFieldMap='AuthorPerson';

/* Index for Foreign Keys for IssueNumberSequence */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: Index for Foreign Keys
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------;

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

/* SQL text to update entity field related entity name field map for entity field ID 6C0B349F-4042-42B6-B8F9-B9D4A681DE80 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='6C0B349F-4042-42B6-B8F9-B9D4A681DE80', @RelatedEntityNameFieldMap='DefaultTaskType';

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

/* SQL text to update entity field related entity name field map for entity field ID E4408976-8A26-42D6-9B2D-81216476AD9C */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='E4408976-8A26-42D6-9B2D-81216476AD9C', @RelatedEntityNameFieldMap='IssueType';

/* Base View SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: vwIssueNumberSequences
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Number Sequences
-----               SCHEMA:      ${flyway:defaultSchema}
-----               BASE TABLE:  IssueNumberSequence
-----               PRIMARY KEY: ScopeCode
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssueNumberSequences]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssueNumberSequences];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssueNumberSequences]
AS
SELECT
    i.*
FROM
    [${flyway:defaultSchema}].[IssueNumberSequence] AS i
GO
GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueNumberSequences] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: Permissions for vwIssueNumberSequences
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueNumberSequences] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: spCreateIssueNumberSequence
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueNumberSequence
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spCreateIssueNumberSequence]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spCreateIssueNumberSequence];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spCreateIssueNumberSequence]
    @ScopeCode nvarchar(50) = NULL,
    @NextSequenceNumber int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO
    [${flyway:defaultSchema}].[IssueNumberSequence]
        (
            [NextSequenceNumber],
                [ScopeCode]
        )
    VALUES
        (
            ISNULL(@NextSequenceNumber, 1),
                @ScopeCode
        )
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssueNumberSequences] WHERE [ScopeCode] = @ScopeCode
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueNumberSequence] TO [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issue Number Sequences */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueNumberSequence] TO [cdp_Developer], [cdp_Integration];

/* spUpdate SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: spUpdateIssueNumberSequence
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueNumberSequence
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spUpdateIssueNumberSequence]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueNumberSequence];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueNumberSequence]
    @ScopeCode nvarchar(50),
    @NextSequenceNumber int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueNumberSequence]
    SET
        [NextSequenceNumber] = ISNULL(@NextSequenceNumber, [NextSequenceNumber])
    WHERE
        [ScopeCode] = @ScopeCode

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
        -- Nothing was updated, return no rows, but column structure from base view intact, semantically correct this way.
        SELECT TOP 0 * FROM [${flyway:defaultSchema}].[vwIssueNumberSequences] WHERE 1=0
    ELSE
        -- Return the updated record so the caller can see the updated values and any calculated fields
        SELECT
                                        *
                                    FROM
                                        [${flyway:defaultSchema}].[vwIssueNumberSequences]
                                    WHERE
                                        [ScopeCode] = @ScopeCode
                                    
END
GO

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueNumberSequence] TO [cdp_Developer], [cdp_Integration]
GO

------------------------------------------------------------
----- TRIGGER FOR __mj_UpdatedAt field for the IssueNumberSequence table
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[trgUpdateIssueNumberSequence]', 'TR') IS NOT NULL
    DROP TRIGGER [${flyway:defaultSchema}].[trgUpdateIssueNumberSequence];
GO
CREATE TRIGGER [${flyway:defaultSchema}].trgUpdateIssueNumberSequence
ON [${flyway:defaultSchema}].[IssueNumberSequence]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueNumberSequence]
    SET
        __mj_UpdatedAt = GETUTCDATE()
    FROM
        [${flyway:defaultSchema}].[IssueNumberSequence] AS _organicTable
    INNER JOIN
        INSERTED AS I ON
        _organicTable.[ScopeCode] = I.[ScopeCode];
END;
GO

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Number Sequences */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueNumberSequence] TO [cdp_Developer], [cdp_Integration];

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

/* spDelete SQL for MJ_BizApps_Issues: Issue Number Sequences */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Number Sequences
-- Item: spDeleteIssueNumberSequence
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueNumberSequence
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spDeleteIssueNumberSequence]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueNumberSequence];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueNumberSequence]
    @ScopeCode nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM
        [${flyway:defaultSchema}].[IssueNumberSequence]
    WHERE
        [ScopeCode] = @ScopeCode


    -- Check if the delete was successful
    IF @@ROWCOUNT = 0
        SELECT NULL AS [ScopeCode] -- Return NULL for all primary key fields to indicate no record was deleted
    ELSE
        SELECT @ScopeCode AS [ScopeCode] -- Return the primary key values to indicate we successfully deleted the record
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueNumberSequence] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issue Number Sequences */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueNumberSequence] TO [cdp_Developer], [cdp_Integration];

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

/* SQL text to update entity field related entity name field map for entity field ID 86B9EC44-D8DA-4540-9638-DB50F4D92BC4 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='86B9EC44-D8DA-4540-9638-DB50F4D92BC4', @RelatedEntityNameFieldMap='OnCreateAction';

/* SQL text to update entity field related entity name field map for entity field ID 7D858A44-3534-468D-9E48-BE4C8DC93052 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='7D858A44-3534-468D-9E48-BE4C8DC93052', @RelatedEntityNameFieldMap='OnStatusChangeAction';

/* SQL text to update entity field related entity name field map for entity field ID 2963D2BC-0473-47A0-BE0A-0E1BD925928B */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='2963D2BC-0473-47A0-BE0A-0E1BD925928B', @RelatedEntityNameFieldMap='Status';

/* SQL text to update entity field related entity name field map for entity field ID AE7027E2-994B-45EC-9F35-220A7664AB85 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='AE7027E2-994B-45EC-9F35-220A7664AB85', @RelatedEntityNameFieldMap='OnAssignAction';

/* SQL text to update entity field related entity name field map for entity field ID 06ED94D8-4607-4061-888E-788FFAFCA023 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='06ED94D8-4607-4061-888E-788FFAFCA023', @RelatedEntityNameFieldMap='ReporterPerson';

/* SQL text to update entity field related entity name field map for entity field ID 5D649C62-6589-43F0-AFFD-E3F9E3268CC8 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='5D649C62-6589-43F0-AFFD-E3F9E3268CC8', @RelatedEntityNameFieldMap='AssigneeEntity';

/* SQL text to update entity field related entity name field map for entity field ID 569D75F7-F081-4BC2-8990-321B8B9D92B6 */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='569D75F7-F081-4BC2-8990-321B8B9D92B6', @RelatedEntityNameFieldMap='OnCloseAction';

/* SQL text to update entity field related entity name field map for entity field ID 9D602C66-9FB5-4514-9ED6-7B530012AE3A */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='9D602C66-9FB5-4514-9ED6-7B530012AE3A', @RelatedEntityNameFieldMap='SourceEntity';

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

/* SQL text to update entity field related entity name field map for entity field ID 2BDFB21A-BAF7-482D-98C5-4DFD03FF45EE */
EXEC [${mjSchema}].[spUpdateEntityFieldRelatedEntityNameFieldMap] @EntityFieldID='2BDFB21A-BAF7-482D-98C5-4DFD03FF45EE', @RelatedEntityNameFieldMap='CreatedByPerson';

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
    @IssueNumber_Clear bit = 0,
    @IssueNumber nvarchar(50) = NULL,
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
                [IssueNumber],
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
                CASE WHEN @IssueNumber_Clear = 1 THEN NULL ELSE ISNULL(@IssueNumber, NULL) END,
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
                [IssueNumber],
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
                CASE WHEN @IssueNumber_Clear = 1 THEN NULL ELSE ISNULL(@IssueNumber, NULL) END,
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
    @IssueNumber_Clear bit = 0,
    @IssueNumber nvarchar(50) = NULL,
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
        [IssueNumber] = CASE WHEN @IssueNumber_Clear = 1 THEN NULL ELSE ISNULL(@IssueNumber, [IssueNumber]) END,
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

/* SQL text to delete unneeded entity fields (5 scoped entities) */
EXEC [${mjSchema}].[spDeleteUnneededEntityFields] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks', @EntityIDs='B08FB976-CC72-4DAC-B950-A5C86DD04267,07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4,65E7DAD5-9930-4140-9A38-2184EB0097DA,7124A46D-EA35-4C8B-BBBB-F19287ED0F9B,595E3981-EE66-4B41-8579-2255A0C7610C';

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'a0e546ec-bea3-46e0-b5e9-21c9f6a31ae3' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'IssueType')) BEGIN
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
            'a0e546ec-bea3-46e0-b5e9-21c9f6a31ae3',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100041,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9111e30e-76a3-4582-ac5c-06a7b9ac530e' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'Status')) BEGIN
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
            '9111e30e-76a3-4582-ac5c-06a7b9ac530e',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100042,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5b543630-4c16-4034-99de-1c4420a9cbd2' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'ReporterPerson')) BEGIN
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
            '5b543630-4c16-4034-99de-1c4420a9cbd2',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100043,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '00d07775-578d-4f35-86b6-136b9256fc30' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'AssigneeEntity')) BEGIN
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
            '00d07775-578d-4f35-86b6-136b9256fc30',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100044,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'd0d423b1-0148-4920-a657-5756b13364b6' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'SourceEntity')) BEGIN
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
            'd0d423b1-0148-4920-a657-5756b13364b6',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100045,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '7d7c497f-a10e-4ea5-8daf-50095c9fb635' OR (EntityID = '65E7DAD5-9930-4140-9A38-2184EB0097DA' AND Name = 'CreatedByPerson')) BEGIN
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
            '7d7c497f-a10e-4ea5-8daf-50095c9fb635',
            '65E7DAD5-9930-4140-9A38-2184EB0097DA', -- Entity: MJ_BizApps_Issues: Issues
            100046,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '9ce5a5b6-b87a-47cf-9ffc-34c433780eed' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'DefaultTaskType')) BEGIN
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
            '9ce5a5b6-b87a-47cf-9ffc-34c433780eed',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'c8533e9d-5b23-49b4-9789-3f645f4573e4' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnCreateAction')) BEGIN
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
            'c8533e9d-5b23-49b4-9789-3f645f4573e4',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '20b735b3-ec6a-4c5f-9027-2be6d96d9045' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnStatusChangeAction')) BEGIN
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
            '20b735b3-ec6a-4c5f-9027-2be6d96d9045',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'b82a5655-b11c-4ead-b7c0-cf61786a4101' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnAssignAction')) BEGIN
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
            'b82a5655-b11c-4ead-b7c0-cf61786a4101',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'b62c4ae2-1148-402c-accc-a4dc7354ddc0' OR (EntityID = 'B08FB976-CC72-4DAC-B950-A5C86DD04267' AND Name = 'OnCloseAction')) BEGIN
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
            'b62c4ae2-1148-402c-accc-a4dc7354ddc0',
            'B08FB976-CC72-4DAC-B950-A5C86DD04267', -- Entity: MJ_BizApps_Issues: Issue Types
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

/* SQL text to insert new entity field */

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'f85bce40-59bb-42d8-8bb6-971c6479ba73' OR (EntityID = '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B' AND Name = 'AuthorPerson')) BEGIN
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
            'f85bce40-59bb-42d8-8bb6-971c6479ba73',
            '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B', -- Entity: MJ_BizApps_Issues: Issue Comments
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

/* SQL text to update existing entity fields from schema (5 scoped entities) */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks', @EntityIDs='B08FB976-CC72-4DAC-B950-A5C86DD04267,07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4,65E7DAD5-9930-4140-9A38-2184EB0097DA,7124A46D-EA35-4C8B-BBBB-F19287ED0F9B,595E3981-EE66-4B41-8579-2255A0C7610C';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

