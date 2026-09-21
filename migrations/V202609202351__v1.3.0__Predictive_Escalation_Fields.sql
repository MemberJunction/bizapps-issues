-- =============================================================================
-- BizAppsIssues: Add Predictive Escalation Outcome Columns & Layered Base Views
-- Materialized columns for Predictive Studio issue escalation classification and
-- engineered relational & temporal training features computed via layered vwIssues.
-- =============================================================================

---------------------------------------------------------------------------
-- 1. Issue: Add materialized prediction fields
---------------------------------------------------------------------------
ALTER TABLE [${flyway:defaultSchema}].[Issue]
    ADD [PredictedCriticalEscalationProbability] DECIMAL(5, 4) NULL,
        [PredictedEscalationRiskBand] NVARCHAR(20) NULL,
        [PredictedEscalationScoredAt] DATETIMEOFFSET NULL;
GO

ALTER TABLE [${flyway:defaultSchema}].[Issue]
    ADD CONSTRAINT [CK_Issue_PredictedEscalationRiskBand]
        CHECK ([PredictedEscalationRiskBand] IN ('Low', 'Medium', 'High', 'Critical'));
GO

EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Predicted probability (0.0000 - 1.0000) that this issue escalates to critical or high back-and-forth severity.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}',
    @level1type = N'TABLE',  @level1name = N'Issue',
    @level2type = N'COLUMN', @level2name = N'PredictedCriticalEscalationProbability';
GO

EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Operational escalation risk tier: Low (<0.30), Medium (0.30-0.70), High (>0.70), or Critical (>=0.90).',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}',
    @level1type = N'TABLE',  @level1name = N'Issue',
    @level2type = N'COLUMN', @level2name = N'PredictedEscalationRiskBand';
GO

EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Timestamp when this issue was last scored by the predictive escalation model.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}',
    @level1type = N'TABLE',  @level1name = N'Issue',
    @level2type = N'COLUMN', @level2name = N'PredictedEscalationScoredAt';
GO

---------------------------------------------------------------------------
-- 2. Establish Layered Base Views for Issues
---------------------------------------------------------------------------
UPDATE [${mjSchema}].[Entity]
   SET [BaseViewGenerated] = 0,
       [GeneratedBaseViewName] = 'vwIssuesGenerated'
 WHERE [Name] = 'MJ_BizApps_Issues: Issues'
   AND ([BaseViewGenerated] <> 0
        OR [GeneratedBaseViewName] IS NULL
        OR [GeneratedBaseViewName] <> 'vwIssuesGenerated');
GO

IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssuesGenerated]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssuesGenerated];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssuesGenerated]
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
    [i].[CreatedByPersonID] = mjBizAppsCommonPerson_CreatedByPersonID.[ID];
GO

IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssues]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssues];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssues]
AS
SELECT
    g.*,
    -- Engineered features for Predictive Studio escalation modeling
    CASE 
        WHEN ISNULL(c.[CommentsCount], 0) >= 3 THEN 'Escalated' 
        ELSE 'Standard' 
    END AS [IsCriticalEscalation],
    ISNULL(c.[CommentsCount], 0) AS [CommentsCount],
    CASE WHEN g.[AssigneeRecordID] IS NOT NULL THEN 1 ELSE 0 END AS [HasAssignee],
    ISNULL(LEN(g.[Title]), 0) AS [TitleLength],
    ISNULL(LEN(g.[Description]), 0) AS [DescriptionLength]
FROM
    [${flyway:defaultSchema}].[vwIssuesGenerated] AS g
LEFT OUTER JOIN (
    SELECT [IssueID], COUNT(*) AS [CommentsCount]
    FROM [${flyway:defaultSchema}].[IssueComment]
    GROUP BY [IssueID]
) AS c ON c.[IssueID] = g.[ID];
GO

IF DATABASE_PRINCIPAL_ID('cdp_UI') IS NOT NULL
    EXEC('GRANT SELECT ON [${flyway:defaultSchema}].[vwIssues] TO [cdp_UI]');
IF DATABASE_PRINCIPAL_ID('cdp_Developer') IS NOT NULL
    EXEC('GRANT SELECT ON [${flyway:defaultSchema}].[vwIssues] TO [cdp_Developer]');
