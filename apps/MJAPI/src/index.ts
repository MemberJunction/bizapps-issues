/**
 * MemberJunction API Server (MJ 3.0 Minimal Architecture)
 * All initialization logic is in @memberjunction/server-bootstrap
 */
import { createMJServer } from '@memberjunction/server-bootstrap';

// Import the BizApps Issues server bootstrap (registers entities, actions, and resolvers).
// This test-harness API also loads the Tasks + Common server bootstraps so the
// FK'd Task/Person entities and their resolvers are available.
import { RESOLVER_PATHS as ISSUES_RESOLVER_PATHS } from '@mj-biz-apps/issues-server';
import { RESOLVER_PATHS as TASKS_RESOLVER_PATHS } from '@mj-biz-apps/tasks-server';
import { RESOLVER_PATHS as COMMON_RESOLVER_PATHS } from '@mj-biz-apps/common-server';

const RESOLVER_PATHS = [
  ...ISSUES_RESOLVER_PATHS,
  ...TASKS_RESOLVER_PATHS,
  ...COMMON_RESOLVER_PATHS,
];

// Import pre-built MJ class registrations manifest (covers all @memberjunction/* packages)
import '@memberjunction/server-bootstrap/mj-class-registrations';

// Optional: Import communication providers if needed
// import '@memberjunction/communication-sendgrid';
// import '@memberjunction/communication-teams';

// Optional: Import custom auth/user creation logic
// See: /docs/examples/custom-user-creation/README.md
// import './custom/customUserCreation';

// Start the server
createMJServer({ resolverPaths: RESOLVER_PATHS }).catch(console.error);
