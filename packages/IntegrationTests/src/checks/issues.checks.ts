import { Assert, AssertEqual, IntegrationCheckRegistry, type NamedCheck } from '@memberjunction/testing-integration/registry';
import { mjBizAppsIssuesIssueCommentEntity, mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';
import { ISSUE_COMMENT_ENTITY, ISSUE_ENTITY } from '../entity-names.js';
import { FindRows, RequireSave } from '../wire.js';
import { GetOrLoadWorld } from '../world/load-world.js';

const checks: NamedCheck[] = [
    {
        Id: 'issues.I1',
        Name: 'I1 — create, filter, and comment on an issue over GraphQL',
        RequiresMutation: true,
        Fn: async (ctx) => {
            const world = await GetOrLoadWorld(ctx);
            const title = `I1 wire ${Date.now()}`;
            const issue = await ctx.Provider.GetEntityObject<mjBizAppsIssuesIssueEntity>(ISSUE_ENTITY, ctx.User);
            issue.NewRecord();
            issue.Title = title;
            issue.IssueTypeID = Object.values(world.Types)[0];
            issue.StatusID = Object.values(world.Statuses)[0];
            issue.Severity = 'High';
            issue.Priority = 'Medium';
            issue.ReporterPersonID = world.ReporterID;
            await RequireSave(issue, 'I1 issue');
            Assert(!!issue.IssueNumber, 'IssueNumber assigned on insert');

            const found = await FindRows<{ ID: string; Title: string }>(ctx, ISSUE_ENTITY, `Title = '${title.replace(/'/g, "''")}'`, ['ID', 'Title']);
            AssertEqual(found.length, 1, 'issue visible');

            const comment = await ctx.Provider.GetEntityObject<mjBizAppsIssuesIssueCommentEntity>(ISSUE_COMMENT_ENTITY, ctx.User);
            comment.NewRecord();
            comment.IssueID = issue.ID;
            comment.Body = 'Seen on the wire.';
            comment.AuthorPersonID = world.ReporterID;
            await RequireSave(comment, 'I1 comment');
            const comments = await FindRows<{ ID: string }>(ctx, ISSUE_COMMENT_ENTITY, `IssueID = '${issue.ID}'`, ['ID']);
            AssertEqual(comments.length, 1, 'comment visible');
            Assert(await comment.Delete(), 'cleanup comment');
            Assert(await issue.Delete(), 'cleanup issue');
        },
    },
    {
        Id: 'issues.I2',
        Name: 'I2 — seed issues are queryable by reporter',
        RequiresMutation: true,
        Fn: async (ctx) => {
            const world = await GetOrLoadWorld(ctx);
            const rows = await FindRows<{ ID: string }>(ctx, ISSUE_ENTITY, `ReporterPersonID = '${world.ReporterID}'`, ['ID']);
            Assert(rows.length >= 3, 'reporter has seed issues');
        },
    },
];
for (const c of checks) IntegrationCheckRegistry.Instance.Register(c);
IntegrationCheckRegistry.Instance.RegisterLifecycle('issues', { Setup: async () => {}, Teardown: async () => {} });