IF DATABASE_PRINCIPAL_ID('cdp_Integration') IS NOT NULL
    EXEC('GRANT SELECT ON [${flyway:defaultSchema}].[vwIssues] TO [cdp_Integration]');
GO




















































































-- =============================================================================
-- GENERATED BY MemberJunction CodeGen — DO NOT EDIT BY HAND
-- =============================================================================
/* SQL text to update existing entities from schema */
EXEC [${mjSchema}].[spUpdateExistingEntitiesFromSchema] @ExcludedSchemaNames='', @IncludedSchemaNames='${flyway:defaultSchema}';

/* SQL text to insert 8 new entity field(s) */
DECLARE @IssueEntityID UNIQUEIDENTIFIER =
    (SELECT [ID] FROM [${mjSchema}].[Entity] WHERE [Name] = 'MJ_BizApps_Issues: Issues');
IF @IssueEntityID IS NULL RAISERROR('Issues entity not registered', 16, 1);


      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'e3da291a-9919-4fbd-b2ac-453baebfb788' OR (EntityID = @IssueEntityID AND Name = 'PredictedCriticalEscalationProbability')) BEGIN
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
            'e3da291a-9919-4fbd-b2ac-453baebfb788',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'PredictedCriticalEscalationProbability',
            'Predicted Critical Escalation Probability',
            'Predicted probability (0.0000 - 1.0000) that this issue escalates to critical or high back-and-forth severity.',
            'decimal',
            5,
            5,
            4,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '5bdfcefb-787b-49dc-8508-8d3e2cc9ade3' OR (EntityID = @IssueEntityID AND Name = 'PredictedEscalationRiskBand')) BEGIN
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
            '5bdfcefb-787b-49dc-8508-8d3e2cc9ade3',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'PredictedEscalationRiskBand',
            'Predicted Escalation Risk Band',
            'Operational escalation risk tier: Low (<0.30), Medium (0.30-0.70), High (>0.70), or Critical (>=0.90).',
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'f1263060-2773-46bb-b829-460e777e4d3a' OR (EntityID = @IssueEntityID AND Name = 'PredictedEscalationScoredAt')) BEGIN
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
            'f1263060-2773-46bb-b829-460e777e4d3a',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'PredictedEscalationScoredAt',
            'Predicted Escalation Scored At',
            'Timestamp when this issue was last scored by the predictive escalation model.',
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '228da02b-55f1-4de0-824f-dc74320e737b' OR (EntityID = @IssueEntityID AND Name = 'IsCriticalEscalation')) BEGIN
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
            '228da02b-55f1-4de0-824f-dc74320e737b',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'IsCriticalEscalation',
            'Is Critical Escalation',
            NULL,
            'varchar',
            9,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '6361dba4-094e-4055-94a4-bd74cdbe4487' OR (EntityID = @IssueEntityID AND Name = 'CommentsCount')) BEGIN
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
            '6361dba4-094e-4055-94a4-bd74cdbe4487',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'CommentsCount',
            'Comments Count',
            NULL,
            'int',
            4,
            10,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'b64ccbdf-1742-4c34-a63d-07da4ef151b5' OR (EntityID = @IssueEntityID AND Name = 'HasAssignee')) BEGIN
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
            'b64ccbdf-1742-4c34-a63d-07da4ef151b5',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'HasAssignee',
            'Has Assignee',
            NULL,
            'int',
            4,
            10,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = '153fbaf4-8251-4f52-bf87-f6e1aedf98df' OR (EntityID = @IssueEntityID AND Name = 'TitleLength')) BEGIN
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
            '153fbaf4-8251-4f52-bf87-f6e1aedf98df',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'TitleLength',
            'Title Length',
            NULL,
            'int',
            4,
            10,
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

      IF NOT EXISTS (SELECT 1 FROM [${mjSchema}].[EntityField] WHERE ID = 'a0aace31-0601-457a-b4d1-d87a27c6f47d' OR (EntityID = @IssueEntityID AND Name = 'DescriptionLength')) BEGIN
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
            'a0aace31-0601-457a-b4d1-d87a27c6f47d',
            @IssueEntityID, -- Entity: MJ_BizApps_Issues: Issues
            (SELECT COALESCE(MAX([Sequence]), 0) + 1 FROM [${mjSchema}].[EntityField] WHERE [EntityID] = @IssueEntityID),
            'DescriptionLength',
            'Description Length',
            NULL,
            'bigint',
            8,
            19,
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

