-- =============================================================================
-- IssueComment.Source — channel-agnostic direction/visibility
-- =============================================================================
-- The original Source values ('internal','email','external') conflated visibility
-- with delivery CHANNEL ('email'). A customer-facing reply can go out on email,
-- SMS, or (eventually) phone — so 'email' is wrong the moment the channel differs.
-- The delivery channel is knowable from the ticket's linked message, not from the
-- comment. So Source now encodes DIRECTION/visibility only, channel-agnostic:
--   internal  = staff-only note, never sent to the reporter
--   outbound  = a customer-facing message we sent (on whatever channel)
--   inbound   = a message from the customer/external side, captured into the thread
--
-- Mapping of the old values: 'email' → 'outbound', 'external' → 'inbound',
-- 'internal' unchanged. Default stays 'internal'.
--
-- Separate V-migration (the baseline B-script is already applied/immutable).
-- Additive/safe: same column + width; only the CHECK value set + remap of any
-- existing rows. CodeGen regenerates the entity Value List + spCreate/spUpdate.
-- =============================================================================

-- Drop the old CHECK before remapping (so the UPDATE isn't blocked by it).
-- Guarded: the constraint may not exist on every DB (it's skipped if absent),
-- so the migration is safe regardless of prior state.
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_IssueComment_Source'
           AND parent_object_id = OBJECT_ID('${flyway:defaultSchema}.IssueComment'))
    ALTER TABLE ${flyway:defaultSchema}.IssueComment DROP CONSTRAINT CK_IssueComment_Source;
GO

-- Remap any existing rows to the new direction values (no-op when none exist).
UPDATE ${flyway:defaultSchema}.IssueComment SET Source = 'outbound' WHERE Source = 'email';
UPDATE ${flyway:defaultSchema}.IssueComment SET Source = 'inbound'  WHERE Source = 'external';
GO

-- Re-add the CHECK with the new channel-agnostic value set (guarded so a re-run
-- against an already-migrated DB is a no-op).
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_IssueComment_Source'
               AND parent_object_id = OBJECT_ID('${flyway:defaultSchema}.IssueComment'))
    ALTER TABLE ${flyway:defaultSchema}.IssueComment
        ADD CONSTRAINT CK_IssueComment_Source CHECK (Source IN ('internal', 'outbound', 'inbound'));
GO

-- Refresh the column description to match the new model.
EXEC sp_updateextendedproperty @name = N'MS_Description', @value = N'Direction/visibility of the comment (channel-agnostic): ''internal'' (staff-only note, never sent), ''outbound'' (customer-facing message we sent, on any channel), or ''inbound'' (a message from the customer/external side captured into the thread). The delivery channel is knowable from the ticket''s linked message, not here.',
    @level0type = N'SCHEMA', @level0name = N'${flyway:defaultSchema}', @level1type = N'TABLE', @level1name = N'IssueComment', @level2type = N'COLUMN', @level2name = N'Source';
GO
























/*-----------------------------CODEGEN--------------------------*/
/* SQL text to update existing entities from schema */
EXEC [${mjSchema}].[spUpdateExistingEntitiesFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to update existing entity fields from schema */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* SQL text to delete entity field value ID E875C064-3D9D-407E-A4E5-C27C1F793206 */
DELETE FROM [${mjSchema}].[EntityFieldValue] WHERE ID='E875C064-3D9D-407E-A4E5-C27C1F793206';

/* SQL text to delete entity field value ID D954BA16-F348-4746-A7A7-5273C3EF3834 */
DELETE FROM [${mjSchema}].[EntityFieldValue] WHERE ID='D954BA16-F348-4746-A7A7-5273C3EF3834';

/* SQL text to insert entity field value with ID d5e3cbda-e027-488d-b379-2f56d5968edd */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('d5e3cbda-e027-488d-b379-2f56d5968edd', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 1, 'inbound', 'inbound', GETUTCDATE(), GETUTCDATE());

/* SQL text to insert entity field value with ID d9d4811d-336e-4361-b8e2-3269c6c95fbe */
INSERT INTO [${mjSchema}].[EntityFieldValue]
                                       ([ID], [EntityFieldID], [Sequence], [Value], [Code], [__mj_CreatedAt], [__mj_UpdatedAt])
                                    VALUES
                                       ('d9d4811d-336e-4361-b8e2-3269c6c95fbe', '89D0ECAE-49F6-4730-B9E4-1F0CFE373571', 3, 'outbound', 'outbound', GETUTCDATE(), GETUTCDATE());

/* SQL text to update entity field value sequence */
UPDATE [${mjSchema}].[EntityFieldValue] SET Sequence=2 WHERE ID='CB674C9D-5DC8-42B4-B37B-59CB1CC1A81C';

/* SQL text to sync schema info from database schemas */
EXEC [${mjSchema}].[spUpdateSchemaInfoFromDatabase] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

/* Index for Foreign Keys for IssueComment */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: Index for Foreign Keys
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------
-- Index for foreign key IssueID in table IssueComment
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueComment_IssueID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueComment]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueComment_IssueID ON [${flyway:defaultSchema}].[IssueComment] ([IssueID]);

