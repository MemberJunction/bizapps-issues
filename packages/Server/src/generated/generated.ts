/********************************************************************************
* ALL ENTITIES - TypeGraphQL Type Class Definition - AUTO GENERATED FILE
* Generated Entities and Resolvers for Server
*
*   >>> DO NOT MODIFY THIS FILE!!!!!!!!!!!!
*   >>> YOUR CHANGES WILL BE OVERWRITTEN
*   >>> THE NEXT TIME THIS FILE IS GENERATED
*
**********************************************************************************/
import { Arg, Ctx, Int, Query, Resolver, Field, Float, ObjectType, FieldResolver, Root, InputType, Mutation,
            PubSub, PubSubEngine, ResolverBase, RunViewByIDInput, RunViewByNameInput, RunDynamicViewInput,
            AppContext, KeyValuePairInput, DeleteOptionsInput, GraphQLTimestamp as Timestamp,
            GetReadOnlyProvider, GetReadWriteProvider, RestoreContextInput } from '@memberjunction/server';
import { Metadata, EntityPermissionType, CompositeKey, UserInfo } from '@memberjunction/core'

import { MaxLength } from 'class-validator';
import * as mj_core_schema_server_object_types from '@memberjunction/server'


import { mjBizAppsIssuesIssueCommentEntity, mjBizAppsIssuesIssueNumberSequenceEntity, mjBizAppsIssuesIssueStatusEntity, mjBizAppsIssuesIssueTypeEntity, mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';
    

//****************************************************************************
// ENTITY CLASS for MJ_BizApps_Issues: Issue Comments
//****************************************************************************
@ObjectType({ description: `Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.` })
export class mjBizAppsIssuesIssueComment_ {
    @Field({description: `Unique identifier (UUID).`}) 
    @MaxLength(36)
    ID: string;
        
    @Field({description: `The Issue this comment belongs to.`}) 
    @MaxLength(36)
    IssueID: string;
        
    @Field({description: `Comment body (Markdown or plain text).`}) 
    Body: string;
        
    @Field({nullable: true, description: `The Person who authored the comment, when internal. NULL for email/external authors (use AuthorEmail).`}) 
    @MaxLength(36)
    AuthorPersonID?: string;
        
    @Field({nullable: true, description: `Email of the comment author, used when there is no linked Person.`}) 
    @MaxLength(320)
    AuthorEmail?: string;
        
    @Field({description: `Origin of the comment: 'internal' (in-app), 'email' (email reply), or 'external' (reserved for v1.1 provider sync).`}) 
    @MaxLength(20)
    Source: string;
        
    @Field() 
    _mj__CreatedAt: Date;
        
    @Field() 
    _mj__UpdatedAt: Date;
        
    @Field({nullable: true}) 
    @MaxLength(201)
    AuthorPerson?: string;
        
}

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Comments
//****************************************************************************
@InputType()
export class CreatemjBizAppsIssuesIssueCommentInput {
    @Field({ nullable: true })
    ID?: string;

    @Field({ nullable: true })
    IssueID?: string;

    @Field({ nullable: true })
    Body?: string;

    @Field({ nullable: true })
    AuthorPersonID: string | null;

    @Field({ nullable: true })
    AuthorEmail: string | null;

    @Field({ nullable: true })
    Source?: string;

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Comments
//****************************************************************************
@InputType()
export class UpdatemjBizAppsIssuesIssueCommentInput {
    @Field()
    ID: string;

    @Field({ nullable: true })
    IssueID?: string;

    @Field({ nullable: true })
    Body?: string;

    @Field({ nullable: true })
    AuthorPersonID?: string | null;

    @Field({ nullable: true })
    AuthorEmail?: string | null;

    @Field({ nullable: true })
    Source?: string;

    @Field(() => [KeyValuePairInput], { nullable: true })
    OldValues___?: KeyValuePairInput[];

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    
//****************************************************************************
// RESOLVER for MJ_BizApps_Issues: Issue Comments
//****************************************************************************
@ObjectType()
export class RunmjBizAppsIssuesIssueCommentViewResult {
    @Field(() => [mjBizAppsIssuesIssueComment_])
    Results: mjBizAppsIssuesIssueComment_[];

    @Field(() => String, {nullable: true})
    UserViewRunID?: string;

    @Field(() => Int, {nullable: true})
    RowCount: number;

    @Field(() => Int, {nullable: true})
    TotalRowCount: number;

    @Field(() => Int, {nullable: true})
    ExecutionTime: number;

    @Field({nullable: true})
    ErrorMessage?: string;

    @Field(() => Boolean, {nullable: false})
    Success: boolean;
}

@Resolver(mjBizAppsIssuesIssueComment_)
export class mjBizAppsIssuesIssueCommentResolver extends ResolverBase {
    @Query(() => RunmjBizAppsIssuesIssueCommentViewResult)
    async RunmjBizAppsIssuesIssueCommentViewByID(@Arg('input', () => RunViewByIDInput) input: RunViewByIDInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByIDGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueCommentViewResult)
    async RunmjBizAppsIssuesIssueCommentViewByName(@Arg('input', () => RunViewByNameInput) input: RunViewByNameInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByNameGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueCommentViewResult)
    async RunmjBizAppsIssuesIssueCommentDynamicView(@Arg('input', () => RunDynamicViewInput) input: RunDynamicViewInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        input.EntityName = 'MJ_BizApps_Issues: Issue Comments';
        return super.RunDynamicViewGeneric(input, provider, userPayload, pubSub);
    }
    @Query(() => mjBizAppsIssuesIssueComment_, { nullable: true })
    async mjBizAppsIssuesIssueComment(@Arg('ID', () => String) ID: string, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine): Promise<mjBizAppsIssuesIssueComment_ | null> {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issue Comments', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssueComments')} WHERE ${provider.QuoteIdentifier('ID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issue Comments', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.MapFieldNamesToCodeNames('MJ_BizApps_Issues: Issue Comments', rows && rows.length > 0 ? rows[0] : null, this.GetUserFromPayload(userPayload));
        return result;
    }
    
    @Mutation(() => mjBizAppsIssuesIssueComment_)
    async CreatemjBizAppsIssuesIssueComment(
        @Arg('input', () => CreatemjBizAppsIssuesIssueCommentInput) input: CreatemjBizAppsIssuesIssueCommentInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.CreateRecord('MJ_BizApps_Issues: Issue Comments', input, provider, userPayload, pubSub)
    }
        
    @Mutation(() => mjBizAppsIssuesIssueComment_)
    async UpdatemjBizAppsIssuesIssueComment(
        @Arg('input', () => UpdatemjBizAppsIssuesIssueCommentInput) input: UpdatemjBizAppsIssuesIssueCommentInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.UpdateRecord('MJ_BizApps_Issues: Issue Comments', input, provider, userPayload, pubSub);
    }
    
    @Mutation(() => mjBizAppsIssuesIssueComment_)
    async DeletemjBizAppsIssuesIssueComment(@Arg('ID', () => String) ID: string, @Arg('options___', () => DeleteOptionsInput) options: DeleteOptionsInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadWriteProvider(providers);
        const key = new CompositeKey([{FieldName: 'ID', Value: ID}]);
        return this.DeleteRecord('MJ_BizApps_Issues: Issue Comments', key, options, provider, userPayload, pubSub);
    }
    
}

//****************************************************************************
// ENTITY CLASS for MJ_BizApps_Issues: Issue Number Sequences
//****************************************************************************
@ObjectType({ description: `Per-scope gap-free counter backing the human-readable Issue.IssueNumber. One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.` })
export class mjBizAppsIssuesIssueNumberSequence_ {
    @Field({description: `The normalized (trim/UPPER) AppScope this counter is for, or 'ISS' when an issue has no AppScope. Primary key.`}) 
    @MaxLength(50)
    ScopeCode: string;
        
    @Field(() => Int, {description: `The next sequence value to assign for this scope. Incremented atomically (UPDLOCK/HOLDLOCK) by spAssignNextIssueNumber.`}) 
    NextSequenceNumber: number;
        
    @Field() 
    _mj__CreatedAt: Date;
        
    @Field() 
    _mj__UpdatedAt: Date;
        
}

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Number Sequences
//****************************************************************************
@InputType()
export class CreatemjBizAppsIssuesIssueNumberSequenceInput {
    @Field({ nullable: true })
    ScopeCode?: string;

    @Field(() => Int, { nullable: true })
    NextSequenceNumber?: number;

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Number Sequences
//****************************************************************************
@InputType()
export class UpdatemjBizAppsIssuesIssueNumberSequenceInput {
    @Field()
    ScopeCode: string;

    @Field(() => Int, { nullable: true })
    NextSequenceNumber?: number;

    @Field(() => [KeyValuePairInput], { nullable: true })
    OldValues___?: KeyValuePairInput[];

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    
//****************************************************************************
// RESOLVER for MJ_BizApps_Issues: Issue Number Sequences
//****************************************************************************
@ObjectType()
export class RunmjBizAppsIssuesIssueNumberSequenceViewResult {
    @Field(() => [mjBizAppsIssuesIssueNumberSequence_])
    Results: mjBizAppsIssuesIssueNumberSequence_[];

    @Field(() => String, {nullable: true})
    UserViewRunID?: string;

    @Field(() => Int, {nullable: true})
    RowCount: number;

    @Field(() => Int, {nullable: true})
    TotalRowCount: number;

    @Field(() => Int, {nullable: true})
    ExecutionTime: number;

    @Field({nullable: true})
    ErrorMessage?: string;

    @Field(() => Boolean, {nullable: false})
    Success: boolean;
}

@Resolver(mjBizAppsIssuesIssueNumberSequence_)
export class mjBizAppsIssuesIssueNumberSequenceResolver extends ResolverBase {
    @Query(() => RunmjBizAppsIssuesIssueNumberSequenceViewResult)
    async RunmjBizAppsIssuesIssueNumberSequenceViewByID(@Arg('input', () => RunViewByIDInput) input: RunViewByIDInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByIDGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueNumberSequenceViewResult)
    async RunmjBizAppsIssuesIssueNumberSequenceViewByName(@Arg('input', () => RunViewByNameInput) input: RunViewByNameInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByNameGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueNumberSequenceViewResult)
    async RunmjBizAppsIssuesIssueNumberSequenceDynamicView(@Arg('input', () => RunDynamicViewInput) input: RunDynamicViewInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        input.EntityName = 'MJ_BizApps_Issues: Issue Number Sequences';
        return super.RunDynamicViewGeneric(input, provider, userPayload, pubSub);
    }
    @Query(() => mjBizAppsIssuesIssueNumberSequence_, { nullable: true })
    async mjBizAppsIssuesIssueNumberSequence(@Arg('ScopeCode', () => String) ScopeCode: string, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine): Promise<mjBizAppsIssuesIssueNumberSequence_ | null> {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issue Number Sequences', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssueNumberSequences')} WHERE ${provider.QuoteIdentifier('ScopeCode')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issue Number Sequences', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [ScopeCode], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.MapFieldNamesToCodeNames('MJ_BizApps_Issues: Issue Number Sequences', rows && rows.length > 0 ? rows[0] : null, this.GetUserFromPayload(userPayload));
        return result;
    }
    
    @Mutation(() => mjBizAppsIssuesIssueNumberSequence_)
    async CreatemjBizAppsIssuesIssueNumberSequence(
        @Arg('input', () => CreatemjBizAppsIssuesIssueNumberSequenceInput) input: CreatemjBizAppsIssuesIssueNumberSequenceInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.CreateRecord('MJ_BizApps_Issues: Issue Number Sequences', input, provider, userPayload, pubSub)
    }
        
    @Mutation(() => mjBizAppsIssuesIssueNumberSequence_)
    async UpdatemjBizAppsIssuesIssueNumberSequence(
        @Arg('input', () => UpdatemjBizAppsIssuesIssueNumberSequenceInput) input: UpdatemjBizAppsIssuesIssueNumberSequenceInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.UpdateRecord('MJ_BizApps_Issues: Issue Number Sequences', input, provider, userPayload, pubSub);
    }
    
    @Mutation(() => mjBizAppsIssuesIssueNumberSequence_)
    async DeletemjBizAppsIssuesIssueNumberSequence(@Arg('ScopeCode', () => String) ScopeCode: string, @Arg('options___', () => DeleteOptionsInput) options: DeleteOptionsInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadWriteProvider(providers);
        const key = new CompositeKey([{FieldName: 'ScopeCode', Value: ScopeCode}]);
        return this.DeleteRecord('MJ_BizApps_Issues: Issue Number Sequences', key, options, provider, userPayload, pubSub);
    }
    
}

//****************************************************************************
// ENTITY CLASS for MJ_BizApps_Issues: Issue Status
//****************************************************************************
@ObjectType({ description: `Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.` })
export class mjBizAppsIssuesIssueStatus_ {
    @Field({description: `Unique identifier (UUID).`}) 
    @MaxLength(36)
    ID: string;
        
    @Field({description: `Display name of the status (unique). E.g. 'In Progress', 'Resolved'.`}) 
    @MaxLength(100)
    Name: string;
        
    @Field({nullable: true, description: `Detailed description of what this status means in the workflow.`}) 
    Description?: string;
        
    @Field(() => Int, {description: `Sort order of the status on boards and in dropdowns. Lower values appear first.`}) 
    Sequence: number;
        
    @Field(() => Boolean, {description: `Whether new issues default to this status. Exactly one status should have this set.`}) 
    IsDefault: boolean;
        
    @Field(() => Boolean, {description: `Whether this is a terminal (end) state such as Closed or Won't Fix. Terminal statuses stop SLA timers and remove the issue from active queues.`}) 
    IsTerminal: boolean;
        
    @Field({nullable: true, description: `Hex (or token) color used to render this status as a chip / board column header.`}) 
    @MaxLength(20)
    ColorCode?: string;
        
    @Field() 
    _mj__CreatedAt: Date;
        
    @Field() 
    _mj__UpdatedAt: Date;
        
    @Field(() => Boolean, {description: `Whether this is the resolved-but-not-closed state (e.g. Resolved). Entering an IsResolved status stamps Issue.ResolvedAt. Distinct from IsTerminal: an issue can be resolved while still open for confirmation before it is closed.`}) 
    IsResolved: boolean;
        
    @Field(() => [mjBizAppsIssuesIssue_])
    mjBizAppsIssuesMJ_BizApps_Issues_Issues_StatusIDArray: mjBizAppsIssuesIssue_[]; // Link to mjBizAppsIssuesMJ_BizApps_Issues_Issues
    
}

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Status
//****************************************************************************
@InputType()
export class CreatemjBizAppsIssuesIssueStatusInput {
    @Field({ nullable: true })
    ID?: string;

    @Field({ nullable: true })
    Name?: string;

    @Field({ nullable: true })
    Description: string | null;

    @Field(() => Int, { nullable: true })
    Sequence?: number;

    @Field(() => Boolean, { nullable: true })
    IsDefault?: boolean;

    @Field(() => Boolean, { nullable: true })
    IsTerminal?: boolean;

    @Field({ nullable: true })
    ColorCode: string | null;

    @Field(() => Boolean, { nullable: true })
    IsResolved?: boolean;

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Status
//****************************************************************************
@InputType()
export class UpdatemjBizAppsIssuesIssueStatusInput {
    @Field()
    ID: string;

    @Field({ nullable: true })
    Name?: string;

    @Field({ nullable: true })
    Description?: string | null;

    @Field(() => Int, { nullable: true })
    Sequence?: number;

    @Field(() => Boolean, { nullable: true })
    IsDefault?: boolean;

    @Field(() => Boolean, { nullable: true })
    IsTerminal?: boolean;

    @Field({ nullable: true })
    ColorCode?: string | null;

    @Field(() => Boolean, { nullable: true })
    IsResolved?: boolean;

    @Field(() => [KeyValuePairInput], { nullable: true })
    OldValues___?: KeyValuePairInput[];

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    
//****************************************************************************
// RESOLVER for MJ_BizApps_Issues: Issue Status
//****************************************************************************
@ObjectType()
export class RunmjBizAppsIssuesIssueStatusViewResult {
    @Field(() => [mjBizAppsIssuesIssueStatus_])
    Results: mjBizAppsIssuesIssueStatus_[];

    @Field(() => String, {nullable: true})
    UserViewRunID?: string;

    @Field(() => Int, {nullable: true})
    RowCount: number;

    @Field(() => Int, {nullable: true})
    TotalRowCount: number;

    @Field(() => Int, {nullable: true})
    ExecutionTime: number;

    @Field({nullable: true})
    ErrorMessage?: string;

    @Field(() => Boolean, {nullable: false})
    Success: boolean;
}

@Resolver(mjBizAppsIssuesIssueStatus_)
export class mjBizAppsIssuesIssueStatusResolver extends ResolverBase {
    @Query(() => RunmjBizAppsIssuesIssueStatusViewResult)
    async RunmjBizAppsIssuesIssueStatusViewByID(@Arg('input', () => RunViewByIDInput) input: RunViewByIDInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByIDGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueStatusViewResult)
    async RunmjBizAppsIssuesIssueStatusViewByName(@Arg('input', () => RunViewByNameInput) input: RunViewByNameInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByNameGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueStatusViewResult)
    async RunmjBizAppsIssuesIssueStatusDynamicView(@Arg('input', () => RunDynamicViewInput) input: RunDynamicViewInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        input.EntityName = 'MJ_BizApps_Issues: Issue Status';
        return super.RunDynamicViewGeneric(input, provider, userPayload, pubSub);
    }
    @Query(() => mjBizAppsIssuesIssueStatus_, { nullable: true })
    async mjBizAppsIssuesIssueStatus(@Arg('ID', () => String) ID: string, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine): Promise<mjBizAppsIssuesIssueStatus_ | null> {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issue Status', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssueStatus')} WHERE ${provider.QuoteIdentifier('ID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issue Status', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.MapFieldNamesToCodeNames('MJ_BizApps_Issues: Issue Status', rows && rows.length > 0 ? rows[0] : null, this.GetUserFromPayload(userPayload));
        return result;
    }
    
    @FieldResolver(() => [mjBizAppsIssuesIssue_])
    async mjBizAppsIssuesMJ_BizApps_Issues_Issues_StatusIDArray(@Root() mjbizappsissuesissuestatus_: mjBizAppsIssuesIssueStatus_, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine) {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issues', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssues')} WHERE ${provider.QuoteIdentifier('StatusID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issues', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [mjbizappsissuesissuestatus_.ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.ArrayMapFieldNamesToCodeNames('MJ_BizApps_Issues: Issues', rows, this.GetUserFromPayload(userPayload));
        return result;
    }
        
    @Mutation(() => mjBizAppsIssuesIssueStatus_)
    async CreatemjBizAppsIssuesIssueStatus(
        @Arg('input', () => CreatemjBizAppsIssuesIssueStatusInput) input: CreatemjBizAppsIssuesIssueStatusInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.CreateRecord('MJ_BizApps_Issues: Issue Status', input, provider, userPayload, pubSub)
    }
        
    @Mutation(() => mjBizAppsIssuesIssueStatus_)
    async UpdatemjBizAppsIssuesIssueStatus(
        @Arg('input', () => UpdatemjBizAppsIssuesIssueStatusInput) input: UpdatemjBizAppsIssuesIssueStatusInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.UpdateRecord('MJ_BizApps_Issues: Issue Status', input, provider, userPayload, pubSub);
    }
    
    @Mutation(() => mjBizAppsIssuesIssueStatus_)
    async DeletemjBizAppsIssuesIssueStatus(@Arg('ID', () => String) ID: string, @Arg('options___', () => DeleteOptionsInput) options: DeleteOptionsInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadWriteProvider(providers);
        const key = new CompositeKey([{FieldName: 'ID', Value: ID}]);
        return this.DeleteRecord('MJ_BizApps_Issues: Issue Status', key, options, provider, userPayload, pubSub);
    }
    
}

//****************************************************************************
// ENTITY CLASS for MJ_BizApps_Issues: Issue Types
//****************************************************************************
@ObjectType({ description: `Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core [Action] records fired at the matching lifecycle event.` })
export class mjBizAppsIssuesIssueType_ {
    @Field({description: `Unique identifier (UUID).`}) 
    @MaxLength(36)
    ID: string;
        
    @Field({description: `Display name of the issue type (unique). E.g. 'Bug', 'Feature Request'.`}) 
    @MaxLength(100)
    Name: string;
        
    @Field({nullable: true, description: `Detailed description of what this issue type represents and when to use it.`}) 
    Description?: string;
        
    @Field({nullable: true, description: `Font Awesome (or similar) icon class shown next to issues of this type in the UI.`}) 
    @MaxLength(100)
    IconClass?: string;
        
    @Field({description: `Priority assigned to new issues of this type when none is specified. One of Low, Medium, High, Critical.`}) 
    @MaxLength(20)
    DefaultPriority: string;
        
    @Field({nullable: true, description: `bizapps-tasks TaskType used when an Issue of this type spawns work via IssueWorkService. NULL = let the caller choose.`}) 
    @MaxLength(36)
    DefaultTaskTypeID?: string;
        
    @Field({nullable: true, description: `Action fired by IssueService when an Issue of this type is created.`}) 
    @MaxLength(36)
    OnCreateActionID?: string;
        
    @Field({nullable: true, description: `Action fired by IssueService when an Issue of this type changes status.`}) 
    @MaxLength(36)
    OnStatusChangeActionID?: string;
        
    @Field({nullable: true, description: `Action fired by IssueService when an Issue of this type is assigned.`}) 
    @MaxLength(36)
    OnAssignActionID?: string;
        
    @Field({nullable: true, description: `Action fired by IssueService when an Issue of this type is closed.`}) 
    @MaxLength(36)
    OnCloseActionID?: string;
        
    @Field(() => Boolean, {description: `Whether this issue type is available for new issues. Inactive types stay on historical issues but are hidden from selection.`}) 
    IsActive: boolean;
        
    @Field() 
    _mj__CreatedAt: Date;
        
    @Field() 
    _mj__UpdatedAt: Date;
        
    @Field({nullable: true}) 
    @MaxLength(100)
    DefaultTaskType?: string;
        
    @Field({nullable: true}) 
    @MaxLength(425)
    OnCreateAction?: string;
        
    @Field({nullable: true}) 
    @MaxLength(425)
    OnStatusChangeAction?: string;
        
    @Field({nullable: true}) 
    @MaxLength(425)
    OnAssignAction?: string;
        
    @Field({nullable: true}) 
    @MaxLength(425)
    OnCloseAction?: string;
        
    @Field(() => [mjBizAppsIssuesIssue_])
    mjBizAppsIssuesMJ_BizApps_Issues_Issues_IssueTypeIDArray: mjBizAppsIssuesIssue_[]; // Link to mjBizAppsIssuesMJ_BizApps_Issues_Issues
    
}

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Types
//****************************************************************************
@InputType()
export class CreatemjBizAppsIssuesIssueTypeInput {
    @Field({ nullable: true })
    ID?: string;

    @Field({ nullable: true })
    Name?: string;

    @Field({ nullable: true })
    Description: string | null;

    @Field({ nullable: true })
    IconClass: string | null;

    @Field({ nullable: true })
    DefaultPriority?: string;

    @Field({ nullable: true })
    DefaultTaskTypeID: string | null;

    @Field({ nullable: true })
    OnCreateActionID: string | null;

    @Field({ nullable: true })
    OnStatusChangeActionID: string | null;

    @Field({ nullable: true })
    OnAssignActionID: string | null;

    @Field({ nullable: true })
    OnCloseActionID: string | null;

    @Field(() => Boolean, { nullable: true })
    IsActive?: boolean;

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issue Types
//****************************************************************************
@InputType()
export class UpdatemjBizAppsIssuesIssueTypeInput {
    @Field()
    ID: string;

    @Field({ nullable: true })
    Name?: string;

    @Field({ nullable: true })
    Description?: string | null;

    @Field({ nullable: true })
    IconClass?: string | null;

    @Field({ nullable: true })
    DefaultPriority?: string;

    @Field({ nullable: true })
    DefaultTaskTypeID?: string | null;

    @Field({ nullable: true })
    OnCreateActionID?: string | null;

    @Field({ nullable: true })
    OnStatusChangeActionID?: string | null;

    @Field({ nullable: true })
    OnAssignActionID?: string | null;

    @Field({ nullable: true })
    OnCloseActionID?: string | null;

    @Field(() => Boolean, { nullable: true })
    IsActive?: boolean;

    @Field(() => [KeyValuePairInput], { nullable: true })
    OldValues___?: KeyValuePairInput[];

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    
//****************************************************************************
// RESOLVER for MJ_BizApps_Issues: Issue Types
//****************************************************************************
@ObjectType()
export class RunmjBizAppsIssuesIssueTypeViewResult {
    @Field(() => [mjBizAppsIssuesIssueType_])
    Results: mjBizAppsIssuesIssueType_[];

    @Field(() => String, {nullable: true})
    UserViewRunID?: string;

    @Field(() => Int, {nullable: true})
    RowCount: number;

    @Field(() => Int, {nullable: true})
    TotalRowCount: number;

    @Field(() => Int, {nullable: true})
    ExecutionTime: number;

    @Field({nullable: true})
    ErrorMessage?: string;

    @Field(() => Boolean, {nullable: false})
    Success: boolean;
}

@Resolver(mjBizAppsIssuesIssueType_)
export class mjBizAppsIssuesIssueTypeResolver extends ResolverBase {
    @Query(() => RunmjBizAppsIssuesIssueTypeViewResult)
    async RunmjBizAppsIssuesIssueTypeViewByID(@Arg('input', () => RunViewByIDInput) input: RunViewByIDInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByIDGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueTypeViewResult)
    async RunmjBizAppsIssuesIssueTypeViewByName(@Arg('input', () => RunViewByNameInput) input: RunViewByNameInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByNameGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueTypeViewResult)
    async RunmjBizAppsIssuesIssueTypeDynamicView(@Arg('input', () => RunDynamicViewInput) input: RunDynamicViewInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        input.EntityName = 'MJ_BizApps_Issues: Issue Types';
        return super.RunDynamicViewGeneric(input, provider, userPayload, pubSub);
    }
    @Query(() => mjBizAppsIssuesIssueType_, { nullable: true })
    async mjBizAppsIssuesIssueType(@Arg('ID', () => String) ID: string, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine): Promise<mjBizAppsIssuesIssueType_ | null> {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issue Types', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssueTypes')} WHERE ${provider.QuoteIdentifier('ID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issue Types', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.MapFieldNamesToCodeNames('MJ_BizApps_Issues: Issue Types', rows && rows.length > 0 ? rows[0] : null, this.GetUserFromPayload(userPayload));
        return result;
    }
    
    @FieldResolver(() => [mjBizAppsIssuesIssue_])
    async mjBizAppsIssuesMJ_BizApps_Issues_Issues_IssueTypeIDArray(@Root() mjbizappsissuesissuetype_: mjBizAppsIssuesIssueType_, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine) {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issues', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssues')} WHERE ${provider.QuoteIdentifier('IssueTypeID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issues', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [mjbizappsissuesissuetype_.ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.ArrayMapFieldNamesToCodeNames('MJ_BizApps_Issues: Issues', rows, this.GetUserFromPayload(userPayload));
        return result;
    }
        
    @Mutation(() => mjBizAppsIssuesIssueType_)
    async CreatemjBizAppsIssuesIssueType(
        @Arg('input', () => CreatemjBizAppsIssuesIssueTypeInput) input: CreatemjBizAppsIssuesIssueTypeInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.CreateRecord('MJ_BizApps_Issues: Issue Types', input, provider, userPayload, pubSub)
    }
        
    @Mutation(() => mjBizAppsIssuesIssueType_)
    async UpdatemjBizAppsIssuesIssueType(
        @Arg('input', () => UpdatemjBizAppsIssuesIssueTypeInput) input: UpdatemjBizAppsIssuesIssueTypeInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.UpdateRecord('MJ_BizApps_Issues: Issue Types', input, provider, userPayload, pubSub);
    }
    
    @Mutation(() => mjBizAppsIssuesIssueType_)
    async DeletemjBizAppsIssuesIssueType(@Arg('ID', () => String) ID: string, @Arg('options___', () => DeleteOptionsInput) options: DeleteOptionsInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadWriteProvider(providers);
        const key = new CompositeKey([{FieldName: 'ID', Value: ID}]);
        return this.DeleteRecord('MJ_BizApps_Issues: Issue Types', key, options, provider, userPayload, pubSub);
    }
    
}

//****************************************************************************
// ENTITY CLASS for MJ_BizApps_Issues: Issues
//****************************************************************************
@ObjectType({ description: `The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.` })
export class mjBizAppsIssuesIssue_ {
    @Field({description: `Unique identifier (UUID).`}) 
    @MaxLength(36)
    ID: string;
        
    @Field({nullable: true, description: `Human-readable case identifier, format {SCOPE}-{seq} (e.g. 'MJC-42'), where SCOPE is the normalized (trim/UPPER) AppScope or 'ISS' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.`}) 
    @MaxLength(50)
    IssueNumber?: string;
        
    @Field({description: `Short, one-line summary of the issue.`}) 
    @MaxLength(500)
    Title: string;
        
    @Field({nullable: true, description: `Full description / body of the issue (Markdown or plain text).`}) 
    Description?: string;
        
    @Field({description: `The IssueType classifying this issue. Drives lifecycle action hooks and the default spawned task type.`}) 
    @MaxLength(36)
    IssueTypeID: string;
        
    @Field({description: `Current workflow status of the issue.`}) 
    @MaxLength(36)
    StatusID: string;
        
    @Field({description: `Impact of the issue (how bad it is): Low, Medium, High, Critical. Distinct from Priority.`}) 
    @MaxLength(20)
    Severity: string;
        
    @Field({description: `Scheduling priority (how soon to address it): Low, Medium, High, Critical. Distinct from Severity.`}) 
    @MaxLength(20)
    Priority: string;
        
    @Field({nullable: true, description: `The Person who raised the issue, when known internally. NULL for external/anonymous reporters (use ReporterEmail).`}) 
    @MaxLength(36)
    ReporterPersonID?: string;
        
    @Field({nullable: true, description: `Email of the reporter, used when there is no linked Person (external feedback, email-in).`}) 
    @MaxLength(320)
    ReporterEmail?: string;
        
    @Field({nullable: true, description: `Polymorphic assignee: the core Entity of the assignee (e.g. a Person entity or an AI Agent entity). Paired with AssigneeRecordID.`}) 
    @MaxLength(36)
    AssigneeEntityID?: string;
        
    @Field({nullable: true, description: `Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.`}) 
    @MaxLength(450)
    AssigneeRecordID?: string;
        
    @Field({nullable: true, description: `Polymorphic source: the core Entity of the record this issue is about (what the feedback concerns). Paired with SourceRecordID.`}) 
    @MaxLength(36)
    SourceEntityID?: string;
        
    @Field({nullable: true, description: `Polymorphic source: the primary key (as string) of the source record within SourceEntityID.`}) 
    @MaxLength(450)
    SourceRecordID?: string;
        
    @Field({nullable: true, description: `Which app / product this issue belongs to (free-text scope tag, e.g. 'MJC', 'Explorer').`}) 
    @MaxLength(255)
    AppScope?: string;
        
    @Field({nullable: true, description: `Timestamp the issue was resolved (entered a resolved state). NULL while unresolved.`}) 
    ResolvedAt?: Date;
        
    @Field({nullable: true, description: `Timestamp the issue was closed (entered a terminal state). NULL while open.`}) 
    ClosedAt?: Date;
        
    @Field({nullable: true, description: `The Person who created the issue record in the system (may differ from the reporter).`}) 
    @MaxLength(36)
    CreatedByPersonID?: string;
        
    @Field() 
    _mj__CreatedAt: Date;
        
    @Field() 
    _mj__UpdatedAt: Date;
        
    @Field() 
    @MaxLength(100)
    IssueType: string;
        
    @Field() 
    @MaxLength(100)
    Status: string;
        
    @Field({nullable: true}) 
    @MaxLength(201)
    ReporterPerson?: string;
        
    @Field({nullable: true}) 
    @MaxLength(255)
    AssigneeEntity?: string;
        
    @Field({nullable: true}) 
    @MaxLength(255)
    SourceEntity?: string;
        
    @Field({nullable: true}) 
    @MaxLength(201)
    CreatedByPerson?: string;
        
    @Field(() => [mjBizAppsIssuesIssueComment_])
    mjBizAppsIssuesMJ_BizApps_Issues_IssueComments_IssueIDArray: mjBizAppsIssuesIssueComment_[]; // Link to mjBizAppsIssuesMJ_BizApps_Issues_IssueComments
    
}

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issues
//****************************************************************************
@InputType()
export class CreatemjBizAppsIssuesIssueInput {
    @Field({ nullable: true })
    ID?: string;

    @Field({ nullable: true })
    IssueNumber: string | null;

    @Field({ nullable: true })
    Title?: string;

    @Field({ nullable: true })
    Description: string | null;

    @Field({ nullable: true })
    IssueTypeID?: string;

    @Field({ nullable: true })
    StatusID?: string;

    @Field({ nullable: true })
    Severity?: string;

    @Field({ nullable: true })
    Priority?: string;

    @Field({ nullable: true })
    ReporterPersonID: string | null;

    @Field({ nullable: true })
    ReporterEmail: string | null;

    @Field({ nullable: true })
    AssigneeEntityID: string | null;

    @Field({ nullable: true })
    AssigneeRecordID: string | null;

    @Field({ nullable: true })
    SourceEntityID: string | null;

    @Field({ nullable: true })
    SourceRecordID: string | null;

    @Field({ nullable: true })
    AppScope: string | null;

    @Field({ nullable: true })
    ResolvedAt: Date | null;

    @Field({ nullable: true })
    ClosedAt: Date | null;

    @Field({ nullable: true })
    CreatedByPersonID: string | null;

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    

//****************************************************************************
// INPUT TYPE for MJ_BizApps_Issues: Issues
//****************************************************************************
@InputType()
export class UpdatemjBizAppsIssuesIssueInput {
    @Field()
    ID: string;

    @Field({ nullable: true })
    IssueNumber?: string | null;

    @Field({ nullable: true })
    Title?: string;

    @Field({ nullable: true })
    Description?: string | null;

    @Field({ nullable: true })
    IssueTypeID?: string;

    @Field({ nullable: true })
    StatusID?: string;

    @Field({ nullable: true })
    Severity?: string;

    @Field({ nullable: true })
    Priority?: string;

    @Field({ nullable: true })
    ReporterPersonID?: string | null;

    @Field({ nullable: true })
    ReporterEmail?: string | null;

    @Field({ nullable: true })
    AssigneeEntityID?: string | null;

    @Field({ nullable: true })
    AssigneeRecordID?: string | null;

    @Field({ nullable: true })
    SourceEntityID?: string | null;

    @Field({ nullable: true })
    SourceRecordID?: string | null;

    @Field({ nullable: true })
    AppScope?: string | null;

    @Field({ nullable: true })
    ResolvedAt?: Date | null;

    @Field({ nullable: true })
    ClosedAt?: Date | null;

    @Field({ nullable: true })
    CreatedByPersonID?: string | null;

    @Field(() => [KeyValuePairInput], { nullable: true })
    OldValues___?: KeyValuePairInput[];

    @Field(() => RestoreContextInput, { nullable: true })
    RestoreContext___?: RestoreContextInput;
}
    
//****************************************************************************
// RESOLVER for MJ_BizApps_Issues: Issues
//****************************************************************************
@ObjectType()
export class RunmjBizAppsIssuesIssueViewResult {
    @Field(() => [mjBizAppsIssuesIssue_])
    Results: mjBizAppsIssuesIssue_[];

    @Field(() => String, {nullable: true})
    UserViewRunID?: string;

    @Field(() => Int, {nullable: true})
    RowCount: number;

    @Field(() => Int, {nullable: true})
    TotalRowCount: number;

    @Field(() => Int, {nullable: true})
    ExecutionTime: number;

    @Field({nullable: true})
    ErrorMessage?: string;

    @Field(() => Boolean, {nullable: false})
    Success: boolean;
}

@Resolver(mjBizAppsIssuesIssue_)
export class mjBizAppsIssuesIssueResolver extends ResolverBase {
    @Query(() => RunmjBizAppsIssuesIssueViewResult)
    async RunmjBizAppsIssuesIssueViewByID(@Arg('input', () => RunViewByIDInput) input: RunViewByIDInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByIDGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueViewResult)
    async RunmjBizAppsIssuesIssueViewByName(@Arg('input', () => RunViewByNameInput) input: RunViewByNameInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        return super.RunViewByNameGeneric(input, provider, userPayload, pubSub);
    }

    @Query(() => RunmjBizAppsIssuesIssueViewResult)
    async RunmjBizAppsIssuesIssueDynamicView(@Arg('input', () => RunDynamicViewInput) input: RunDynamicViewInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        input.EntityName = 'MJ_BizApps_Issues: Issues';
        return super.RunDynamicViewGeneric(input, provider, userPayload, pubSub);
    }
    @Query(() => mjBizAppsIssuesIssue_, { nullable: true })
    async mjBizAppsIssuesIssue(@Arg('ID', () => String) ID: string, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine): Promise<mjBizAppsIssuesIssue_ | null> {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issues', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssues')} WHERE ${provider.QuoteIdentifier('ID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issues', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.MapFieldNamesToCodeNames('MJ_BizApps_Issues: Issues', rows && rows.length > 0 ? rows[0] : null, this.GetUserFromPayload(userPayload));
        return result;
    }
    
    @FieldResolver(() => [mjBizAppsIssuesIssueComment_])
    async mjBizAppsIssuesMJ_BizApps_Issues_IssueComments_IssueIDArray(@Root() mjbizappsissuesissue_: mjBizAppsIssuesIssue_, @Ctx() { userPayload, providers }: AppContext, @PubSub() pubSub: PubSubEngine) {
        this.CheckUserReadPermissions('MJ_BizApps_Issues: Issue Comments', userPayload);
        const provider = GetReadOnlyProvider(providers, { allowFallbackToReadWrite: true });
        const sSQL = `SELECT * FROM ${provider.QuoteSchemaAndView('__mj_BizAppsIssues', 'vwIssueComments')} WHERE ${provider.QuoteIdentifier('IssueID')}=${provider.BuildParameterPlaceholder(0)} ` + this.getRowLevelSecurityWhereClause(provider, 'MJ_BizApps_Issues: Issue Comments', userPayload, EntityPermissionType.Read, 'AND');
        const rows = await provider.ExecuteSQL(sSQL, [mjbizappsissuesissue_.ID], undefined, this.GetUserFromPayload(userPayload));
        const result = await this.ArrayMapFieldNamesToCodeNames('MJ_BizApps_Issues: Issue Comments', rows, this.GetUserFromPayload(userPayload));
        return result;
    }
        
    @Mutation(() => mjBizAppsIssuesIssue_)
    async CreatemjBizAppsIssuesIssue(
        @Arg('input', () => CreatemjBizAppsIssuesIssueInput) input: CreatemjBizAppsIssuesIssueInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.CreateRecord('MJ_BizApps_Issues: Issues', input, provider, userPayload, pubSub)
    }
        
    @Mutation(() => mjBizAppsIssuesIssue_)
    async UpdatemjBizAppsIssuesIssue(
        @Arg('input', () => UpdatemjBizAppsIssuesIssueInput) input: UpdatemjBizAppsIssuesIssueInput,
        @Ctx() { providers, userPayload }: AppContext,
        @PubSub() pubSub: PubSubEngine
    ) {
        const provider = GetReadWriteProvider(providers);
        return this.UpdateRecord('MJ_BizApps_Issues: Issues', input, provider, userPayload, pubSub);
    }
    
    @Mutation(() => mjBizAppsIssuesIssue_)
    async DeletemjBizAppsIssuesIssue(@Arg('ID', () => String) ID: string, @Arg('options___', () => DeleteOptionsInput) options: DeleteOptionsInput, @Ctx() { providers, userPayload }: AppContext, @PubSub() pubSub: PubSubEngine) {
        const provider = GetReadWriteProvider(providers);
        const key = new CompositeKey([{FieldName: 'ID', Value: ID}]);
        return this.DeleteRecord('MJ_BizApps_Issues: Issues', key, options, provider, userPayload, pubSub);
    }
    
}