/* SQL text to update existing entity fields from schema */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='', @IncludedSchemaNames='${flyway:defaultSchema}';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='', @IncludedSchemaNames='${flyway:defaultSchema}';

/* SQL text to insert entity field value with ID 38373e95-ce14-4340-bc34-783d3be9b920 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('38373e95-ce14-4340-bc34-783d3be9b920', '5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3', 1, 'Critical', 'Critical', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID d86ac07e-0fd8-4c0b-a098-121bf3f1fd18 */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('d86ac07e-0fd8-4c0b-a098-121bf3f1fd18', '5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3', 2, 'High', 'High', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID c71d53bc-8046-48f8-b022-5fa10b8385fa */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('c71d53bc-8046-48f8-b022-5fa10b8385fa', '5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3', 3, 'Low', 'Low', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID 0b6cd487-910c-4604-a645-7332df57ae8a */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('0b6cd487-910c-4604-a645-7332df57ae8a', '5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3', 4, 'Medium', 'Medium', GETUTCDATE(), GETUTCDATE());

/* SQL text to update ValueListType for entity field ID 5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3 */
UPDATE [${mjSchema}].[EntityField] SET ValueListType='List' WHERE ID='5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3';

/* SQL text to sync schema info from database schemas */
EXEC [${mjSchema}].[spUpdateSchemaInfoFromDatabase] @ExcludedSchemaNames='', @IncludedSchemaNames='${flyway:defaultSchema}';

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

/* Base View Permissions SQL for MJ_BizApps_Issues: Issues */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issues
-- Item: Permissions for vwIssues
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

REVOKE SELECT ON [${flyway:defaultSchema}].[vwIssues] FROM [cdp_Developer]
REVOKE SELECT ON [${flyway:defaultSchema}].[vwIssues] FROM [cdp_Integration]
REVOKE SELECT ON [${flyway:defaultSchema}].[vwIssues] FROM [cdp_UI]
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
    @CreatedByPersonID uniqueidentifier = NULL,
    @PredictedCriticalEscalationProbability_Clear bit = 0,
    @PredictedCriticalEscalationProbability decimal(5, 4) = NULL,
    @PredictedEscalationRiskBand_Clear bit = 0,
    @PredictedEscalationRiskBand nvarchar(20) = NULL,
    @PredictedEscalationScoredAt_Clear bit = 0,
    @PredictedEscalationScoredAt datetimeoffset = NULL
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
                [CreatedByPersonID],
                [PredictedCriticalEscalationProbability],
                [PredictedEscalationRiskBand],
                [PredictedEscalationScoredAt]
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
                CASE WHEN @CreatedByPersonID_Clear = 1 THEN NULL ELSE ISNULL(@CreatedByPersonID, NULL) END,
                CASE WHEN @PredictedCriticalEscalationProbability_Clear = 1 THEN NULL ELSE ISNULL(@PredictedCriticalEscalationProbability, NULL) END,
                CASE WHEN @PredictedEscalationRiskBand_Clear = 1 THEN NULL ELSE ISNULL(@PredictedEscalationRiskBand, NULL) END,
                CASE WHEN @PredictedEscalationScoredAt_Clear = 1 THEN NULL ELSE ISNULL(@PredictedEscalationScoredAt, NULL) END
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
                [CreatedByPersonID],
                [PredictedCriticalEscalationProbability],
                [PredictedEscalationRiskBand],
                [PredictedEscalationScoredAt]
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
                CASE WHEN @CreatedByPersonID_Clear = 1 THEN NULL ELSE ISNULL(@CreatedByPersonID, NULL) END,
                CASE WHEN @PredictedCriticalEscalationProbability_Clear = 1 THEN NULL ELSE ISNULL(@PredictedCriticalEscalationProbability, NULL) END,
                CASE WHEN @PredictedEscalationRiskBand_Clear = 1 THEN NULL ELSE ISNULL(@PredictedEscalationRiskBand, NULL) END,
                CASE WHEN @PredictedEscalationScoredAt_Clear = 1 THEN NULL ELSE ISNULL(@PredictedEscalationScoredAt, NULL) END
            )
    END
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssues] WHERE [ID] = (SELECT [ID] FROM @InsertedRow)
END
GO
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] FROM [cdp_Developer]
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] FROM [cdp_Integration]
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issues */

