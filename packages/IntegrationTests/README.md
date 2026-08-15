# @mj-biz-apps/issues-integration-tests

GraphQL-wire suite. Types and statuses are looked up from metadata. Seed issues go through typed entities over MJAPI.

```bash
pnpm --filter @mj-biz-apps/issues-integration-tests build
GRAPHQL_PORT=4103 node test-harnesses/integration.mjs
```