-- Index for foreign key AuthorPersonID in table IssueComment
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID' 
    AND object_id = OBJECT_ID('[${flyway:defaultSchema}].[IssueComment]')
)
CREATE INDEX IDX_AUTO_MJ_FKEY_IssueComment_AuthorPersonID ON [${flyway:defaultSchema}].[IssueComment] ([AuthorPersonID]);

/* Base View SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- BASE VIEW FOR ENTITY:      MJ_BizApps_Issues: Issue Comments
-----               SCHEMA:      ${flyway:defaultSchema}
-----               BASE TABLE:  IssueComment
-----               PRIMARY KEY: ID
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[vwIssueComments]', 'V') IS NOT NULL
    DROP VIEW [${flyway:defaultSchema}].[vwIssueComments];
GO

CREATE VIEW [${flyway:defaultSchema}].[vwIssueComments]
AS
SELECT
    i.*,
    mjBizAppsCommonPerson_AuthorPersonID.[DisplayName] AS [AuthorPerson]
FROM
    [${flyway:defaultSchema}].[IssueComment] AS i
LEFT OUTER JOIN
    [${mjSchema}_BizAppsCommon].[Person] AS mjBizAppsCommonPerson_AuthorPersonID
  ON
    [i].[AuthorPersonID] = mjBizAppsCommonPerson_AuthorPersonID.[ID]
GO
GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueComments] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* Base View Permissions SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: Permissions for vwIssueComments
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

GRANT SELECT ON [${flyway:defaultSchema}].[vwIssueComments] TO [cdp_UI], [cdp_Developer], [cdp_Integration];

/* spCreate SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spCreateIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- CREATE PROCEDURE FOR IssueComment
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spCreateIssueComment]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spCreateIssueComment];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spCreateIssueComment]
    @ID uniqueidentifier = NULL,
    @IssueID uniqueidentifier,
    @Body nvarchar(MAX),
    @AuthorPersonID_Clear bit = 0,
    @AuthorPersonID uniqueidentifier = NULL,
    @AuthorEmail_Clear bit = 0,
    @AuthorEmail nvarchar(320) = NULL,
    @Source nvarchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @InsertedRow TABLE ([ID] UNIQUEIDENTIFIER)
    
    IF @ID IS NOT NULL
    BEGIN
        -- User provided a value, use it
        INSERT INTO [${flyway:defaultSchema}].[IssueComment]
            (
                [ID],
                [IssueID],
                [Body],
                [AuthorPersonID],
                [AuthorEmail],
                [Source]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @ID,
                @IssueID,
                @Body,
                CASE WHEN @AuthorPersonID_Clear = 1 THEN NULL ELSE ISNULL(@AuthorPersonID, NULL) END,
                CASE WHEN @AuthorEmail_Clear = 1 THEN NULL ELSE ISNULL(@AuthorEmail, NULL) END,
                ISNULL(@Source, 'internal')
            )
    END
    ELSE
    BEGIN
        -- No value provided, let database use its default (e.g., NEWSEQUENTIALID())
        INSERT INTO [${flyway:defaultSchema}].[IssueComment]
            (
                [IssueID],
                [Body],
                [AuthorPersonID],
                [AuthorEmail],
                [Source]
            )
        OUTPUT INSERTED.[ID] INTO @InsertedRow
        VALUES
            (
                @IssueID,
                @Body,
                CASE WHEN @AuthorPersonID_Clear = 1 THEN NULL ELSE ISNULL(@AuthorPersonID, NULL) END,
                CASE WHEN @AuthorEmail_Clear = 1 THEN NULL ELSE ISNULL(@AuthorEmail, NULL) END,
                ISNULL(@Source, 'internal')
            )
    END
    -- return the new record from the base view, which might have some calculated fields
    SELECT * FROM [${flyway:defaultSchema}].[vwIssueComments] WHERE [ID] = (SELECT [ID] FROM @InsertedRow)
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spCreate Permissions for MJ_BizApps_Issues: Issue Comments */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spCreateIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spUpdate SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spUpdateIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- UPDATE PROCEDURE FOR IssueComment
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spUpdateIssueComment]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueComment];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spUpdateIssueComment]
    @ID uniqueidentifier,
    @IssueID uniqueidentifier = NULL,
    @Body nvarchar(MAX) = NULL,
    @AuthorPersonID_Clear bit = 0,
    @AuthorPersonID uniqueidentifier = NULL,
    @AuthorEmail_Clear bit = 0,
    @AuthorEmail nvarchar(320) = NULL,
    @Source nvarchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueComment]
    SET
        [IssueID] = ISNULL(@IssueID, [IssueID]),
        [Body] = ISNULL(@Body, [Body]),
        [AuthorPersonID] = CASE WHEN @AuthorPersonID_Clear = 1 THEN NULL ELSE ISNULL(@AuthorPersonID, [AuthorPersonID]) END,
        [AuthorEmail] = CASE WHEN @AuthorEmail_Clear = 1 THEN NULL ELSE ISNULL(@AuthorEmail, [AuthorEmail]) END,
        [Source] = ISNULL(@Source, [Source])
    WHERE
        [ID] = @ID

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
        -- Nothing was updated, return no rows, but column structure from base view intact, semantically correct this way.
        SELECT TOP 0 * FROM [${flyway:defaultSchema}].[vwIssueComments] WHERE 1=0
    ELSE
        -- Return the updated record so the caller can see the updated values and any calculated fields
        SELECT
                                        *
                                    FROM
                                        [${flyway:defaultSchema}].[vwIssueComments]
                                    WHERE
                                        [ID] = @ID
                                    