REVOKE EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] FROM [cdp_Developer]
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] FROM [cdp_Integration]
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssue] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

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
    @CreatedByPersonID uniqueidentifier = NULL,
    @PredictedCriticalEscalationProbability_Clear bit = 0,
    @PredictedCriticalEscalationProbability decimal(5, 4) = NULL,
    @PredictedEscalationRiskBand_Clear bit = 0,
    @PredictedEscalationRiskBand nvarchar(20) = NULL,
    @PredictedEscalationScoredAt_Clear bit = 0,
    @PredictedEscalationScoredAt datetimeoffset = NULL
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
        [CreatedByPersonID] = CASE WHEN @CreatedByPersonID_Clear = 1 THEN NULL ELSE ISNULL(@CreatedByPersonID, [CreatedByPersonID]) END,
        [PredictedCriticalEscalationProbability] = CASE WHEN @PredictedCriticalEscalationProbability_Clear = 1 THEN NULL ELSE ISNULL(@PredictedCriticalEscalationProbability, [PredictedCriticalEscalationProbability]) END,
        [PredictedEscalationRiskBand] = CASE WHEN @PredictedEscalationRiskBand_Clear = 1 THEN NULL ELSE ISNULL(@PredictedEscalationRiskBand, [PredictedEscalationRiskBand]) END,
        [PredictedEscalationScoredAt] = CASE WHEN @PredictedEscalationScoredAt_Clear = 1 THEN NULL ELSE ISNULL(@PredictedEscalationScoredAt, [PredictedEscalationScoredAt]) END
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

REVOKE EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] FROM [cdp_Developer]
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] FROM [cdp_Integration]
GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] TO [cdp_UI], [cdp_Developer], [cdp_Integration]
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

REVOKE EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] FROM [cdp_Developer]
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] FROM [cdp_Integration]
GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssue] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

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
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] FROM [cdp_Developer]
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] FROM [cdp_Integration]
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issues */

REVOKE EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] FROM [cdp_Developer]
REVOKE EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] FROM [cdp_Integration]
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssue] TO [cdp_Developer], [cdp_Integration];

/* SQL text to delete unneeded entity fields (1 scoped entities) */

/* SQL text to update existing entity fields from schema (1 scoped entities) */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='', @IncludedSchemaNames='${flyway:defaultSchema}';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='', @IncludedSchemaNames='${flyway:defaultSchema}';

/* Set field properties for entity */

               UPDATE [${mjSchema}].[EntityField]
               SET IsNameField = 1
               WHERE ID = 'ADDDCC67-6C31-4E40-8C22-AAAF2E9EB165'
               AND AutoUpdateIsNameField = 1;

/* Set categories for 33 fields */

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.IssueNumber 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'ADDDCC67-6C31-4E40-8C22-AAAF2E9EB165';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.Title 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'FBDA77B7-3EDB-4D32-A7D4-06FE401457BE';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.Description 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '1CE66015-9E1B-4E20-BE02-922D1D91A619';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.AppScope 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'BDC175D9-3F7B-4818-AF86-801D821B9276';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.IssueTypeID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Classification',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'E4408976-8A26-42D6-9B2D-81216476AD9C';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.StatusID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Classification',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '2963D2BC-0473-47A0-BE0A-0E1BD925928B';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.Severity 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Classification',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '99C48BC4-C15E-440A-A577-EC5BA8F9E48B';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.Priority 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Classification',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '7C48EC27-0691-4CE9-B990-F554CAF50864';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.ReporterPersonID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '06ED94D8-4607-4061-888E-788FFAFCA023';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.ReporterEmail 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '65C94B3C-A5BF-4D2D-BBFF-289A0C041047';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.AssigneeEntityID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '5D649C62-6589-43F0-AFFD-E3F9E3268CC8';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.AssigneeRecordID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '24653D3B-FAED-4A91-BD7F-8C903B8AD018';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.SourceEntityID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Context',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '9D602C66-9FB5-4514-9ED6-7B530012AE3A';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.SourceRecordID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Context',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '5E4D5272-5F71-4E7F-99B0-F0D9DE5C3641';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.ResolvedAt 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Timeline',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'D50B709A-C90F-4771-ABEF-9A108002A341';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.ClosedAt 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Timeline',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '9AB132E0-FB1A-410A-A736-DDFBB0388F7E';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.CreatedByPersonID 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Timeline',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '2BDFB21A-BAF7-482D-98C5-4DFD03FF45EE';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.__mj_CreatedAt 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'System Metadata',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'D6995810-5F0A-4775-8E81-9BD304DCA9E0';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.__mj_UpdatedAt 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'System Metadata',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '77F34775-1C61-4921-AC99-045D0A20B9BF';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.PredictedCriticalEscalationProbability 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Escalation Intelligence',
   GeneratedFormSection = 'Category',
   DisplayName = 'Escalation Probability'
