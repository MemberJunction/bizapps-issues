import { Assert, IntegrationCheckRegistry, type IntegrationCheckContext, type NamedCheck } from '@memberjunction/testing-integration/registry';
import { LoadWorld } from '../world/load-world.js';

const checks: NamedCheck[] = [
    {
        Id: 'issue-world.IW1',
        Name: 'IW1 — ISSUE-WORLD loads over GraphQL; types from metadata',
        RequiresMutation: true,
        Fn: async (ctx: IntegrationCheckContext) => {
            const world = await LoadWorld(ctx);
            Assert(Object.keys(world.Types).length > 0, 'issue types');
            Assert(Object.keys(world.Statuses).length > 0, 'issue statuses');
            Assert(Object.keys(world.SeedIssueIDs).length === 3, 'three seed issues');
        },
    },
];
for (const c of checks) IntegrationCheckRegistry.Instance.Register(c);
IntegrationCheckRegistry.Instance.RegisterLifecycle('issue-world', { Setup: async () => {}, Teardown: async () => {} });
