import { BaseEntity, EntitySaveOptions, EntityDeleteOptions, CompositeKey, ValidationResult, ValidationErrorInfo, ValidationErrorType, Metadata, ProviderType, DatabaseProviderBase } from "@memberjunction/core";
import { RegisterClass } from "@memberjunction/global";
import { z } from "zod";

export const loadModule = () => {
  // no-op, only used to ensure this file is a valid module and to allow easy loading
}

     
 
/**
 * zod schema definition for the entity MJ_BizApps_Issues: Issue Comments
 */
export const mjBizAppsIssuesIssueCommentSchema = z.object({
    ID: z.string().describe(`
        * * Field Name: ID
        * * Display Name: ID
        * * SQL Data Type: uniqueidentifier
        * * Default Value: newsequentialid()
        * * Description: Unique identifier (UUID).`),
    IssueID: z.string().describe(`
        * * Field Name: IssueID
        * * Display Name: Issue ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Issues: Issues (vwIssues.ID)
        * * Description: The Issue this comment belongs to.`),
    Body: z.string().describe(`
        * * Field Name: Body
        * * Display Name: Body
        * * SQL Data Type: nvarchar(MAX)
        * * Description: Comment body (Markdown or plain text).`),
    AuthorPersonID: z.string().nullable().describe(`
        * * Field Name: AuthorPersonID
        * * Display Name: Author Person ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Common: People (vwPeople.ID)
        * * Description: The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).`),
    AuthorEmail: z.string().nullable().describe(`
        * * Field Name: AuthorEmail
        * * Display Name: Author Email
        * * SQL Data Type: nvarchar(320)
        * * Description: Email of the comment author, used when there is no linked Person.`),
    Source: z.union([z.literal('email'), z.literal('external'), z.literal('internal')]).describe(`
        * * Field Name: Source
        * * Display Name: Source
        * * SQL Data Type: nvarchar(20)
        * * Default Value: internal
    * * Value List Type: List
    * * Possible Values 
    *   * email
    *   * external
    *   * internal
        * * Description: Origin of the comment: 'internal' (in-app), 'email' (email reply), or 'external' (reserved for v1.1 provider sync).`),
    __mj_CreatedAt: z.date().describe(`
        * * Field Name: __mj_CreatedAt
        * * Display Name: Created At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    __mj_UpdatedAt: z.date().describe(`
        * * Field Name: __mj_UpdatedAt
        * * Display Name: Updated At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    AuthorPerson: z.string().nullable().describe(`
        * * Field Name: AuthorPerson
        * * Display Name: Author Person
        * * SQL Data Type: nvarchar(201)`),
});

export type mjBizAppsIssuesIssueCommentEntityType = z.infer<typeof mjBizAppsIssuesIssueCommentSchema>;

/**
 * zod schema definition for the entity MJ_BizApps_Issues: Issue Number Sequences
 */
export const mjBizAppsIssuesIssueNumberSequenceSchema = z.object({
    ScopeCode: z.string().describe(`
        * * Field Name: ScopeCode
        * * Display Name: Scope Code
        * * SQL Data Type: nvarchar(50)
        * * Description: The normalized (trim/UPPER) AppScope this counter is for, or 'ISS' when an issue has no AppScope. Primary key.`),
    NextSequenceNumber: z.number().describe(`
        * * Field Name: NextSequenceNumber
        * * Display Name: Next Sequence Number
        * * SQL Data Type: int
        * * Default Value: 1
        * * Description: The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.`),
    __mj_CreatedAt: z.date().describe(`
        * * Field Name: __mj_CreatedAt
        * * Display Name: Created At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    __mj_UpdatedAt: z.date().describe(`
        * * Field Name: __mj_UpdatedAt
        * * Display Name: Updated At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
});

export type mjBizAppsIssuesIssueNumberSequenceEntityType = z.infer<typeof mjBizAppsIssuesIssueNumberSequenceSchema>;

/**
 * zod schema definition for the entity MJ_BizApps_Issues: Issue Status
 */
export const mjBizAppsIssuesIssueStatusSchema = z.object({
    ID: z.string().describe(`
        * * Field Name: ID
        * * Display Name: ID
        * * SQL Data Type: uniqueidentifier
        * * Default Value: newsequentialid()
        * * Description: Unique identifier (UUID).`),
    Name: z.string().describe(`
        * * Field Name: Name
        * * Display Name: Name
        * * SQL Data Type: nvarchar(100)
        * * Description: Display name of the status (unique). E.g. 'In Progress', 'Resolved'.`),
    Description: z.string().nullable().describe(`
        * * Field Name: Description
        * * Display Name: Description
        * * SQL Data Type: nvarchar(MAX)
        * * Description: Detailed description of what this status means in the workflow.`),
    Sequence: z.number().describe(`
        * * Field Name: Sequence
        * * Display Name: Sequence
        * * SQL Data Type: int
        * * Default Value: 100
        * * Description: Sort order of the status on boards and in dropdowns. Lower values appear first.`),
    IsDefault: z.boolean().describe(`
        * * Field Name: IsDefault
        * * Display Name: Is Default
        * * SQL Data Type: bit
        * * Default Value: 0
        * * Description: Whether new issues default to this status. Exactly one status should have this set.`),
    IsTerminal: z.boolean().describe(`
        * * Field Name: IsTerminal
        * * Display Name: Is Terminal
        * * SQL Data Type: bit
        * * Default Value: 0
        * * Description: Whether this is a terminal (end) state such as Closed or Won't Fix. Terminal statuses stop SLA timers and remove the issue from active queues.`),
    ColorCode: z.string().nullable().describe(`
        * * Field Name: ColorCode
        * * Display Name: Color Code
        * * SQL Data Type: nvarchar(20)
        * * Description: Hex (or token) color used to render this status as a chip / board column header.`),
    __mj_CreatedAt: z.date().describe(`
        * * Field Name: __mj_CreatedAt
        * * Display Name: Created At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    __mj_UpdatedAt: z.date().describe(`
        * * Field Name: __mj_UpdatedAt
        * * Display Name: Updated At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    IsResolved: z.boolean().describe(`
        * * Field Name: IsResolved
        * * Display Name: Is Resolved
        * * SQL Data Type: bit
        * * Default Value: 0
        * * Description: Whether this is the resolved-but-not-closed state (e.g. Resolved). Entering an IsResolved status stamps Issue.ResolvedAt. Distinct from IsTerminal: an issue can be resolved while still open for confirmation before it is closed.`),
});

export type mjBizAppsIssuesIssueStatusEntityType = z.infer<typeof mjBizAppsIssuesIssueStatusSchema>;

/**
 * zod schema definition for the entity MJ_BizApps_Issues: Issue Types
 */
export const mjBizAppsIssuesIssueTypeSchema = z.object({
    ID: z.string().describe(`
        * * Field Name: ID
        * * Display Name: ID
        * * SQL Data Type: uniqueidentifier
        * * Default Value: newsequentialid()
        * * Description: Unique identifier (UUID).`),
    Name: z.string().describe(`
        * * Field Name: Name
        * * Display Name: Name
        * * SQL Data Type: nvarchar(100)
        * * Description: Display name of the issue type (unique). E.g. 'Bug', 'Feature Request'.`),
    Description: z.string().nullable().describe(`
        * * Field Name: Description
        * * Display Name: Description
        * * SQL Data Type: nvarchar(MAX)
        * * Description: Detailed description of what this issue type represents and when to use it.`),
    IconClass: z.string().nullable().describe(`
        * * Field Name: IconClass
        * * Display Name: Icon Class
        * * SQL Data Type: nvarchar(100)
        * * Description: Font Awesome (or similar) icon class shown next to issues of this type in the UI.`),
    DefaultPriority: z.union([z.literal('Critical'), z.literal('High'), z.literal('Low'), z.literal('Medium')]).describe(`
        * * Field Name: DefaultPriority
        * * Display Name: Default Priority
        * * SQL Data Type: nvarchar(20)
        * * Default Value: Medium
    * * Value List Type: List
    * * Possible Values 
    *   * Critical
    *   * High
    *   * Low
    *   * Medium
        * * Description: Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.`),
    DefaultTaskTypeID: z.string().nullable().describe(`
        * * Field Name: DefaultTaskTypeID
        * * Display Name: Default Task Type ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Tasks: Task Types (vwTaskTypes.ID)
        * * Description: bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.`),
    OnCreateActionID: z.string().nullable().describe(`
        * * Field Name: OnCreateActionID
        * * Display Name: On Create Action ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
        * * Description: Action fired by IssueService when an Issue of this type is created.`),
    OnStatusChangeActionID: z.string().nullable().describe(`
        * * Field Name: OnStatusChangeActionID
        * * Display Name: On Status Change Action ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
        * * Description: Action fired by IssueService when an Issue of this type changes status.`),
    OnAssignActionID: z.string().nullable().describe(`
        * * Field Name: OnAssignActionID
        * * Display Name: On Assign Action ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
        * * Description: Action fired by IssueService when an Issue of this type is assigned.`),
    OnCloseActionID: z.string().nullable().describe(`
        * * Field Name: OnCloseActionID
        * * Display Name: On Close Action ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
        * * Description: Action fired by IssueService when an Issue of this type is closed.`),
    IsActive: z.boolean().describe(`
        * * Field Name: IsActive
        * * Display Name: Is Active
        * * SQL Data Type: bit
        * * Default Value: 1
        * * Description: Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.`),
    __mj_CreatedAt: z.date().describe(`
        * * Field Name: __mj_CreatedAt
        * * Display Name: Created At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    __mj_UpdatedAt: z.date().describe(`
        * * Field Name: __mj_UpdatedAt
        * * Display Name: Updated At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    DefaultTaskType: z.string().nullable().describe(`
        * * Field Name: DefaultTaskType
        * * Display Name: Default Task Type
        * * SQL Data Type: nvarchar(100)`),
    OnCreateAction: z.string().nullable().describe(`
        * * Field Name: OnCreateAction
        * * Display Name: On Create Action
        * * SQL Data Type: nvarchar(425)`),
    OnStatusChangeAction: z.string().nullable().describe(`
        * * Field Name: OnStatusChangeAction
        * * Display Name: On Status Change Action
        * * SQL Data Type: nvarchar(425)`),
    OnAssignAction: z.string().nullable().describe(`
        * * Field Name: OnAssignAction
        * * Display Name: On Assign Action
        * * SQL Data Type: nvarchar(425)`),
    OnCloseAction: z.string().nullable().describe(`
        * * Field Name: OnCloseAction
        * * Display Name: On Close Action
        * * SQL Data Type: nvarchar(425)`),
});

export type mjBizAppsIssuesIssueTypeEntityType = z.infer<typeof mjBizAppsIssuesIssueTypeSchema>;

/**
 * zod schema definition for the entity MJ_BizApps_Issues: Issues
 */
export const mjBizAppsIssuesIssueSchema = z.object({
    ID: z.string().describe(`
        * * Field Name: ID
        * * Display Name: ID
        * * SQL Data Type: uniqueidentifier
        * * Default Value: newsequentialid()
        * * Description: Unique identifier (UUID).`),
    IssueNumber: z.string().nullable().describe(`
        * * Field Name: IssueNumber
        * * Display Name: Issue Number
        * * SQL Data Type: nvarchar(50)
        * * Description: Human-readable case identifier, format {SCOPE}-{seq} (e.g. 'MJC-42'), where SCOPE is the normalized (trim/UPPER) AppScope or 'ISS' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.`),
    Title: z.string().describe(`
        * * Field Name: Title
        * * Display Name: Title
        * * SQL Data Type: nvarchar(500)
        * * Description: Short, one-line summary of the issue.`),
    Description: z.string().nullable().describe(`
        * * Field Name: Description
        * * Display Name: Description
        * * SQL Data Type: nvarchar(MAX)
        * * Description: Full description / body of the issue (Markdown or plain text).`),
    IssueTypeID: z.string().describe(`
        * * Field Name: IssueTypeID
        * * Display Name: Issue Type ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Issues: Issue Types (vwIssueTypes.ID)
        * * Description: The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.`),
    StatusID: z.string().describe(`
        * * Field Name: StatusID
        * * Display Name: Status ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Issues: Issue Status (vwIssueStatus.ID)
        * * Description: Current workflow status of the issue.`),
    Severity: z.union([z.literal('Critical'), z.literal('High'), z.literal('Low'), z.literal('Medium')]).describe(`
        * * Field Name: Severity
        * * Display Name: Severity
        * * SQL Data Type: nvarchar(20)
        * * Default Value: Medium
    * * Value List Type: List
    * * Possible Values 
    *   * Critical
    *   * High
    *   * Low
    *   * Medium
        * * Description: Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.`),
    Priority: z.union([z.literal('Critical'), z.literal('High'), z.literal('Low'), z.literal('Medium')]).describe(`
        * * Field Name: Priority
        * * Display Name: Priority
        * * SQL Data Type: nvarchar(20)
        * * Default Value: Medium
    * * Value List Type: List
    * * Possible Values 
    *   * Critical
    *   * High
    *   * Low
    *   * Medium
        * * Description: Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.`),
    ReporterPersonID: z.string().nullable().describe(`
        * * Field Name: ReporterPersonID
        * * Display Name: Reporter Person ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Common: People (vwPeople.ID)
        * * Description: The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).`),
    ReporterEmail: z.string().nullable().describe(`
        * * Field Name: ReporterEmail
        * * Display Name: Reporter Email
        * * SQL Data Type: nvarchar(320)
        * * Description: Email of the reporter, used when there is no linked Person (external feedback, email-in).`),
    AssigneeEntityID: z.string().nullable().describe(`
        * * Field Name: AssigneeEntityID
        * * Display Name: Assignee Entity ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ: Entities (vwEntities.ID)
        * * Description: Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.`),
    AssigneeRecordID: z.string().nullable().describe(`
        * * Field Name: AssigneeRecordID
        * * Display Name: Assignee Record ID
        * * SQL Data Type: nvarchar(450)
        * * Description: Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.`),
    SourceEntityID: z.string().nullable().describe(`
        * * Field Name: SourceEntityID
        * * Display Name: Source Entity ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ: Entities (vwEntities.ID)
        * * Description: Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.`),
    SourceRecordID: z.string().nullable().describe(`
        * * Field Name: SourceRecordID
        * * Display Name: Source Record ID
        * * SQL Data Type: nvarchar(450)
        * * Description: Polymorphic source: the primary key (as string) of the source record within SourceEntityID.`),
    AppScope: z.string().nullable().describe(`
        * * Field Name: AppScope
        * * Display Name: App Scope
        * * SQL Data Type: nvarchar(255)
        * * Description: Which app / product this issue belongs to (free-text scope tag, e.g. 'MJC', 'Explorer').`),
    ResolvedAt: z.date().nullable().describe(`
        * * Field Name: ResolvedAt
        * * Display Name: Resolved At
        * * SQL Data Type: datetimeoffset
        * * Description: Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.`),
    ClosedAt: z.date().nullable().describe(`
        * * Field Name: ClosedAt
        * * Display Name: Closed At
        * * SQL Data Type: datetimeoffset
        * * Description: Timestamp the issue was closed (entered a terminal state). NULL while open.`),
    CreatedByPersonID: z.string().nullable().describe(`
        * * Field Name: CreatedByPersonID
        * * Display Name: Created By Person ID
        * * SQL Data Type: uniqueidentifier
        * * Related Entity/Foreign Key: MJ_BizApps_Common: People (vwPeople.ID)
        * * Description: The Person who created the issue record in the system (may differ from the reporter).`),
    __mj_CreatedAt: z.date().describe(`
        * * Field Name: __mj_CreatedAt
        * * Display Name: Created At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    __mj_UpdatedAt: z.date().describe(`
        * * Field Name: __mj_UpdatedAt
        * * Display Name: Updated At
        * * SQL Data Type: datetimeoffset
        * * Default Value: getutcdate()`),
    IssueType: z.string().describe(`
        * * Field Name: IssueType
        * * Display Name: Issue Type
        * * SQL Data Type: nvarchar(100)`),
    Status: z.string().describe(`
        * * Field Name: Status
        * * Display Name: Status
        * * SQL Data Type: nvarchar(100)`),
    ReporterPerson: z.string().nullable().describe(`
        * * Field Name: ReporterPerson
        * * Display Name: Reporter Person
        * * SQL Data Type: nvarchar(201)`),
    AssigneeEntity: z.string().nullable().describe(`
        * * Field Name: AssigneeEntity
        * * Display Name: Assignee Entity
        * * SQL Data Type: nvarchar(255)`),
    SourceEntity: z.string().nullable().describe(`
        * * Field Name: SourceEntity
        * * Display Name: Source Entity
        * * SQL Data Type: nvarchar(255)`),
    CreatedByPerson: z.string().nullable().describe(`
        * * Field Name: CreatedByPerson
        * * Display Name: Created By Person
        * * SQL Data Type: nvarchar(201)`),
});

export type mjBizAppsIssuesIssueEntityType = z.infer<typeof mjBizAppsIssuesIssueSchema>;
 
 

/**
 * MJ_BizApps_Issues: Issue Comments - strongly typed entity sub-class
 * * Schema: __mj_BizAppsIssues
 * * Base Table: IssueComment
 * * Base View: vwIssueComments
 * * @description Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.
 * * Primary Key: ID
 * @extends {BaseEntity}
 * @class
 * @public
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issue Comments')
export class mjBizAppsIssuesIssueCommentEntity extends BaseEntity<mjBizAppsIssuesIssueCommentEntityType> {
    /**
    * Loads the MJ_BizApps_Issues: Issue Comments record from the database
    * @param ID: string - primary key value to load the MJ_BizApps_Issues: Issue Comments record.
    * @param EntityRelationshipsToLoad - (optional) the relationships to load
    * @returns {Promise<boolean>} - true if successful, false otherwise
    * @public
    * @async
    * @memberof mjBizAppsIssuesIssueCommentEntity
    * @method
    * @override
    */
    public async Load(ID: string, EntityRelationshipsToLoad?: string[]) : Promise<boolean> {
        const compositeKey: CompositeKey = new CompositeKey();
        compositeKey.KeyValuePairs.push({ FieldName: 'ID', Value: ID });
        return await super.InnerLoad(compositeKey, EntityRelationshipsToLoad);
    }

    /**
    * * Field Name: ID
    * * Display Name: ID
    * * SQL Data Type: uniqueidentifier
    * * Default Value: newsequentialid()
    * * Description: Unique identifier (UUID).
    */
    get ID(): string {
        return this.Get('ID');
    }
    set ID(value: string) {
        this.Set('ID', value);
    }

    /**
    * * Field Name: IssueID
    * * Display Name: Issue ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Issues: Issues (vwIssues.ID)
    * * Description: The Issue this comment belongs to.
    */
    get IssueID(): string {
        return this.Get('IssueID');
    }
    set IssueID(value: string) {
        this.Set('IssueID', value);
    }

    /**
    * * Field Name: Body
    * * Display Name: Body
    * * SQL Data Type: nvarchar(MAX)
    * * Description: Comment body (Markdown or plain text).
    */
    get Body(): string {
        return this.Get('Body');
    }
    set Body(value: string) {
        this.Set('Body', value);
    }

    /**
    * * Field Name: AuthorPersonID
    * * Display Name: Author Person ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Common: People (vwPeople.ID)
    * * Description: The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).
    */
    get AuthorPersonID(): string | null {
        return this.Get('AuthorPersonID');
    }
    set AuthorPersonID(value: string | null) {
        this.Set('AuthorPersonID', value);
    }

    /**
    * * Field Name: AuthorEmail
    * * Display Name: Author Email
    * * SQL Data Type: nvarchar(320)
    * * Description: Email of the comment author, used when there is no linked Person.
    */
    get AuthorEmail(): string | null {
        return this.Get('AuthorEmail');
    }
    set AuthorEmail(value: string | null) {
        this.Set('AuthorEmail', value);
    }

    /**
    * * Field Name: Source
    * * Display Name: Source
    * * SQL Data Type: nvarchar(20)
    * * Default Value: internal
    * * Value List Type: List
    * * Possible Values 
    *   * email
    *   * external
    *   * internal
    * * Description: Origin of the comment: 'internal' (in-app), 'email' (email reply), or 'external' (reserved for v1.1 provider sync).
    */
    get Source(): 'email' | 'external' | 'internal' {
        return this.Get('Source');
    }
    set Source(value: 'email' | 'external' | 'internal') {
        this.Set('Source', value);
    }

    /**
    * * Field Name: __mj_CreatedAt
    * * Display Name: Created At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_CreatedAt(): Date {
        return this.Get('__mj_CreatedAt');
    }

    /**
    * * Field Name: __mj_UpdatedAt
    * * Display Name: Updated At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_UpdatedAt(): Date {
        return this.Get('__mj_UpdatedAt');
    }

    /**
    * * Field Name: AuthorPerson
    * * Display Name: Author Person
    * * SQL Data Type: nvarchar(201)
    */
    get AuthorPerson(): string | null {
        return this.Get('AuthorPerson');
    }
}


/**
 * MJ_BizApps_Issues: Issue Number Sequences - strongly typed entity sub-class
 * * Schema: __mj_BizAppsIssues
 * * Base Table: IssueNumberSequence
 * * Base View: vwIssueNumberSequences
 * * @description Per-scope gap-free counter backing the human-readable Issue.IssueNumber. One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.
 * * Primary Key: ScopeCode
 * @extends {BaseEntity}
 * @class
 * @public
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issue Number Sequences')
export class mjBizAppsIssuesIssueNumberSequenceEntity extends BaseEntity<mjBizAppsIssuesIssueNumberSequenceEntityType> {
    /**
    * Loads the MJ_BizApps_Issues: Issue Number Sequences record from the database
    * @param ScopeCode: string - primary key value to load the MJ_BizApps_Issues: Issue Number Sequences record.
    * @param EntityRelationshipsToLoad - (optional) the relationships to load
    * @returns {Promise<boolean>} - true if successful, false otherwise
    * @public
    * @async
    * @memberof mjBizAppsIssuesIssueNumberSequenceEntity
    * @method
    * @override
    */
    public async Load(ScopeCode: string, EntityRelationshipsToLoad?: string[]) : Promise<boolean> {
        const compositeKey: CompositeKey = new CompositeKey();
        compositeKey.KeyValuePairs.push({ FieldName: 'ScopeCode', Value: ScopeCode });
        return await super.InnerLoad(compositeKey, EntityRelationshipsToLoad);
    }

    /**
    * * Field Name: ScopeCode
    * * Display Name: Scope Code
    * * SQL Data Type: nvarchar(50)
    * * Description: The normalized (trim/UPPER) AppScope this counter is for, or 'ISS' when an issue has no AppScope. Primary key.
    */
    get ScopeCode(): string {
        return this.Get('ScopeCode');
    }
    set ScopeCode(value: string) {
        this.Set('ScopeCode', value);
    }

    /**
    * * Field Name: NextSequenceNumber
    * * Display Name: Next Sequence Number
    * * SQL Data Type: int
    * * Default Value: 1
    * * Description: The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.
    */
    get NextSequenceNumber(): number {
        return this.Get('NextSequenceNumber');
    }
    set NextSequenceNumber(value: number) {
        this.Set('NextSequenceNumber', value);
    }

    /**
    * * Field Name: __mj_CreatedAt
    * * Display Name: Created At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_CreatedAt(): Date {
        return this.Get('__mj_CreatedAt');
    }

    /**
    * * Field Name: __mj_UpdatedAt
    * * Display Name: Updated At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_UpdatedAt(): Date {
        return this.Get('__mj_UpdatedAt');
    }
}


/**
 * MJ_BizApps_Issues: Issue Status - strongly typed entity sub-class
 * * Schema: __mj_BizAppsIssues
 * * Base Table: IssueStatus
 * * Base View: vwIssueStatus
 * * @description Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.
 * * Primary Key: ID
 * @extends {BaseEntity}
 * @class
 * @public
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issue Status')
export class mjBizAppsIssuesIssueStatusEntity extends BaseEntity<mjBizAppsIssuesIssueStatusEntityType> {
    /**
    * Loads the MJ_BizApps_Issues: Issue Status record from the database
    * @param ID: string - primary key value to load the MJ_BizApps_Issues: Issue Status record.
    * @param EntityRelationshipsToLoad - (optional) the relationships to load
    * @returns {Promise<boolean>} - true if successful, false otherwise
    * @public
    * @async
    * @memberof mjBizAppsIssuesIssueStatusEntity
    * @method
    * @override
    */
    public async Load(ID: string, EntityRelationshipsToLoad?: string[]) : Promise<boolean> {
        const compositeKey: CompositeKey = new CompositeKey();
        compositeKey.KeyValuePairs.push({ FieldName: 'ID', Value: ID });
        return await super.InnerLoad(compositeKey, EntityRelationshipsToLoad);
    }

    /**
    * * Field Name: ID
    * * Display Name: ID
    * * SQL Data Type: uniqueidentifier
    * * Default Value: newsequentialid()
    * * Description: Unique identifier (UUID).
    */
    get ID(): string {
        return this.Get('ID');
    }
    set ID(value: string) {
        this.Set('ID', value);
    }

    /**
    * * Field Name: Name
    * * Display Name: Name
    * * SQL Data Type: nvarchar(100)
    * * Description: Display name of the status (unique). E.g. 'In Progress', 'Resolved'.
    */
    get Name(): string {
        return this.Get('Name');
    }
    set Name(value: string) {
        this.Set('Name', value);
    }

    /**
    * * Field Name: Description
    * * Display Name: Description
    * * SQL Data Type: nvarchar(MAX)
    * * Description: Detailed description of what this status means in the workflow.
    */
    get Description(): string | null {
        return this.Get('Description');
    }
    set Description(value: string | null) {
        this.Set('Description', value);
    }

    /**
    * * Field Name: Sequence
    * * Display Name: Sequence
    * * SQL Data Type: int
    * * Default Value: 100
    * * Description: Sort order of the status on boards and in dropdowns. Lower values appear first.
    */
    get Sequence(): number {
        return this.Get('Sequence');
    }
    set Sequence(value: number) {
        this.Set('Sequence', value);
    }

    /**
    * * Field Name: IsDefault
    * * Display Name: Is Default
    * * SQL Data Type: bit
    * * Default Value: 0
    * * Description: Whether new issues default to this status. Exactly one status should have this set.
    */
    get IsDefault(): boolean {
        return this.Get('IsDefault');
    }
    set IsDefault(value: boolean) {
        this.Set('IsDefault', value);
    }

    /**
    * * Field Name: IsTerminal
    * * Display Name: Is Terminal
    * * SQL Data Type: bit
    * * Default Value: 0
    * * Description: Whether this is a terminal (end) state such as Closed or Won't Fix. Terminal statuses stop SLA timers and remove the issue from active queues.
    */
    get IsTerminal(): boolean {
        return this.Get('IsTerminal');
    }
    set IsTerminal(value: boolean) {
        this.Set('IsTerminal', value);
    }

    /**
    * * Field Name: ColorCode
    * * Display Name: Color Code
    * * SQL Data Type: nvarchar(20)
    * * Description: Hex (or token) color used to render this status as a chip / board column header.
    */
    get ColorCode(): string | null {
        return this.Get('ColorCode');
    }
    set ColorCode(value: string | null) {
        this.Set('ColorCode', value);
    }

    /**
    * * Field Name: __mj_CreatedAt
    * * Display Name: Created At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_CreatedAt(): Date {
        return this.Get('__mj_CreatedAt');
    }

    /**
    * * Field Name: __mj_UpdatedAt
    * * Display Name: Updated At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_UpdatedAt(): Date {
        return this.Get('__mj_UpdatedAt');
    }

    /**
    * * Field Name: IsResolved
    * * Display Name: Is Resolved
    * * SQL Data Type: bit
    * * Default Value: 0
    * * Description: Whether this is the resolved-but-not-closed state (e.g. Resolved). Entering an IsResolved status stamps Issue.ResolvedAt. Distinct from IsTerminal: an issue can be resolved while still open for confirmation before it is closed.
    */
    get IsResolved(): boolean {
        return this.Get('IsResolved');
    }
    set IsResolved(value: boolean) {
        this.Set('IsResolved', value);
    }
}


/**
 * MJ_BizApps_Issues: Issue Types - strongly typed entity sub-class
 * * Schema: __mj_BizAppsIssues
 * * Base Table: IssueType
 * * Base View: vwIssueTypes
 * * @description Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core [Action] records fired at the matching lifecycle event.
 * * Primary Key: ID
 * @extends {BaseEntity}
 * @class
 * @public
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issue Types')
export class mjBizAppsIssuesIssueTypeEntity extends BaseEntity<mjBizAppsIssuesIssueTypeEntityType> {
    /**
    * Loads the MJ_BizApps_Issues: Issue Types record from the database
    * @param ID: string - primary key value to load the MJ_BizApps_Issues: Issue Types record.
    * @param EntityRelationshipsToLoad - (optional) the relationships to load
    * @returns {Promise<boolean>} - true if successful, false otherwise
    * @public
    * @async
    * @memberof mjBizAppsIssuesIssueTypeEntity
    * @method
    * @override
    */
    public async Load(ID: string, EntityRelationshipsToLoad?: string[]) : Promise<boolean> {
        const compositeKey: CompositeKey = new CompositeKey();
        compositeKey.KeyValuePairs.push({ FieldName: 'ID', Value: ID });
        return await super.InnerLoad(compositeKey, EntityRelationshipsToLoad);
    }

    /**
    * * Field Name: ID
    * * Display Name: ID
    * * SQL Data Type: uniqueidentifier
    * * Default Value: newsequentialid()
    * * Description: Unique identifier (UUID).
    */
    get ID(): string {
        return this.Get('ID');
    }
    set ID(value: string) {
        this.Set('ID', value);
    }

    /**
    * * Field Name: Name
    * * Display Name: Name
    * * SQL Data Type: nvarchar(100)
    * * Description: Display name of the issue type (unique). E.g. 'Bug', 'Feature Request'.
    */
    get Name(): string {
        return this.Get('Name');
    }
    set Name(value: string) {
        this.Set('Name', value);
    }

    /**
    * * Field Name: Description
    * * Display Name: Description
    * * SQL Data Type: nvarchar(MAX)
    * * Description: Detailed description of what this issue type represents and when to use it.
    */
    get Description(): string | null {
        return this.Get('Description');
    }
    set Description(value: string | null) {
        this.Set('Description', value);
    }

    /**
    * * Field Name: IconClass
    * * Display Name: Icon Class
    * * SQL Data Type: nvarchar(100)
    * * Description: Font Awesome (or similar) icon class shown next to issues of this type in the UI.
    */
    get IconClass(): string | null {
        return this.Get('IconClass');
    }
    set IconClass(value: string | null) {
        this.Set('IconClass', value);
    }

    /**
    * * Field Name: DefaultPriority
    * * Display Name: Default Priority
    * * SQL Data Type: nvarchar(20)
    * * Default Value: Medium
    * * Value List Type: List
    * * Possible Values 
    *   * Critical
    *   * High
    *   * Low
    *   * Medium
    * * Description: Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.
    */
    get DefaultPriority(): 'Critical' | 'High' | 'Low' | 'Medium' {
        return this.Get('DefaultPriority');
    }
    set DefaultPriority(value: 'Critical' | 'High' | 'Low' | 'Medium') {
        this.Set('DefaultPriority', value);
    }

    /**
    * * Field Name: DefaultTaskTypeID
    * * Display Name: Default Task Type ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Tasks: Task Types (vwTaskTypes.ID)
    * * Description: bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.
    */
    get DefaultTaskTypeID(): string | null {
        return this.Get('DefaultTaskTypeID');
    }
    set DefaultTaskTypeID(value: string | null) {
        this.Set('DefaultTaskTypeID', value);
    }

    /**
    * * Field Name: OnCreateActionID
    * * Display Name: On Create Action ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
    * * Description: Action fired by IssueService when an Issue of this type is created.
    */
    get OnCreateActionID(): string | null {
        return this.Get('OnCreateActionID');
    }
    set OnCreateActionID(value: string | null) {
        this.Set('OnCreateActionID', value);
    }

    /**
    * * Field Name: OnStatusChangeActionID
    * * Display Name: On Status Change Action ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
    * * Description: Action fired by IssueService when an Issue of this type changes status.
    */
    get OnStatusChangeActionID(): string | null {
        return this.Get('OnStatusChangeActionID');
    }
    set OnStatusChangeActionID(value: string | null) {
        this.Set('OnStatusChangeActionID', value);
    }

    /**
    * * Field Name: OnAssignActionID
    * * Display Name: On Assign Action ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
    * * Description: Action fired by IssueService when an Issue of this type is assigned.
    */
    get OnAssignActionID(): string | null {
        return this.Get('OnAssignActionID');
    }
    set OnAssignActionID(value: string | null) {
        this.Set('OnAssignActionID', value);
    }

    /**
    * * Field Name: OnCloseActionID
    * * Display Name: On Close Action ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ: Actions (vwActions.ID)
    * * Description: Action fired by IssueService when an Issue of this type is closed.
    */
    get OnCloseActionID(): string | null {
        return this.Get('OnCloseActionID');
    }
    set OnCloseActionID(value: string | null) {
        this.Set('OnCloseActionID', value);
    }

    /**
    * * Field Name: IsActive
    * * Display Name: Is Active
    * * SQL Data Type: bit
    * * Default Value: 1
    * * Description: Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.
    */
    get IsActive(): boolean {
        return this.Get('IsActive');
    }
    set IsActive(value: boolean) {
        this.Set('IsActive', value);
    }

    /**
    * * Field Name: __mj_CreatedAt
    * * Display Name: Created At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_CreatedAt(): Date {
        return this.Get('__mj_CreatedAt');
    }

    /**
    * * Field Name: __mj_UpdatedAt
    * * Display Name: Updated At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_UpdatedAt(): Date {
        return this.Get('__mj_UpdatedAt');
    }

    /**
    * * Field Name: DefaultTaskType
    * * Display Name: Default Task Type
    * * SQL Data Type: nvarchar(100)
    */
    get DefaultTaskType(): string | null {
        return this.Get('DefaultTaskType');
    }

    /**
    * * Field Name: OnCreateAction
    * * Display Name: On Create Action
    * * SQL Data Type: nvarchar(425)
    */
    get OnCreateAction(): string | null {
        return this.Get('OnCreateAction');
    }

    /**
    * * Field Name: OnStatusChangeAction
    * * Display Name: On Status Change Action
    * * SQL Data Type: nvarchar(425)
    */
    get OnStatusChangeAction(): string | null {
        return this.Get('OnStatusChangeAction');
    }

    /**
    * * Field Name: OnAssignAction
    * * Display Name: On Assign Action
    * * SQL Data Type: nvarchar(425)
    */
    get OnAssignAction(): string | null {
        return this.Get('OnAssignAction');
    }

    /**
    * * Field Name: OnCloseAction
    * * Display Name: On Close Action
    * * SQL Data Type: nvarchar(425)
    */
    get OnCloseAction(): string | null {
        return this.Get('OnCloseAction');
    }
}


/**
 * MJ_BizApps_Issues: Issues - strongly typed entity sub-class
 * * Schema: __mj_BizAppsIssues
 * * Base Table: Issue
 * * Base View: vwIssues
 * * @description The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.
 * * Primary Key: ID
 * @extends {BaseEntity}
 * @class
 * @public
 */
@RegisterClass(BaseEntity, 'MJ_BizApps_Issues: Issues')
export class mjBizAppsIssuesIssueEntity extends BaseEntity<mjBizAppsIssuesIssueEntityType> {
    /**
    * Loads the MJ_BizApps_Issues: Issues record from the database
    * @param ID: string - primary key value to load the MJ_BizApps_Issues: Issues record.
    * @param EntityRelationshipsToLoad - (optional) the relationships to load
    * @returns {Promise<boolean>} - true if successful, false otherwise
    * @public
    * @async
    * @memberof mjBizAppsIssuesIssueEntity
    * @method
    * @override
    */
    public async Load(ID: string, EntityRelationshipsToLoad?: string[]) : Promise<boolean> {
        const compositeKey: CompositeKey = new CompositeKey();
        compositeKey.KeyValuePairs.push({ FieldName: 'ID', Value: ID });
        return await super.InnerLoad(compositeKey, EntityRelationshipsToLoad);
    }

    /**
    * * Field Name: ID
    * * Display Name: ID
    * * SQL Data Type: uniqueidentifier
    * * Default Value: newsequentialid()
    * * Description: Unique identifier (UUID).
    */
    get ID(): string {
        return this.Get('ID');
    }
    set ID(value: string) {
        this.Set('ID', value);
    }

    /**
    * * Field Name: IssueNumber
    * * Display Name: Issue Number
    * * SQL Data Type: nvarchar(50)
    * * Description: Human-readable case identifier, format {SCOPE}-{seq} (e.g. 'MJC-42'), where SCOPE is the normalized (trim/UPPER) AppScope or 'ISS' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.
    */
    get IssueNumber(): string | null {
        return this.Get('IssueNumber');
    }
    set IssueNumber(value: string | null) {
        this.Set('IssueNumber', value);
    }

    /**
    * * Field Name: Title
    * * Display Name: Title
    * * SQL Data Type: nvarchar(500)
    * * Description: Short, one-line summary of the issue.
    */
    get Title(): string {
        return this.Get('Title');
    }
    set Title(value: string) {
        this.Set('Title', value);
    }

    /**
    * * Field Name: Description
    * * Display Name: Description
    * * SQL Data Type: nvarchar(MAX)
    * * Description: Full description / body of the issue (Markdown or plain text).
    */
    get Description(): string | null {
        return this.Get('Description');
    }
    set Description(value: string | null) {
        this.Set('Description', value);
    }

    /**
    * * Field Name: IssueTypeID
    * * Display Name: Issue Type ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Issues: Issue Types (vwIssueTypes.ID)
    * * Description: The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.
    */
    get IssueTypeID(): string {
        return this.Get('IssueTypeID');
    }
    set IssueTypeID(value: string) {
        this.Set('IssueTypeID', value);
    }

    /**
    * * Field Name: StatusID
    * * Display Name: Status ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Issues: Issue Status (vwIssueStatus.ID)
    * * Description: Current workflow status of the issue.
    */
    get StatusID(): string {
        return this.Get('StatusID');
    }
    set StatusID(value: string) {
        this.Set('StatusID', value);
    }

    /**
    * * Field Name: Severity
    * * Display Name: Severity
    * * SQL Data Type: nvarchar(20)
    * * Default Value: Medium
    * * Value List Type: List
    * * Possible Values 
    *   * Critical
    *   * High
    *   * Low
    *   * Medium
    * * Description: Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.
    */
    get Severity(): 'Critical' | 'High' | 'Low' | 'Medium' {
        return this.Get('Severity');
    }
    set Severity(value: 'Critical' | 'High' | 'Low' | 'Medium') {
        this.Set('Severity', value);
    }

    /**
    * * Field Name: Priority
    * * Display Name: Priority
    * * SQL Data Type: nvarchar(20)
    * * Default Value: Medium
    * * Value List Type: List
    * * Possible Values 
    *   * Critical
    *   * High
    *   * Low
    *   * Medium
    * * Description: Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.
    */
    get Priority(): 'Critical' | 'High' | 'Low' | 'Medium' {
        return this.Get('Priority');
    }
    set Priority(value: 'Critical' | 'High' | 'Low' | 'Medium') {
        this.Set('Priority', value);
    }

    /**
    * * Field Name: ReporterPersonID
    * * Display Name: Reporter Person ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Common: People (vwPeople.ID)
    * * Description: The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).
    */
    get ReporterPersonID(): string | null {
        return this.Get('ReporterPersonID');
    }
    set ReporterPersonID(value: string | null) {
        this.Set('ReporterPersonID', value);
    }

    /**
    * * Field Name: ReporterEmail
    * * Display Name: Reporter Email
    * * SQL Data Type: nvarchar(320)
    * * Description: Email of the reporter, used when there is no linked Person (external feedback, email-in).
    */
    get ReporterEmail(): string | null {
        return this.Get('ReporterEmail');
    }
    set ReporterEmail(value: string | null) {
        this.Set('ReporterEmail', value);
    }

    /**
    * * Field Name: AssigneeEntityID
    * * Display Name: Assignee Entity ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ: Entities (vwEntities.ID)
    * * Description: Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.
    */
    get AssigneeEntityID(): string | null {
        return this.Get('AssigneeEntityID');
    }
    set AssigneeEntityID(value: string | null) {
        this.Set('AssigneeEntityID', value);
    }

    /**
    * * Field Name: AssigneeRecordID
    * * Display Name: Assignee Record ID
    * * SQL Data Type: nvarchar(450)
    * * Description: Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.
    */
    get AssigneeRecordID(): string | null {
        return this.Get('AssigneeRecordID');
    }
    set AssigneeRecordID(value: string | null) {
        this.Set('AssigneeRecordID', value);
    }

    /**
    * * Field Name: SourceEntityID
    * * Display Name: Source Entity ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ: Entities (vwEntities.ID)
    * * Description: Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.
    */
    get SourceEntityID(): string | null {
        return this.Get('SourceEntityID');
    }
    set SourceEntityID(value: string | null) {
        this.Set('SourceEntityID', value);
    }

    /**
    * * Field Name: SourceRecordID
    * * Display Name: Source Record ID
    * * SQL Data Type: nvarchar(450)
    * * Description: Polymorphic source: the primary key (as string) of the source record within SourceEntityID.
    */
    get SourceRecordID(): string | null {
        return this.Get('SourceRecordID');
    }
    set SourceRecordID(value: string | null) {
        this.Set('SourceRecordID', value);
    }

    /**
    * * Field Name: AppScope
    * * Display Name: App Scope
    * * SQL Data Type: nvarchar(255)
    * * Description: Which app / product this issue belongs to (free-text scope tag, e.g. 'MJC', 'Explorer').
    */
    get AppScope(): string | null {
        return this.Get('AppScope');
    }
    set AppScope(value: string | null) {
        this.Set('AppScope', value);
    }

    /**
    * * Field Name: ResolvedAt
    * * Display Name: Resolved At
    * * SQL Data Type: datetimeoffset
    * * Description: Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.
    */
    get ResolvedAt(): Date | null {
        return this.Get('ResolvedAt');
    }
    set ResolvedAt(value: Date | null) {
        this.Set('ResolvedAt', value);
    }

    /**
    * * Field Name: ClosedAt
    * * Display Name: Closed At
    * * SQL Data Type: datetimeoffset
    * * Description: Timestamp the issue was closed (entered a terminal state). NULL while open.
    */
    get ClosedAt(): Date | null {
        return this.Get('ClosedAt');
    }
    set ClosedAt(value: Date | null) {
        this.Set('ClosedAt', value);
    }

    /**
    * * Field Name: CreatedByPersonID
    * * Display Name: Created By Person ID
    * * SQL Data Type: uniqueidentifier
    * * Related Entity/Foreign Key: MJ_BizApps_Common: People (vwPeople.ID)
    * * Description: The Person who created the issue record in the system (may differ from the reporter).
    */
    get CreatedByPersonID(): string | null {
        return this.Get('CreatedByPersonID');
    }
    set CreatedByPersonID(value: string | null) {
        this.Set('CreatedByPersonID', value);
    }

    /**
    * * Field Name: __mj_CreatedAt
    * * Display Name: Created At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_CreatedAt(): Date {
        return this.Get('__mj_CreatedAt');
    }

    /**
    * * Field Name: __mj_UpdatedAt
    * * Display Name: Updated At
    * * SQL Data Type: datetimeoffset
    * * Default Value: getutcdate()
    */
    get __mj_UpdatedAt(): Date {
        return this.Get('__mj_UpdatedAt');
    }

    /**
    * * Field Name: IssueType
    * * Display Name: Issue Type
    * * SQL Data Type: nvarchar(100)
    */
    get IssueType(): string {
        return this.Get('IssueType');
    }

    /**
    * * Field Name: Status
    * * Display Name: Status
    * * SQL Data Type: nvarchar(100)
    */
    get Status(): string {
        return this.Get('Status');
    }

    /**
    * * Field Name: ReporterPerson
    * * Display Name: Reporter Person
    * * SQL Data Type: nvarchar(201)
    */
    get ReporterPerson(): string | null {
        return this.Get('ReporterPerson');
    }

    /**
    * * Field Name: AssigneeEntity
    * * Display Name: Assignee Entity
    * * SQL Data Type: nvarchar(255)
    */
    get AssigneeEntity(): string | null {
        return this.Get('AssigneeEntity');
    }

    /**
    * * Field Name: SourceEntity
    * * Display Name: Source Entity
    * * SQL Data Type: nvarchar(255)
    */
    get SourceEntity(): string | null {
        return this.Get('SourceEntity');
    }

    /**
    * * Field Name: CreatedByPerson
    * * Display Name: Created By Person
    * * SQL Data Type: nvarchar(201)
    */
    get CreatedByPerson(): string | null {
        return this.Get('CreatedByPerson');
    }
}