END
GO

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueComment] TO [cdp_Developer], [cdp_Integration]
GO

------------------------------------------------------------
----- TRIGGER FOR __mj_UpdatedAt field for the IssueComment table
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[trgUpdateIssueComment]', 'TR') IS NOT NULL
    DROP TRIGGER [${flyway:defaultSchema}].[trgUpdateIssueComment];
GO
CREATE TRIGGER [${flyway:defaultSchema}].trgUpdateIssueComment
ON [${flyway:defaultSchema}].[IssueComment]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE
        [${flyway:defaultSchema}].[IssueComment]
    SET
        __mj_UpdatedAt = GETUTCDATE()
    FROM
        [${flyway:defaultSchema}].[IssueComment] AS _organicTable
    INNER JOIN
        INSERTED AS I ON
        _organicTable.[ID] = I.[ID];
END;
GO

/* spUpdate Permissions for MJ_BizApps_Issues: Issue Comments */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spUpdateIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spDelete SQL for MJ_BizApps_Issues: Issue Comments */
-----------------------------------------------------------------
-- SQL Code Generation
-- Entity: MJ_BizApps_Issues: Issue Comments
-- Item: spDeleteIssueComment
--
-- This was generated by the MemberJunction CodeGen tool.
-- This file should NOT be edited by hand.
-----------------------------------------------------------------

------------------------------------------------------------
----- DELETE PROCEDURE FOR IssueComment
------------------------------------------------------------
IF OBJECT_ID('[${flyway:defaultSchema}].[spDeleteIssueComment]', 'P') IS NOT NULL
    DROP PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueComment];
GO

CREATE PROCEDURE [${flyway:defaultSchema}].[spDeleteIssueComment]
    @ID uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM
        [${flyway:defaultSchema}].[IssueComment]
    WHERE
        [ID] = @ID


    -- Check if the delete was successful
    IF @@ROWCOUNT = 0
        SELECT NULL AS [ID] -- Return NULL for all primary key fields to indicate no record was deleted
    ELSE
        SELECT @ID AS [ID] -- Return the primary key values to indicate we successfully deleted the record
END
GO
GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueComment] TO [cdp_Developer], [cdp_Integration];

/* spDelete Permissions for MJ_BizApps_Issues: Issue Comments */

GRANT EXECUTE ON [${flyway:defaultSchema}].[spDeleteIssueComment] TO [cdp_Developer], [cdp_Integration];

/* SQL text to delete unneeded entity fields (1 scoped entities) */
EXEC [${mjSchema}].[spDeleteUnneededEntityFields] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks', @EntityIDs='7124A46D-EA35-4C8B-BBBB-F19287ED0F9B';

/* SQL text to update existing entity fields from schema (1 scoped entities) */
EXEC [${mjSchema}].[spUpdateExistingEntityFieldsFromSchema] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks', @EntityIDs='7124A46D-EA35-4C8B-BBBB-F19287ED0F9B';

/* SQL text to set default column width where needed */
EXEC [${mjSchema}].[spSetDefaultColumnWidthWhereNeeded] @ExcludedSchemaNames='sys,staging,dbo,${mjSchema},${mjSchema}_BizAppsCommon,${mjSchema}_BizAppsTasks';