WHERE 
   ID = 'E3DA291A-9919-4FBD-B2AC-453BAEBFB788';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.PredictedEscalationRiskBand 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Escalation Intelligence',
   GeneratedFormSection = 'Category',
   DisplayName = 'Escalation Risk Band'
WHERE 
   ID = '5BDFCEFB-787B-49DC-8508-8D3E2CC9ADE3';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.PredictedEscalationScoredAt 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Escalation Intelligence',
   GeneratedFormSection = 'Category',
   DisplayName = 'Escalation Scored At'
WHERE 
   ID = 'F1263060-2773-46BB-B829-460E777E4D3A';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.IssueType 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Classification',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'A0E546EC-BEA3-46E0-B5E9-21C9F6A31AE3';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.Status 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Classification',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '9111E30E-76A3-4582-AC5C-06A7B9AC530E';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.ReporterPerson 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '5B543630-4C16-4034-99DE-1C4420A9CBD2';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.AssigneeEntity 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '00D07775-578D-4F35-86B6-136B9256FC30';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.SourceEntity 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Context',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'D0D423B1-0148-4920-A657-5756B13364B6';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.CreatedByPerson 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Timeline',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '7D7C497F-A10E-4EA5-8DAF-50095C9FB635';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.IsCriticalEscalation 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Escalation Intelligence',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '228DA02B-55F1-4DE0-824F-DC74320E737B';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.CommentsCount 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '6361DBA4-094E-4055-94A4-BD74CDBE4487';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.HasAssignee 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Stakeholders',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'B64CCBDF-1742-4C34-A63D-07DA4EF151B5';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.TitleLength 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = '153FBAF4-8251-4F52-BF87-F6E1AEDF98DF';

-- UPDATE Entity Field Category Info MJ_BizApps_Issues: Issues.DescriptionLength 
UPDATE [${mjSchema}].[EntityField]
SET 
   Category = 'Issue Overview',
   GeneratedFormSection = 'Category'
WHERE 
   ID = 'A0AACE31-0601-457A-B4D1-D87A27C6F47D';

/* Set entity icon to fa fa-bug */
DECLARE @IssueEntityID_Settings UNIQUEIDENTIFIER =
    (SELECT [ID] FROM [${mjSchema}].[Entity] WHERE [Name] = 'MJ_BizApps_Issues: Issues');

               UPDATE [${mjSchema}].[Entity]
               SET [Icon] = 'fa fa-bug', [__mj_UpdatedAt] = GETUTCDATE()
               WHERE [ID] = @IssueEntityID_Settings;

