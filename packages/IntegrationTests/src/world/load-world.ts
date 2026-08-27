import type { IntegrationCheckContext } from '@memberjunction/testing-integration/registry';
import { Assert } from '@memberjunction/testing-integration/registry';
import { mjBizAppsCommonPersonEntity } from '@mj-biz-apps/common-entities';
import { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';
import { ISSUE_ENTITY, ISSUE_STATUS_ENTITY, ISSUE_TYPE_ENTITY, PERSON_ENTITY, WORLD_DOMAIN } from '../entity-names.js';
import { FindId, FindRows, Quote, RequireSave } from '../wire.js';

export interface IssueWorld {
    Types: Record<string, string>;
    Statuses: Record<string, string>;
    ReporterID: string;
    SeedIssueIDs: Record<string, string>;
}

let current: IssueWorld | null = null;
export function World(): IssueWorld {
    if (!current) throw new Error('ISSUE-WORLD not loaded');
    return current;
}

export async function LoadWorld(ctx: IntegrationCheckContext): Promise<IssueWorld> {
    const types = await FindRows<{ ID: string; Name: string }>(ctx, ISSUE_TYPE_ENTITY, '', ['ID', 'Name']);
    const statuses = await FindRows<{ ID: string; Name: string }>(ctx, ISSUE_STATUS_ENTITY, '', ['ID', 'Name']);
    Assert(types.length > 0, 'no Issue Types — push metadata/issue-types');
    Assert(statuses.length > 0, 'no Issue Status — push metadata/issue-statuses');

    const Types: Record<string, string> = {};
    for (const t of types) Types[t.Name] = t.ID;
    const Statuses: Record<string, string> = {};
    for (const s of statuses) Statuses[s.Name] = s.ID;

    const email = `reporter@${WORLD_DOMAIN}`;
    const existingPerson = await FindId(ctx, PERSON_ENTITY, `Email = '${Quote(email)}'`);
    const person = await ctx.Provider.GetEntityObject<mjBizAppsCommonPersonEntity>(PERSON_ENTITY, ctx.User);
    if (existingPerson) await person.Load(existingPerson);
    else person.NewRecord();
    person.FirstName = 'Ivy';
    person.LastName = 'Reporter';
    person.Email = email;
    person.Status = 'Active';
    await RequireSave(person, 'reporter');

    const typeID = types[0].ID;
    const openStatus = Statuses['Open'] ?? Statuses['New'] ?? statuses[0].ID;
    const SeedIssueIDs: Record<string, string> = {};
    for (const title of ['Cannot print invoice', 'Login timeout on Safari', 'Membership card not scanning']) {
        const existing = await FindId(ctx, ISSUE_ENTITY, `Title = '${Quote(title)}'`);
        const issue = await ctx.Provider.GetEntityObject<mjBizAppsIssuesIssueEntity>(ISSUE_ENTITY, ctx.User);
        if (existing) await issue.Load(existing);
        else issue.NewRecord();
        issue.Title = title;
        issue.Description = `${title} — ISSUE-WORLD fixture`;
        issue.IssueTypeID = typeID;
        issue.StatusID = openStatus;
        issue.Severity = 'Medium';
        issue.Priority = 'High';
        issue.ReporterPersonID = person.ID;
        issue.ReporterEmail = email;
        await RequireSave(issue, `issue ${title}`);
        SeedIssueIDs[title] = issue.ID;
    }

    current = { Types, Statuses, ReporterID: person.ID, SeedIssueIDs };
    return current;
}

export async function GetOrLoadWorld(ctx: IntegrationCheckContext): Promise<IssueWorld> {
    return current ?? LoadWorld(ctx);
}
