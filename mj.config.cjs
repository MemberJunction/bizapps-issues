/** @type {import('@memberjunction/config').MJConfig} */
module.exports = {
  /**
   * MemberJunction Minimal Distribution Configuration for BizApps Issues.
   *
   * Most settings come from package defaults (DEFAULT_SERVER_CONFIG /
   * DEFAULT_CODEGEN_CONFIG). Only deployment-specific output paths,
   * post-CodeGen build commands, and the few overrides below are set here.
   */

  // ============================================================================
  // DEPLOYMENT-SPECIFIC CONFIGURATION (Required)
  // ============================================================================

  entityPackageName: '@mj-biz-apps/issues-entities',

  testing: {
    checkModules: ['@mj-biz-apps/issues-integration-tests'],
  },

  output: [
    { type: 'SQL', directory: './SQL Scripts/generated', appendOutputCode: true },
    {
      type: 'Angular',
      directory: './packages/Angular/src/lib/generated',
      options: [{ name: 'maxComponentsPerModule', value: 20 }],
    },
    { type: 'GraphQLServer', directory: './packages/Server/src/generated' },
    { type: 'ActionSubclasses', directory: './packages/Actions/src/generated' },
    { type: 'EntitySubclasses', directory: './packages/Entities/src/generated' },
    { type: 'DBSchemaJSON', directory: './Schema Files' },
  ],

  /**
   * Build commands run after code generation, in dependency order:
   * Entities → Actions → Core → CoreEntitiesServer → Server → Angular,
   * then boot MJAPI to verify.
   */
  commands: [
    {
      workingDirectory: './packages/Entities',
      command: 'npm',
      args: ['run', 'build'],
      when: 'after',
    },
    {
      workingDirectory: './packages/Actions',
      command: 'npm',
      args: ['run', 'build'],
      when: 'after',
    },
    {
      workingDirectory: './packages/Core',
      command: 'npm',
      args: ['run', 'build'],
      when: 'after',
    },
    {
      workingDirectory: './packages/CoreEntitiesServer',
      command: 'npm',
      args: ['run', 'build'],
      when: 'after',
    },
    {
      workingDirectory: './packages/Server',
      command: 'npm',
      args: ['run', 'build'],
      when: 'after',
    },
    {
      workingDirectory: './packages/Angular',
      command: 'npm',
      args: ['run', 'build'],
      when: 'after',
    },
  ],

  // ============================================================================
  // OPTIONAL OVERRIDES
  // ============================================================================

  // ---------------------------------------------------------------------------
  // New Entity Defaults — entity name prefix for the app schema.
  // Uses underscores (MJ_BizApps_Issues:) to match the BizApps convention.
  // ---------------------------------------------------------------------------
  newEntityDefaults: {
    NameRulesBySchema: [
      { SchemaName: '${mj_core_schema}', EntityNamePrefix: 'MJ: ' },
      {
        SchemaName: '__mj_BizAppsIssues',
        EntityNamePrefix: 'MJ_BizApps_Issues: ',
        EntityNameSuffix: '',
      },
    ],
  },

  // Allow-list: CodeGen this app's schema only (MJ >= 5.50 includeSchemas).
  // Unnamed schemas — core, siblings, never-seen client schemas — are excluded.
  includeSchemas: ['__mj_BizAppsIssues'],
  excludeSchemas: [],
  /**
   * Schema → npm for peer entity classes this emit does NOT generate
   * (embeds + related-record collections). Distinct from:
   *   includeSchemas     — what this run generates
   *   entityPackageName  — the npm package this run writes (string form)
   * Core (__mj) always comes from @memberjunction/core-entities; do not list it.
   * Do not map a foreign schema to this emit's own package.
   */
  entityImportPackages: {
    '__mj_BizAppsCommon': '@mj-biz-apps/common-entities',
    '__mj_BizAppsTasks': '@mj-biz-apps/tasks-entities',
  },

  // ---------------------------------------------------------------------------
  // SQL Output (for migrations)
  // ---------------------------------------------------------------------------
  SQLOutput: {
    enabled: true,
    folderPath: './migrations/codegen/',
    appendToFile: false,
    convertCoreSchemaToFlywayMigrationFile: true,
    omitRecurringScriptsFromLog: false,
    schemaPlaceholders: [
      // Order matters: the app schema must be substituted BEFORE '__mj' because
      // substitution runs sequentially with a greedy regex. If '__mj' came first
      // it would also match the '__mj' prefix of '__mj_BizAppsIssues', yielding
      // '${mjSchema}_BizAppsIssues'.
      { schema: '__mj_BizAppsIssues', placeholder: '${flyway:defaultSchema}' },
      { schema: '__mj', placeholder: '${mjSchema}' },
    ],
  },
};