/* Insert FieldCategoryInfo setting for entity */
IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntitySetting] WHERE [EntityID] = @IssueEntityID_Settings AND [Name] = 'FieldCategoryInfo'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntitySetting] ([ID], [EntityID], [Name], [Value], [__mj_CreatedAt], [__mj_UpdatedAt])
               VALUES ('3c710b93-00ae-5f44-9f14-d91e4e4ededf', @IssueEntityID_Settings, 'FieldCategoryInfo', '{
  "Classification": {
    "description": "Categorization, status, and priority settings for the issue.",
    "icon": "fa fa-tags"
  },
  "Context": {
    "description": "Links to the source entity that this issue concerns.",
    "icon": "fa fa-link"
  },
  "Escalation Intelligence": {
    "description": "Predictive analytics regarding escalation risk.",
    "icon": "fa fa-exclamation-triangle"
  },
  "Issue Overview": {
    "description": "Core summary, description, and metadata about the issue.",
    "icon": "fa fa-info-circle"
  },
  "Stakeholders": {
    "description": "Information about the reporter and the assigned party.",
    "icon": "fa fa-users"
  },
  "System Metadata": {
    "description": "System-managed audit and tracking fields.",
    "icon": "fa fa-cog"
  },
  "Timeline": {
    "description": "Key lifecycle dates and authorship information.",
    "icon": "fa fa-calendar-alt"
  }
}', GETUTCDATE(), GETUTCDATE())
   END;

/* Insert FieldCategoryIcons setting (legacy) */
IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[EntitySetting] WHERE [EntityID] = @IssueEntityID_Settings AND [Name] = 'FieldCategoryIcons'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[EntitySetting] ([ID], [EntityID], [Name], [Value], [__mj_CreatedAt], [__mj_UpdatedAt])
               VALUES ('be0c082c-2519-577a-b073-31c764d4aade', @IssueEntityID_Settings, 'FieldCategoryIcons', '{
  "Classification": "fa fa-tags",
  "Context": "fa fa-link",
  "Escalation Intelligence": "fa fa-exclamation-triangle",
  "Issue Overview": "fa fa-info-circle",
  "Stakeholders": "fa fa-users",
  "System Metadata": "fa fa-cog",
  "Timeline": "fa fa-calendar-alt"
}', GETUTCDATE(), GETUTCDATE())
   END;

/* Refresh custom base views for modified entities so schema changes are picked up */
EXEC sp_refreshview '${flyway:defaultSchema}.vwIssues';

/* Generated Validation Functions for MJ_BizApps_Issues: Issue Number Sequences */
-- CHECK constraint for MJ_BizApps_Issues: Issue Number Sequences: Field: NextSequenceNumber was newly set or modified since the last generation of the validation function, the code was regenerated and updating the GeneratedCode table with the new generated validation function
IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[GeneratedCode] WHERE [CategoryID] = (SELECT [ID] FROM [${mjSchema}].[vwGeneratedCodeCategories] WHERE [Name]='CodeGen: Validators') AND [LinkedEntityID] = 'DF238F34-2837-EF11-86D4-6045BDEE16E6' AND [LinkedRecordPrimaryKey] = '219D0D34-F277-4222-B9A1-F5A9F155ABCA'
   )
   BEGIN
      INSERT INTO [${mjSchema}].[GeneratedCode] ([ID], [CategoryID], [GeneratedByModelID], [GeneratedAt], [Language], [Status], [Source], [Code], [Description], [Name], [LinkedEntityID], [LinkedRecordPrimaryKey])
VALUES ('16a7d7b8-23af-4a58-baf5-f43eff764f80', (SELECT [ID] FROM [${mjSchema}].[vwGeneratedCodeCategories] WHERE [Name]='CodeGen: Validators'), 'C43229F6-4CC8-4838-9D04-03419A2DA191', GETUTCDATE(), 'TypeScript', 'Approved', '([NextSequenceNumber]>(0))', 'public ValidateNextSequenceNumberGreaterThanZero(result: ValidationResult) {
	if (this.NextSequenceNumber != null && this.NextSequenceNumber <= 0) {
		result.Errors.push(new ValidationErrorInfo(
			"NextSequenceNumber",
			"The next sequence number must be greater than 0.",
			this.NextSequenceNumber,
			ValidationErrorType.Failure
		));
	}
}', 'The next sequence number must be a positive integer greater than zero to ensure sequence generation starts correctly.', 'ValidateNextSequenceNumberGreaterThanZero', 'DF238F34-2837-EF11-86D4-6045BDEE16E6', '219D0D34-F277-4222-B9A1-F5A9F155ABCA')
   END;

