import { LoadGeneratedEntities as LoadCommon } from '@mj-biz-apps/common-entities';
import { LoadGeneratedEntities as LoadIssues } from '@mj-biz-apps/issues-entities';
LoadCommon();
LoadIssues();
export * from './entity-names.js';
export * from './wire.js';
export * from './world/load-world.js';
export * from './checks/issue-world.checks.js';
export * from './checks/issues.checks.js';
export function LoadIssuesIntegrationTests(): void {}