/* Generated Validation Functions for MJ_BizApps_Issues: Issues */
-- CHECK constraint for MJ_BizApps_Issues: Issues @ Table Level was newly set or modified since the last generation of the validation function, the code was regenerated and updating the GeneratedCode table with the new generated validation function
IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[GeneratedCode] WHERE [CategoryID] = (SELECT [ID] FROM [${mjSchema}].[vwGeneratedCodeCategories] WHERE [Name]='CodeGen: Validators') AND [LinkedEntityID] = 'E0238F34-2837-EF11-86D4-6045BDEE16E6' AND [LinkedRecordPrimaryKey] = @IssueEntityID_Settings
   )
   BEGIN
      INSERT INTO [${mjSchema}].[GeneratedCode] ([ID], [CategoryID], [GeneratedByModelID], [GeneratedAt], [Language], [Status], [Source], [Code], [Description], [Name], [LinkedEntityID], [LinkedRecordPrimaryKey])
VALUES ('6f29640b-081c-435e-a766-c1fdf055df7f', (SELECT [ID] FROM [${mjSchema}].[vwGeneratedCodeCategories] WHERE [Name]='CodeGen: Validators'), 'C43229F6-4CC8-4838-9D04-03419A2DA191', GETUTCDATE(), 'TypeScript', 'Approved', '([AssigneeEntityID] IS NULL AND [AssigneeRecordID] IS NULL OR [AssigneeEntityID] IS NOT NULL AND [AssigneeRecordID] IS NOT NULL)', 'public ValidateAssigneeFieldsCoexistence(result: ValidationResult) {
	const hasEntity = this.AssigneeEntityID != null;
	const hasRecord = this.AssigneeRecordID != null;

	if (hasEntity !== hasRecord) {
		result.Errors.push(new ValidationErrorInfo(
			"AssigneeEntityID",
			"Both Assignee Entity and Assignee Record must be specified together, or both must be left empty.",
			this.AssigneeEntityID,
			ValidationErrorType.Failure
		));
	}
}', 'Both Assignee Entity and Assignee Record must either be provided together or both left blank to ensure the assignee reference is complete.', 'ValidateAssigneeFieldsCoexistence', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', @IssueEntityID_Settings)
   END;

-- CHECK constraint for MJ_BizApps_Issues: Issues @ Table Level was newly set or modified since the last generation of the validation function, the code was regenerated and updating the GeneratedCode table with the new generated validation function
IF NOT EXISTS (
      SELECT 1 FROM [${mjSchema}].[GeneratedCode] WHERE [CategoryID] = (SELECT [ID] FROM [${mjSchema}].[vwGeneratedCodeCategories] WHERE [Name]='CodeGen: Validators') AND [LinkedEntityID] = 'E0238F34-2837-EF11-86D4-6045BDEE16E6' AND [LinkedRecordPrimaryKey] = @IssueEntityID_Settings
   )
   BEGIN
      INSERT INTO [${mjSchema}].[GeneratedCode] ([ID], [CategoryID], [GeneratedByModelID], [GeneratedAt], [Language], [Status], [Source], [Code], [Description], [Name], [LinkedEntityID], [LinkedRecordPrimaryKey])
VALUES ('4020813c-2edb-49f2-ab51-4d3a7f9dc661', (SELECT [ID] FROM [${mjSchema}].[vwGeneratedCodeCategories] WHERE [Name]='CodeGen: Validators'), 'C43229F6-4CC8-4838-9D04-03419A2DA191', GETUTCDATE(), 'TypeScript', 'Approved', '([SourceEntityID] IS NULL AND [SourceRecordID] IS NULL OR [SourceEntityID] IS NOT NULL AND [SourceRecordID] IS NOT NULL)', '	public ValidateSourceEntityAndRecordCoexistence(result: ValidationResult) {
		const hasSourceEntity = this.SourceEntityID != null;
		const hasSourceRecord = this.SourceRecordID != null;

		if (hasSourceEntity !== hasSourceRecord) {
			result.Errors.push(new ValidationErrorInfo(
				"SourceEntityID",
				"Both Source Entity and Source Record must be provided together, or both must be left blank.",
				this.SourceEntityID,
				ValidationErrorType.Failure
			));
		}
	}', 'Both Source Entity and Source Record must be provided together, or both must be left empty.', 'ValidateSourceEntityAndRecordCoexistence', 'E0238F34-2837-EF11-86D4-6045BDEE16E6', @IssueEntityID_Settings)
   END;

