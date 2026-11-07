-- =============================================================================================
-- PostgreSQL counterpart of V202610231900__v1.4.x__Metadata_Sync.sql -- BizApps Issues v1.4.x Metadata_Sync
-- =============================================================================================
-- Same 14 records, same values, same order as the T-SQL file; see its header for what ships, what is
-- left out (the predictive-escalation ML metadata) and why.
--
-- HOW IT WAS MADE
--   * `mj sql-convert --from tsql --to postgres` (MJ CLI 6.1.6) on the push log, the core schema
--     written as `__mj` first so the converter does not skip the calls. Each record is a DO block
--     that calls the core function. spUpdateEntityField is called in whichever signature the host
--     has (jsonb or named parameters); spUpdateEntity takes more than 100 parameters, so on 6.1.x
--     it exists only as `spUpdateEntity(p_data JSONB)` and the blocks call that form.
--   * Core calls then use `${mjSchema}`, as the Common, Orders and Contracts seeds do. Unlike
--     V202606221300.pg.sql, nothing here writes this app's tables, so no direct INSERTs are needed.
--   * Every value matches the T-SQL file (577 assignments: strings verbatim, BIT 1/0 as TRUE/FALSE);
--     checked one by one.
--   * Every block was checked to parse and compile on postgres:16.
-- =============================================================================================

SET standard_conforming_strings = on;
-- ===================== Data (INSERT/UPDATE/DELETE) =====================

-- Save MJ: Entities (core SP call only)
DO $mj$
DECLARE
  p_ParentID_1eb09252 UUID;
  p_Name_1eb09252 VARCHAR(255);
  p_NameSuffix_1eb09252 VARCHAR(255);
  p_Description_1eb09252 TEXT;
  p_AutoUpdateDescription_1eb09252 BOOLEAN;
  p_BaseView_1eb09252 VARCHAR(255);
  p_BaseViewGenerated_1eb09252 BOOLEAN;
  p_VirtualEntity_1eb09252 BOOLEAN;
  p_TrackRecordChanges_1eb09252 BOOLEAN;
  p_AuditRecordAccess_1eb09252 BOOLEAN;
  p_AuditViewRuns_1eb09252 BOOLEAN;
  p_IncludeInAPI_1eb09252 BOOLEAN;
  p_AllowAllRowsAPI_1eb09252 BOOLEAN;
  p_AllowUpdateAPI_1eb09252 BOOLEAN;
  p_AllowCreateAPI_1eb09252 BOOLEAN;
  p_AllowDeleteAPI_1eb09252 BOOLEAN;
  p_CustomResolverAPI_1eb09252 BOOLEAN;
  p_AllowUserSearchAPI_1eb09252 BOOLEAN;
  p_FullTextSearchEnabled_1eb09252 BOOLEAN;
  p_FullTextCatalog_1eb09252 VARCHAR(255);
  p_FullTextCatalogGenerated_1eb09252 BOOLEAN;
  p_FullTextIndex_1eb09252 VARCHAR(255);
  p_FullTextIndexGenerated_1eb09252 BOOLEAN;
  p_FullTextSearchFunction_1eb09252 VARCHAR(255);
  p_FullTextSearchFunctionGenerated_1eb09252 BOOLEAN;
  p_UserViewMaxRows_1eb09252 INTEGER;
  p_spCreate_1eb09252 VARCHAR(255);
  p_spUpdate_1eb09252 VARCHAR(255);
  p_spDelete_1eb09252 VARCHAR(255);
  p_spCreateGenerated_1eb09252 BOOLEAN;
  p_spUpdateGenerated_1eb09252 BOOLEAN;
  p_spDeleteGenerated_1eb09252 BOOLEAN;
  p_CascadeDeletes_1eb09252 BOOLEAN;
  p_DeleteType_1eb09252 VARCHAR(10);
  p_AllowRecordMerge_1eb09252 BOOLEAN;
  p_spMatch_1eb09252 VARCHAR(255);
  p_RelationshipDefaultDisplayType_1eb09252 VARCHAR(20);
  p_UserFormGenerated_1eb09252 BOOLEAN;
  p_EntityObjectSubclassName_1eb09252 VARCHAR(255);
  p_EntityObjectSubclassImport_1eb09252 VARCHAR(255);
  p_PreferredCommunicationField_1eb09252 VARCHAR(255);
  p_Icon_1eb09252 VARCHAR(500);
  p_ScopeDefault_1eb09252 VARCHAR(100);
  p_RowsToPackWithSchema_1eb09252 VARCHAR(20);
  p_RowsToPackSampleMethod_1eb09252 VARCHAR(20);
  p_RowsToPackSampleCount_1eb09252 INTEGER;
  p_RowsToPackSampleOrder_1eb09252 TEXT;
  p_AutoRowCountFrequency_1eb09252 INTEGER;
  p_RowCount_1eb09252 BIGINT;
  p_RowCountRunAt_1eb09252 TIMESTAMPTZ;
  p_Status_1eb09252 VARCHAR(25);
  p_DisplayName_1eb09252 VARCHAR(255);
  p_AllowMultipleSubtypes_1eb09252 BOOLEAN;
  p_AutoUpdateFullTextSearch_1eb09252 BOOLEAN;
  p_AutoUpdateAllowUserSearchAPI_1eb09252 BOOLEAN;
  p_TrustServerCacheCompletely_1eb09252 BOOLEAN;
  p_SupportsGeoCoding_1eb09252 BOOLEAN;
  p_AutoUpdateSupportsGeoCoding_1eb09252 BOOLEAN;
  p_AllowCaching_1eb09252 BOOLEAN;
  p_DetectExternalChanges_1eb09252 BOOLEAN;
  p_ExternalDataSourceID_1eb09252 UUID;
  p_ExternalObjectName_1eb09252 VARCHAR(255);
  p_GeneratedBaseViewName_1eb09252 VARCHAR(255);
  p_AllowDirectSQLInsert_1eb09252 BOOLEAN;
  p_AllowDirectSQLUpdate_1eb09252 BOOLEAN;
  p_AllowDirectSQLDelete_1eb09252 BOOLEAN;
  p_Configuration_1eb09252 TEXT;
  p_SubtypeSelector_1eb09252 TEXT;
  p_EnableFieldLevelSecurity_1eb09252 BOOLEAN;
  p_ID_1eb09252 UUID;
BEGIN
  p_Name_1eb09252 := 'MJ_BizApps_Issues: Issues';
  p_Description_1eb09252 := 'The core case / ticket / feedback record. Carries reporter, polymorphic assignee (Person or AI Agent), and a polymorphic source (any record the issue is about). Spawns bizapps-tasks Tasks for the actual work via TaskLink.';
  p_AutoUpdateDescription_1eb09252 := TRUE;
  p_BaseView_1eb09252 := 'vwIssues';
  p_BaseViewGenerated_1eb09252 := FALSE;
  p_VirtualEntity_1eb09252 := FALSE;
  p_TrackRecordChanges_1eb09252 := TRUE;
  p_AuditRecordAccess_1eb09252 := FALSE;
  p_AuditViewRuns_1eb09252 := FALSE;
  p_IncludeInAPI_1eb09252 := TRUE;
  p_AllowAllRowsAPI_1eb09252 := FALSE;
  p_AllowUpdateAPI_1eb09252 := TRUE;
  p_AllowCreateAPI_1eb09252 := TRUE;
  p_AllowDeleteAPI_1eb09252 := TRUE;
  p_CustomResolverAPI_1eb09252 := FALSE;
  p_AllowUserSearchAPI_1eb09252 := TRUE;
  p_FullTextSearchEnabled_1eb09252 := FALSE;
  p_FullTextCatalogGenerated_1eb09252 := TRUE;
  p_FullTextIndexGenerated_1eb09252 := TRUE;
  p_FullTextSearchFunctionGenerated_1eb09252 := TRUE;
  p_UserViewMaxRows_1eb09252 := 1000;
  p_spCreateGenerated_1eb09252 := TRUE;
  p_spUpdateGenerated_1eb09252 := TRUE;
  p_spDeleteGenerated_1eb09252 := TRUE;
  p_CascadeDeletes_1eb09252 := FALSE;
  p_DeleteType_1eb09252 := 'Hard';
  p_AllowRecordMerge_1eb09252 := FALSE;
  p_RelationshipDefaultDisplayType_1eb09252 := 'Search';
  p_UserFormGenerated_1eb09252 := TRUE;
  p_Icon_1eb09252 := 'fa fa-bug';
  p_RowsToPackWithSchema_1eb09252 := 'None';
  p_RowsToPackSampleMethod_1eb09252 := 'random';
  p_RowsToPackSampleCount_1eb09252 := 0;
  p_Status_1eb09252 := 'Active';
  p_DisplayName_1eb09252 := 'Issues';
  p_AllowMultipleSubtypes_1eb09252 := FALSE;
  p_AutoUpdateFullTextSearch_1eb09252 := TRUE;
  p_AutoUpdateAllowUserSearchAPI_1eb09252 := FALSE;
  p_TrustServerCacheCompletely_1eb09252 := TRUE;
  p_SupportsGeoCoding_1eb09252 := FALSE;
  p_AutoUpdateSupportsGeoCoding_1eb09252 := TRUE;
  p_AllowCaching_1eb09252 := FALSE;
  p_DetectExternalChanges_1eb09252 := FALSE;
  p_GeneratedBaseViewName_1eb09252 := 'vwIssuesGenerated';
  p_AllowDirectSQLInsert_1eb09252 := FALSE;
  p_AllowDirectSQLUpdate_1eb09252 := FALSE;
  p_AllowDirectSQLDelete_1eb09252 := FALSE;
  p_Configuration_1eb09252 := '{
  "UI": {
    "Form": {
      "Layout": "left-nav",
      "RelatedRolePolicy": "smart",
      "PrimaryRelatedBudget": 6
    }
  }
}';
  p_EnableFieldLevelSecurity_1eb09252 := FALSE;
  p_ID_1eb09252 := '65E7DAD5-9930-4140-9A38-2184EB0097DA';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntity'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntity"(p_data := jsonb_build_object(
    'ParentID', p_ParentID_1eb09252,
    'Name', p_Name_1eb09252,
    'NameSuffix', p_NameSuffix_1eb09252,
    'Description', p_Description_1eb09252,
    'AutoUpdateDescription', p_AutoUpdateDescription_1eb09252,
    'BaseView', p_BaseView_1eb09252,
    'BaseViewGenerated', p_BaseViewGenerated_1eb09252,
    'VirtualEntity', p_VirtualEntity_1eb09252,
    'TrackRecordChanges', p_TrackRecordChanges_1eb09252,
    'AuditRecordAccess', p_AuditRecordAccess_1eb09252,
    'AuditViewRuns', p_AuditViewRuns_1eb09252,
    'IncludeInAPI', p_IncludeInAPI_1eb09252,
    'AllowAllRowsAPI', p_AllowAllRowsAPI_1eb09252,
    'AllowUpdateAPI', p_AllowUpdateAPI_1eb09252,
    'AllowCreateAPI', p_AllowCreateAPI_1eb09252,
    'AllowDeleteAPI', p_AllowDeleteAPI_1eb09252,
    'CustomResolverAPI', p_CustomResolverAPI_1eb09252,
    'AllowUserSearchAPI', p_AllowUserSearchAPI_1eb09252,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_1eb09252,
    'FullTextCatalog', p_FullTextCatalog_1eb09252,
    'FullTextCatalogGenerated', p_FullTextCatalogGenerated_1eb09252,
    'FullTextIndex', p_FullTextIndex_1eb09252,
    'FullTextIndexGenerated', p_FullTextIndexGenerated_1eb09252,
    'FullTextSearchFunction', p_FullTextSearchFunction_1eb09252,
    'FullTextSearchFunctionGenerated', p_FullTextSearchFunctionGenerated_1eb09252,
    'UserViewMaxRows', p_UserViewMaxRows_1eb09252,
    'spCreate', p_spCreate_1eb09252,
    'spUpdate', p_spUpdate_1eb09252,
    'spDelete', p_spDelete_1eb09252,
    'spCreateGenerated', p_spCreateGenerated_1eb09252,
    'spUpdateGenerated', p_spUpdateGenerated_1eb09252,
    'spDeleteGenerated', p_spDeleteGenerated_1eb09252,
    'CascadeDeletes', p_CascadeDeletes_1eb09252,
    'DeleteType', p_DeleteType_1eb09252,
    'AllowRecordMerge', p_AllowRecordMerge_1eb09252,
    'spMatch', p_spMatch_1eb09252,
    'RelationshipDefaultDisplayType', p_RelationshipDefaultDisplayType_1eb09252,
    'UserFormGenerated', p_UserFormGenerated_1eb09252,
    'EntityObjectSubclassName', p_EntityObjectSubclassName_1eb09252,
    'EntityObjectSubclassImport', p_EntityObjectSubclassImport_1eb09252,
    'PreferredCommunicationField', p_PreferredCommunicationField_1eb09252,
    'Icon', p_Icon_1eb09252,
    'ScopeDefault', p_ScopeDefault_1eb09252,
    'RowsToPackWithSchema', p_RowsToPackWithSchema_1eb09252,
    'RowsToPackSampleMethod', p_RowsToPackSampleMethod_1eb09252,
    'RowsToPackSampleCount', p_RowsToPackSampleCount_1eb09252,
    'RowsToPackSampleOrder', p_RowsToPackSampleOrder_1eb09252,
    'AutoRowCountFrequency', p_AutoRowCountFrequency_1eb09252,
    'RowCount', p_RowCount_1eb09252,
    'RowCountRunAt', p_RowCountRunAt_1eb09252
  ) ||
  jsonb_build_object(
    'Status', p_Status_1eb09252,
    'DisplayName', p_DisplayName_1eb09252,
    'AllowMultipleSubtypes', p_AllowMultipleSubtypes_1eb09252,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_1eb09252,
    'AutoUpdateAllowUserSearchAPI', p_AutoUpdateAllowUserSearchAPI_1eb09252,
    'TrustServerCacheCompletely', p_TrustServerCacheCompletely_1eb09252,
    'SupportsGeoCoding', p_SupportsGeoCoding_1eb09252,
    'AutoUpdateSupportsGeoCoding', p_AutoUpdateSupportsGeoCoding_1eb09252,
    'AllowCaching', p_AllowCaching_1eb09252,
    'DetectExternalChanges', p_DetectExternalChanges_1eb09252,
    'ExternalDataSourceID', p_ExternalDataSourceID_1eb09252,
    'ExternalObjectName', p_ExternalObjectName_1eb09252,
    'GeneratedBaseViewName', p_GeneratedBaseViewName_1eb09252,
    'AllowDirectSQLInsert', p_AllowDirectSQLInsert_1eb09252,
    'AllowDirectSQLUpdate', p_AllowDirectSQLUpdate_1eb09252,
    'AllowDirectSQLDelete', p_AllowDirectSQLDelete_1eb09252,
    'Configuration', p_Configuration_1eb09252,
    'SubtypeSelector', p_SubtypeSelector_1eb09252,
    'EnableFieldLevelSecurity', p_EnableFieldLevelSecurity_1eb09252,
    'ID', p_ID_1eb09252
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntity"(p_ParentID := p_ParentID_1eb09252, p_ParentID_Clear := TRUE, p_Name := p_Name_1eb09252, p_NameSuffix := p_NameSuffix_1eb09252, p_NameSuffix_Clear := TRUE, p_Description := p_Description_1eb09252, p_AutoUpdateDescription := p_AutoUpdateDescription_1eb09252, p_BaseView := p_BaseView_1eb09252, p_BaseViewGenerated := p_BaseViewGenerated_1eb09252, p_VirtualEntity := p_VirtualEntity_1eb09252, p_TrackRecordChanges := p_TrackRecordChanges_1eb09252, p_AuditRecordAccess := p_AuditRecordAccess_1eb09252, p_AuditViewRuns := p_AuditViewRuns_1eb09252, p_IncludeInAPI := p_IncludeInAPI_1eb09252, p_AllowAllRowsAPI := p_AllowAllRowsAPI_1eb09252, p_AllowUpdateAPI := p_AllowUpdateAPI_1eb09252, p_AllowCreateAPI := p_AllowCreateAPI_1eb09252, p_AllowDeleteAPI := p_AllowDeleteAPI_1eb09252, p_CustomResolverAPI := p_CustomResolverAPI_1eb09252, p_AllowUserSearchAPI := p_AllowUserSearchAPI_1eb09252, p_FullTextSearchEnabled := p_FullTextSearchEnabled_1eb09252, p_FullTextCatalog := p_FullTextCatalog_1eb09252, p_FullTextCatalog_Clear := TRUE, p_FullTextCatalogGenerated := p_FullTextCatalogGenerated_1eb09252, p_FullTextIndex := p_FullTextIndex_1eb09252, p_FullTextIndex_Clear := TRUE, p_FullTextIndexGenerated := p_FullTextIndexGenerated_1eb09252, p_FullTextSearchFunction := p_FullTextSearchFunction_1eb09252, p_FullTextSearchFunction_Clear := TRUE, p_FullTextSearchFunctionGenerated := p_FullTextSearchFunctionGenerated_1eb09252, p_UserViewMaxRows := p_UserViewMaxRows_1eb09252, p_spCreate := p_spCreate_1eb09252, p_spCreate_Clear := TRUE, p_spUpdate := p_spUpdate_1eb09252, p_spUpdate_Clear := TRUE, p_spDelete := p_spDelete_1eb09252, p_spDelete_Clear := TRUE, p_spCreateGenerated := p_spCreateGenerated_1eb09252, p_spUpdateGenerated := p_spUpdateGenerated_1eb09252, p_spDeleteGenerated := p_spDeleteGenerated_1eb09252, p_CascadeDeletes := p_CascadeDeletes_1eb09252, p_DeleteType := p_DeleteType_1eb09252, p_AllowRecordMerge := p_AllowRecordMerge_1eb09252, p_spMatch := p_spMatch_1eb09252, p_spMatch_Clear := TRUE, p_RelationshipDefaultDisplayType := p_RelationshipDefaultDisplayType_1eb09252, p_UserFormGenerated := p_UserFormGenerated_1eb09252, p_EntityObjectSubclassName := p_EntityObjectSubclassName_1eb09252, p_EntityObjectSubclassName_Clear := TRUE, p_EntityObjectSubclassImport := p_EntityObjectSubclassImport_1eb09252, p_EntityObjectSubclassImport_Clear := TRUE, p_PreferredCommunicationField := p_PreferredCommunicationField_1eb09252, p_PreferredCommunicationField_Clear := TRUE, p_Icon := p_Icon_1eb09252, p_ScopeDefault := p_ScopeDefault_1eb09252, p_ScopeDefault_Clear := TRUE, p_RowsToPackWithSchema := p_RowsToPackWithSchema_1eb09252, p_RowsToPackSampleMethod := p_RowsToPackSampleMethod_1eb09252, p_RowsToPackSampleCount := p_RowsToPackSampleCount_1eb09252, p_RowsToPackSampleOrder := p_RowsToPackSampleOrder_1eb09252, p_RowsToPackSampleOrder_Clear := TRUE, p_AutoRowCountFrequency := p_AutoRowCountFrequency_1eb09252, p_AutoRowCountFrequency_Clear := TRUE, p_RowCount := p_RowCount_1eb09252, p_RowCount_Clear := TRUE, p_RowCountRunAt := p_RowCountRunAt_1eb09252, p_RowCountRunAt_Clear := TRUE, p_Status := p_Status_1eb09252, p_DisplayName := p_DisplayName_1eb09252, p_AllowMultipleSubtypes := p_AllowMultipleSubtypes_1eb09252, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_1eb09252, p_AutoUpdateAllowUserSearchAPI := p_AutoUpdateAllowUserSearchAPI_1eb09252, p_TrustServerCacheCompletely := p_TrustServerCacheCompletely_1eb09252, p_SupportsGeoCoding := p_SupportsGeoCoding_1eb09252, p_AutoUpdateSupportsGeoCoding := p_AutoUpdateSupportsGeoCoding_1eb09252, p_AllowCaching := p_AllowCaching_1eb09252, p_DetectExternalChanges := p_DetectExternalChanges_1eb09252, p_ExternalDataSourceID := p_ExternalDataSourceID_1eb09252, p_ExternalDataSourceID_Clear := TRUE, p_ExternalObjectName := p_ExternalObjectName_1eb09252, p_ExternalObjectName_Clear := TRUE, p_GeneratedBaseViewName := p_GeneratedBaseViewName_1eb09252, p_AllowDirectSQLInsert := p_AllowDirectSQLInsert_1eb09252, p_AllowDirectSQLUpdate := p_AllowDirectSQLUpdate_1eb09252, p_AllowDirectSQLDelete := p_AllowDirectSQLDelete_1eb09252, p_Configuration := p_Configuration_1eb09252, p_SubtypeSelector := p_SubtypeSelector_1eb09252, p_SubtypeSelector_Clear := TRUE, p_EnableFieldLevelSecurity := p_EnableFieldLevelSecurity_1eb09252, p_ID := p_ID_1eb09252);
  END IF;
END $mj$;

-- Save MJ: Entities (core SP call only)
DO $mj$
DECLARE
  p_ParentID_cb776658 UUID;
  p_Name_cb776658 VARCHAR(255);
  p_NameSuffix_cb776658 VARCHAR(255);
  p_Description_cb776658 TEXT;
  p_AutoUpdateDescription_cb776658 BOOLEAN;
  p_BaseView_cb776658 VARCHAR(255);
  p_BaseViewGenerated_cb776658 BOOLEAN;
  p_VirtualEntity_cb776658 BOOLEAN;
  p_TrackRecordChanges_cb776658 BOOLEAN;
  p_AuditRecordAccess_cb776658 BOOLEAN;
  p_AuditViewRuns_cb776658 BOOLEAN;
  p_IncludeInAPI_cb776658 BOOLEAN;
  p_AllowAllRowsAPI_cb776658 BOOLEAN;
  p_AllowUpdateAPI_cb776658 BOOLEAN;
  p_AllowCreateAPI_cb776658 BOOLEAN;
  p_AllowDeleteAPI_cb776658 BOOLEAN;
  p_CustomResolverAPI_cb776658 BOOLEAN;
  p_AllowUserSearchAPI_cb776658 BOOLEAN;
  p_FullTextSearchEnabled_cb776658 BOOLEAN;
  p_FullTextCatalog_cb776658 VARCHAR(255);
  p_FullTextCatalogGenerated_cb776658 BOOLEAN;
  p_FullTextIndex_cb776658 VARCHAR(255);
  p_FullTextIndexGenerated_cb776658 BOOLEAN;
  p_FullTextSearchFunction_cb776658 VARCHAR(255);
  p_FullTextSearchFunctionGenerated_cb776658 BOOLEAN;
  p_UserViewMaxRows_cb776658 INTEGER;
  p_spCreate_cb776658 VARCHAR(255);
  p_spUpdate_cb776658 VARCHAR(255);
  p_spDelete_cb776658 VARCHAR(255);
  p_spCreateGenerated_cb776658 BOOLEAN;
  p_spUpdateGenerated_cb776658 BOOLEAN;
  p_spDeleteGenerated_cb776658 BOOLEAN;
  p_CascadeDeletes_cb776658 BOOLEAN;
  p_DeleteType_cb776658 VARCHAR(10);
  p_AllowRecordMerge_cb776658 BOOLEAN;
  p_spMatch_cb776658 VARCHAR(255);
  p_RelationshipDefaultDisplayType_cb776658 VARCHAR(20);
  p_UserFormGenerated_cb776658 BOOLEAN;
  p_EntityObjectSubclassName_cb776658 VARCHAR(255);
  p_EntityObjectSubclassImport_cb776658 VARCHAR(255);
  p_PreferredCommunicationField_cb776658 VARCHAR(255);
  p_Icon_cb776658 VARCHAR(500);
  p_ScopeDefault_cb776658 VARCHAR(100);
  p_RowsToPackWithSchema_cb776658 VARCHAR(20);
  p_RowsToPackSampleMethod_cb776658 VARCHAR(20);
  p_RowsToPackSampleCount_cb776658 INTEGER;
  p_RowsToPackSampleOrder_cb776658 TEXT;
  p_AutoRowCountFrequency_cb776658 INTEGER;
  p_RowCount_cb776658 BIGINT;
  p_RowCountRunAt_cb776658 TIMESTAMPTZ;
  p_Status_cb776658 VARCHAR(25);
  p_DisplayName_cb776658 VARCHAR(255);
  p_AllowMultipleSubtypes_cb776658 BOOLEAN;
  p_AutoUpdateFullTextSearch_cb776658 BOOLEAN;
  p_AutoUpdateAllowUserSearchAPI_cb776658 BOOLEAN;
  p_TrustServerCacheCompletely_cb776658 BOOLEAN;
  p_SupportsGeoCoding_cb776658 BOOLEAN;
  p_AutoUpdateSupportsGeoCoding_cb776658 BOOLEAN;
  p_AllowCaching_cb776658 BOOLEAN;
  p_DetectExternalChanges_cb776658 BOOLEAN;
  p_ExternalDataSourceID_cb776658 UUID;
  p_ExternalObjectName_cb776658 VARCHAR(255);
  p_GeneratedBaseViewName_cb776658 VARCHAR(255);
  p_AllowDirectSQLInsert_cb776658 BOOLEAN;
  p_AllowDirectSQLUpdate_cb776658 BOOLEAN;
  p_AllowDirectSQLDelete_cb776658 BOOLEAN;
  p_Configuration_cb776658 TEXT;
  p_SubtypeSelector_cb776658 TEXT;
  p_EnableFieldLevelSecurity_cb776658 BOOLEAN;
  p_ID_cb776658 UUID;
BEGIN
  p_Name_cb776658 := 'MJ_BizApps_Issues: Issue Types';
  p_Description_cb776658 := 'Lifecycle automation for a class of issue (Bug, Feature Request, Question, Feedback). Mirrors the bizapps-tasks TaskType action-hook pattern: On*ActionID columns point at core [Action] records fired at the matching lifecycle event.';
  p_AutoUpdateDescription_cb776658 := TRUE;
  p_BaseView_cb776658 := 'vwIssueTypes';
  p_BaseViewGenerated_cb776658 := TRUE;
  p_VirtualEntity_cb776658 := FALSE;
  p_TrackRecordChanges_cb776658 := TRUE;
  p_AuditRecordAccess_cb776658 := FALSE;
  p_AuditViewRuns_cb776658 := FALSE;
  p_IncludeInAPI_cb776658 := TRUE;
  p_AllowAllRowsAPI_cb776658 := FALSE;
  p_AllowUpdateAPI_cb776658 := TRUE;
  p_AllowCreateAPI_cb776658 := TRUE;
  p_AllowDeleteAPI_cb776658 := TRUE;
  p_CustomResolverAPI_cb776658 := FALSE;
  p_AllowUserSearchAPI_cb776658 := TRUE;
  p_FullTextSearchEnabled_cb776658 := FALSE;
  p_FullTextCatalogGenerated_cb776658 := TRUE;
  p_FullTextIndexGenerated_cb776658 := TRUE;
  p_FullTextSearchFunctionGenerated_cb776658 := TRUE;
  p_UserViewMaxRows_cb776658 := 1000;
  p_spCreateGenerated_cb776658 := TRUE;
  p_spUpdateGenerated_cb776658 := TRUE;
  p_spDeleteGenerated_cb776658 := TRUE;
  p_CascadeDeletes_cb776658 := FALSE;
  p_DeleteType_cb776658 := 'Hard';
  p_AllowRecordMerge_cb776658 := FALSE;
  p_RelationshipDefaultDisplayType_cb776658 := 'Search';
  p_UserFormGenerated_cb776658 := TRUE;
  p_RowsToPackWithSchema_cb776658 := 'None';
  p_RowsToPackSampleMethod_cb776658 := 'random';
  p_RowsToPackSampleCount_cb776658 := 0;
  p_Status_cb776658 := 'Active';
  p_DisplayName_cb776658 := 'Issue Types';
  p_AllowMultipleSubtypes_cb776658 := FALSE;
  p_AutoUpdateFullTextSearch_cb776658 := TRUE;
  p_AutoUpdateAllowUserSearchAPI_cb776658 := FALSE;
  p_TrustServerCacheCompletely_cb776658 := TRUE;
  p_SupportsGeoCoding_cb776658 := FALSE;
  p_AutoUpdateSupportsGeoCoding_cb776658 := TRUE;
  p_AllowCaching_cb776658 := FALSE;
  p_DetectExternalChanges_cb776658 := FALSE;
  p_AllowDirectSQLInsert_cb776658 := FALSE;
  p_AllowDirectSQLUpdate_cb776658 := FALSE;
  p_AllowDirectSQLDelete_cb776658 := FALSE;
  p_EnableFieldLevelSecurity_cb776658 := FALSE;
  p_ID_cb776658 := 'B08FB976-CC72-4DAC-B950-A5C86DD04267';
  PERFORM "${mjSchema}"."spUpdateEntity"(p_data := jsonb_build_object(
    'ParentID', p_ParentID_cb776658,
    'Name', p_Name_cb776658,
    'NameSuffix', p_NameSuffix_cb776658,
    'Description', p_Description_cb776658,
    'AutoUpdateDescription', p_AutoUpdateDescription_cb776658,
    'BaseView', p_BaseView_cb776658,
    'BaseViewGenerated', p_BaseViewGenerated_cb776658,
    'VirtualEntity', p_VirtualEntity_cb776658,
    'TrackRecordChanges', p_TrackRecordChanges_cb776658,
    'AuditRecordAccess', p_AuditRecordAccess_cb776658,
    'AuditViewRuns', p_AuditViewRuns_cb776658,
    'IncludeInAPI', p_IncludeInAPI_cb776658,
    'AllowAllRowsAPI', p_AllowAllRowsAPI_cb776658,
    'AllowUpdateAPI', p_AllowUpdateAPI_cb776658,
    'AllowCreateAPI', p_AllowCreateAPI_cb776658,
    'AllowDeleteAPI', p_AllowDeleteAPI_cb776658,
    'CustomResolverAPI', p_CustomResolverAPI_cb776658,
    'AllowUserSearchAPI', p_AllowUserSearchAPI_cb776658,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_cb776658,
    'FullTextCatalog', p_FullTextCatalog_cb776658,
    'FullTextCatalogGenerated', p_FullTextCatalogGenerated_cb776658,
    'FullTextIndex', p_FullTextIndex_cb776658,
    'FullTextIndexGenerated', p_FullTextIndexGenerated_cb776658,
    'FullTextSearchFunction', p_FullTextSearchFunction_cb776658,
    'FullTextSearchFunctionGenerated', p_FullTextSearchFunctionGenerated_cb776658,
    'UserViewMaxRows', p_UserViewMaxRows_cb776658,
    'spCreate', p_spCreate_cb776658,
    'spUpdate', p_spUpdate_cb776658,
    'spDelete', p_spDelete_cb776658,
    'spCreateGenerated', p_spCreateGenerated_cb776658,
    'spUpdateGenerated', p_spUpdateGenerated_cb776658,
    'spDeleteGenerated', p_spDeleteGenerated_cb776658,
    'CascadeDeletes', p_CascadeDeletes_cb776658,
    'DeleteType', p_DeleteType_cb776658,
    'AllowRecordMerge', p_AllowRecordMerge_cb776658,
    'spMatch', p_spMatch_cb776658,
    'RelationshipDefaultDisplayType', p_RelationshipDefaultDisplayType_cb776658,
    'UserFormGenerated', p_UserFormGenerated_cb776658,
    'EntityObjectSubclassName', p_EntityObjectSubclassName_cb776658,
    'EntityObjectSubclassImport', p_EntityObjectSubclassImport_cb776658,
    'PreferredCommunicationField', p_PreferredCommunicationField_cb776658,
    'Icon', p_Icon_cb776658,
    'ScopeDefault', p_ScopeDefault_cb776658,
    'RowsToPackWithSchema', p_RowsToPackWithSchema_cb776658,
    'RowsToPackSampleMethod', p_RowsToPackSampleMethod_cb776658,
    'RowsToPackSampleCount', p_RowsToPackSampleCount_cb776658,
    'RowsToPackSampleOrder', p_RowsToPackSampleOrder_cb776658,
    'AutoRowCountFrequency', p_AutoRowCountFrequency_cb776658,
    'RowCount', p_RowCount_cb776658,
    'RowCountRunAt', p_RowCountRunAt_cb776658
  ) ||
  jsonb_build_object(
    'Status', p_Status_cb776658,
    'DisplayName', p_DisplayName_cb776658,
    'AllowMultipleSubtypes', p_AllowMultipleSubtypes_cb776658,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_cb776658,
    'AutoUpdateAllowUserSearchAPI', p_AutoUpdateAllowUserSearchAPI_cb776658,
    'TrustServerCacheCompletely', p_TrustServerCacheCompletely_cb776658,
    'SupportsGeoCoding', p_SupportsGeoCoding_cb776658,
    'AutoUpdateSupportsGeoCoding', p_AutoUpdateSupportsGeoCoding_cb776658,
    'AllowCaching', p_AllowCaching_cb776658,
    'DetectExternalChanges', p_DetectExternalChanges_cb776658,
    'ExternalDataSourceID', p_ExternalDataSourceID_cb776658,
    'ExternalObjectName', p_ExternalObjectName_cb776658,
    'GeneratedBaseViewName', p_GeneratedBaseViewName_cb776658,
    'AllowDirectSQLInsert', p_AllowDirectSQLInsert_cb776658,
    'AllowDirectSQLUpdate', p_AllowDirectSQLUpdate_cb776658,
    'AllowDirectSQLDelete', p_AllowDirectSQLDelete_cb776658,
    'Configuration', p_Configuration_cb776658,
    'SubtypeSelector', p_SubtypeSelector_cb776658,
    'EnableFieldLevelSecurity', p_EnableFieldLevelSecurity_cb776658,
    'ID', p_ID_cb776658
  ));
END $mj$;

-- Save MJ: Entities (core SP call only)
DO $mj$
DECLARE
  p_ParentID_f9712ed4 UUID;
  p_Name_f9712ed4 VARCHAR(255);
  p_NameSuffix_f9712ed4 VARCHAR(255);
  p_Description_f9712ed4 TEXT;
  p_AutoUpdateDescription_f9712ed4 BOOLEAN;
  p_BaseView_f9712ed4 VARCHAR(255);
  p_BaseViewGenerated_f9712ed4 BOOLEAN;
  p_VirtualEntity_f9712ed4 BOOLEAN;
  p_TrackRecordChanges_f9712ed4 BOOLEAN;
  p_AuditRecordAccess_f9712ed4 BOOLEAN;
  p_AuditViewRuns_f9712ed4 BOOLEAN;
  p_IncludeInAPI_f9712ed4 BOOLEAN;
  p_AllowAllRowsAPI_f9712ed4 BOOLEAN;
  p_AllowUpdateAPI_f9712ed4 BOOLEAN;
  p_AllowCreateAPI_f9712ed4 BOOLEAN;
  p_AllowDeleteAPI_f9712ed4 BOOLEAN;
  p_CustomResolverAPI_f9712ed4 BOOLEAN;
  p_AllowUserSearchAPI_f9712ed4 BOOLEAN;
  p_FullTextSearchEnabled_f9712ed4 BOOLEAN;
  p_FullTextCatalog_f9712ed4 VARCHAR(255);
  p_FullTextCatalogGenerated_f9712ed4 BOOLEAN;
  p_FullTextIndex_f9712ed4 VARCHAR(255);
  p_FullTextIndexGenerated_f9712ed4 BOOLEAN;
  p_FullTextSearchFunction_f9712ed4 VARCHAR(255);
  p_FullTextSearchFunctionGenerated_f9712ed4 BOOLEAN;
  p_UserViewMaxRows_f9712ed4 INTEGER;
  p_spCreate_f9712ed4 VARCHAR(255);
  p_spUpdate_f9712ed4 VARCHAR(255);
  p_spDelete_f9712ed4 VARCHAR(255);
  p_spCreateGenerated_f9712ed4 BOOLEAN;
  p_spUpdateGenerated_f9712ed4 BOOLEAN;
  p_spDeleteGenerated_f9712ed4 BOOLEAN;
  p_CascadeDeletes_f9712ed4 BOOLEAN;
  p_DeleteType_f9712ed4 VARCHAR(10);
  p_AllowRecordMerge_f9712ed4 BOOLEAN;
  p_spMatch_f9712ed4 VARCHAR(255);
  p_RelationshipDefaultDisplayType_f9712ed4 VARCHAR(20);
  p_UserFormGenerated_f9712ed4 BOOLEAN;
  p_EntityObjectSubclassName_f9712ed4 VARCHAR(255);
  p_EntityObjectSubclassImport_f9712ed4 VARCHAR(255);
  p_PreferredCommunicationField_f9712ed4 VARCHAR(255);
  p_Icon_f9712ed4 VARCHAR(500);
  p_ScopeDefault_f9712ed4 VARCHAR(100);
  p_RowsToPackWithSchema_f9712ed4 VARCHAR(20);
  p_RowsToPackSampleMethod_f9712ed4 VARCHAR(20);
  p_RowsToPackSampleCount_f9712ed4 INTEGER;
  p_RowsToPackSampleOrder_f9712ed4 TEXT;
  p_AutoRowCountFrequency_f9712ed4 INTEGER;
  p_RowCount_f9712ed4 BIGINT;
  p_RowCountRunAt_f9712ed4 TIMESTAMPTZ;
  p_Status_f9712ed4 VARCHAR(25);
  p_DisplayName_f9712ed4 VARCHAR(255);
  p_AllowMultipleSubtypes_f9712ed4 BOOLEAN;
  p_AutoUpdateFullTextSearch_f9712ed4 BOOLEAN;
  p_AutoUpdateAllowUserSearchAPI_f9712ed4 BOOLEAN;
  p_TrustServerCacheCompletely_f9712ed4 BOOLEAN;
  p_SupportsGeoCoding_f9712ed4 BOOLEAN;
  p_AutoUpdateSupportsGeoCoding_f9712ed4 BOOLEAN;
  p_AllowCaching_f9712ed4 BOOLEAN;
  p_DetectExternalChanges_f9712ed4 BOOLEAN;
  p_ExternalDataSourceID_f9712ed4 UUID;
  p_ExternalObjectName_f9712ed4 VARCHAR(255);
  p_GeneratedBaseViewName_f9712ed4 VARCHAR(255);
  p_AllowDirectSQLInsert_f9712ed4 BOOLEAN;
  p_AllowDirectSQLUpdate_f9712ed4 BOOLEAN;
  p_AllowDirectSQLDelete_f9712ed4 BOOLEAN;
  p_Configuration_f9712ed4 TEXT;
  p_SubtypeSelector_f9712ed4 TEXT;
  p_EnableFieldLevelSecurity_f9712ed4 BOOLEAN;
  p_ID_f9712ed4 UUID;
BEGIN
  p_Name_f9712ed4 := 'MJ_BizApps_Issues: Issue Status';
  p_Description_f9712ed4 := 'Workflow state an Issue can be in (New, Triaged, In Progress, Resolved, Closed, ...). Seeded via metadata sync, not in this migration. Drives board columns.';
  p_AutoUpdateDescription_f9712ed4 := TRUE;
  p_BaseView_f9712ed4 := 'vwIssueStatus';
  p_BaseViewGenerated_f9712ed4 := TRUE;
  p_VirtualEntity_f9712ed4 := FALSE;
  p_TrackRecordChanges_f9712ed4 := TRUE;
  p_AuditRecordAccess_f9712ed4 := FALSE;
  p_AuditViewRuns_f9712ed4 := FALSE;
  p_IncludeInAPI_f9712ed4 := TRUE;
  p_AllowAllRowsAPI_f9712ed4 := FALSE;
  p_AllowUpdateAPI_f9712ed4 := TRUE;
  p_AllowCreateAPI_f9712ed4 := TRUE;
  p_AllowDeleteAPI_f9712ed4 := TRUE;
  p_CustomResolverAPI_f9712ed4 := FALSE;
  p_AllowUserSearchAPI_f9712ed4 := TRUE;
  p_FullTextSearchEnabled_f9712ed4 := FALSE;
  p_FullTextCatalogGenerated_f9712ed4 := TRUE;
  p_FullTextIndexGenerated_f9712ed4 := TRUE;
  p_FullTextSearchFunctionGenerated_f9712ed4 := TRUE;
  p_UserViewMaxRows_f9712ed4 := 1000;
  p_spCreateGenerated_f9712ed4 := TRUE;
  p_spUpdateGenerated_f9712ed4 := TRUE;
  p_spDeleteGenerated_f9712ed4 := TRUE;
  p_CascadeDeletes_f9712ed4 := FALSE;
  p_DeleteType_f9712ed4 := 'Hard';
  p_AllowRecordMerge_f9712ed4 := FALSE;
  p_RelationshipDefaultDisplayType_f9712ed4 := 'Search';
  p_UserFormGenerated_f9712ed4 := TRUE;
  p_RowsToPackWithSchema_f9712ed4 := 'None';
  p_RowsToPackSampleMethod_f9712ed4 := 'random';
  p_RowsToPackSampleCount_f9712ed4 := 0;
  p_Status_f9712ed4 := 'Active';
  p_DisplayName_f9712ed4 := 'Issue Status';
  p_AllowMultipleSubtypes_f9712ed4 := FALSE;
  p_AutoUpdateFullTextSearch_f9712ed4 := TRUE;
  p_AutoUpdateAllowUserSearchAPI_f9712ed4 := FALSE;
  p_TrustServerCacheCompletely_f9712ed4 := TRUE;
  p_SupportsGeoCoding_f9712ed4 := FALSE;
  p_AutoUpdateSupportsGeoCoding_f9712ed4 := TRUE;
  p_AllowCaching_f9712ed4 := FALSE;
  p_DetectExternalChanges_f9712ed4 := FALSE;
  p_AllowDirectSQLInsert_f9712ed4 := FALSE;
  p_AllowDirectSQLUpdate_f9712ed4 := FALSE;
  p_AllowDirectSQLDelete_f9712ed4 := FALSE;
  p_EnableFieldLevelSecurity_f9712ed4 := FALSE;
  p_ID_f9712ed4 := '07E2BD79-BA8A-4B9C-8D45-4EA3A9922DE4';
  PERFORM "${mjSchema}"."spUpdateEntity"(p_data := jsonb_build_object(
    'ParentID', p_ParentID_f9712ed4,
    'Name', p_Name_f9712ed4,
    'NameSuffix', p_NameSuffix_f9712ed4,
    'Description', p_Description_f9712ed4,
    'AutoUpdateDescription', p_AutoUpdateDescription_f9712ed4,
    'BaseView', p_BaseView_f9712ed4,
    'BaseViewGenerated', p_BaseViewGenerated_f9712ed4,
    'VirtualEntity', p_VirtualEntity_f9712ed4,
    'TrackRecordChanges', p_TrackRecordChanges_f9712ed4,
    'AuditRecordAccess', p_AuditRecordAccess_f9712ed4,
    'AuditViewRuns', p_AuditViewRuns_f9712ed4,
    'IncludeInAPI', p_IncludeInAPI_f9712ed4,
    'AllowAllRowsAPI', p_AllowAllRowsAPI_f9712ed4,
    'AllowUpdateAPI', p_AllowUpdateAPI_f9712ed4,
    'AllowCreateAPI', p_AllowCreateAPI_f9712ed4,
    'AllowDeleteAPI', p_AllowDeleteAPI_f9712ed4,
    'CustomResolverAPI', p_CustomResolverAPI_f9712ed4,
    'AllowUserSearchAPI', p_AllowUserSearchAPI_f9712ed4,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_f9712ed4,
    'FullTextCatalog', p_FullTextCatalog_f9712ed4,
    'FullTextCatalogGenerated', p_FullTextCatalogGenerated_f9712ed4,
    'FullTextIndex', p_FullTextIndex_f9712ed4,
    'FullTextIndexGenerated', p_FullTextIndexGenerated_f9712ed4,
    'FullTextSearchFunction', p_FullTextSearchFunction_f9712ed4,
    'FullTextSearchFunctionGenerated', p_FullTextSearchFunctionGenerated_f9712ed4,
    'UserViewMaxRows', p_UserViewMaxRows_f9712ed4,
    'spCreate', p_spCreate_f9712ed4,
    'spUpdate', p_spUpdate_f9712ed4,
    'spDelete', p_spDelete_f9712ed4,
    'spCreateGenerated', p_spCreateGenerated_f9712ed4,
    'spUpdateGenerated', p_spUpdateGenerated_f9712ed4,
    'spDeleteGenerated', p_spDeleteGenerated_f9712ed4,
    'CascadeDeletes', p_CascadeDeletes_f9712ed4,
    'DeleteType', p_DeleteType_f9712ed4,
    'AllowRecordMerge', p_AllowRecordMerge_f9712ed4,
    'spMatch', p_spMatch_f9712ed4,
    'RelationshipDefaultDisplayType', p_RelationshipDefaultDisplayType_f9712ed4,
    'UserFormGenerated', p_UserFormGenerated_f9712ed4,
    'EntityObjectSubclassName', p_EntityObjectSubclassName_f9712ed4,
    'EntityObjectSubclassImport', p_EntityObjectSubclassImport_f9712ed4,
    'PreferredCommunicationField', p_PreferredCommunicationField_f9712ed4,
    'Icon', p_Icon_f9712ed4,
    'ScopeDefault', p_ScopeDefault_f9712ed4,
    'RowsToPackWithSchema', p_RowsToPackWithSchema_f9712ed4,
    'RowsToPackSampleMethod', p_RowsToPackSampleMethod_f9712ed4,
    'RowsToPackSampleCount', p_RowsToPackSampleCount_f9712ed4,
    'RowsToPackSampleOrder', p_RowsToPackSampleOrder_f9712ed4,
    'AutoRowCountFrequency', p_AutoRowCountFrequency_f9712ed4,
    'RowCount', p_RowCount_f9712ed4,
    'RowCountRunAt', p_RowCountRunAt_f9712ed4
  ) ||
  jsonb_build_object(
    'Status', p_Status_f9712ed4,
    'DisplayName', p_DisplayName_f9712ed4,
    'AllowMultipleSubtypes', p_AllowMultipleSubtypes_f9712ed4,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_f9712ed4,
    'AutoUpdateAllowUserSearchAPI', p_AutoUpdateAllowUserSearchAPI_f9712ed4,
    'TrustServerCacheCompletely', p_TrustServerCacheCompletely_f9712ed4,
    'SupportsGeoCoding', p_SupportsGeoCoding_f9712ed4,
    'AutoUpdateSupportsGeoCoding', p_AutoUpdateSupportsGeoCoding_f9712ed4,
    'AllowCaching', p_AllowCaching_f9712ed4,
    'DetectExternalChanges', p_DetectExternalChanges_f9712ed4,
    'ExternalDataSourceID', p_ExternalDataSourceID_f9712ed4,
    'ExternalObjectName', p_ExternalObjectName_f9712ed4,
    'GeneratedBaseViewName', p_GeneratedBaseViewName_f9712ed4,
    'AllowDirectSQLInsert', p_AllowDirectSQLInsert_f9712ed4,
    'AllowDirectSQLUpdate', p_AllowDirectSQLUpdate_f9712ed4,
    'AllowDirectSQLDelete', p_AllowDirectSQLDelete_f9712ed4,
    'Configuration', p_Configuration_f9712ed4,
    'SubtypeSelector', p_SubtypeSelector_f9712ed4,
    'EnableFieldLevelSecurity', p_EnableFieldLevelSecurity_f9712ed4,
    'ID', p_ID_f9712ed4
  ));
END $mj$;

-- Save MJ: Entities (core SP call only)
DO $mj$
DECLARE
  p_ParentID_2d52079a UUID;
  p_Name_2d52079a VARCHAR(255);
  p_NameSuffix_2d52079a VARCHAR(255);
  p_Description_2d52079a TEXT;
  p_AutoUpdateDescription_2d52079a BOOLEAN;
  p_BaseView_2d52079a VARCHAR(255);
  p_BaseViewGenerated_2d52079a BOOLEAN;
  p_VirtualEntity_2d52079a BOOLEAN;
  p_TrackRecordChanges_2d52079a BOOLEAN;
  p_AuditRecordAccess_2d52079a BOOLEAN;
  p_AuditViewRuns_2d52079a BOOLEAN;
  p_IncludeInAPI_2d52079a BOOLEAN;
  p_AllowAllRowsAPI_2d52079a BOOLEAN;
  p_AllowUpdateAPI_2d52079a BOOLEAN;
  p_AllowCreateAPI_2d52079a BOOLEAN;
  p_AllowDeleteAPI_2d52079a BOOLEAN;
  p_CustomResolverAPI_2d52079a BOOLEAN;
  p_AllowUserSearchAPI_2d52079a BOOLEAN;
  p_FullTextSearchEnabled_2d52079a BOOLEAN;
  p_FullTextCatalog_2d52079a VARCHAR(255);
  p_FullTextCatalogGenerated_2d52079a BOOLEAN;
  p_FullTextIndex_2d52079a VARCHAR(255);
  p_FullTextIndexGenerated_2d52079a BOOLEAN;
  p_FullTextSearchFunction_2d52079a VARCHAR(255);
  p_FullTextSearchFunctionGenerated_2d52079a BOOLEAN;
  p_UserViewMaxRows_2d52079a INTEGER;
  p_spCreate_2d52079a VARCHAR(255);
  p_spUpdate_2d52079a VARCHAR(255);
  p_spDelete_2d52079a VARCHAR(255);
  p_spCreateGenerated_2d52079a BOOLEAN;
  p_spUpdateGenerated_2d52079a BOOLEAN;
  p_spDeleteGenerated_2d52079a BOOLEAN;
  p_CascadeDeletes_2d52079a BOOLEAN;
  p_DeleteType_2d52079a VARCHAR(10);
  p_AllowRecordMerge_2d52079a BOOLEAN;
  p_spMatch_2d52079a VARCHAR(255);
  p_RelationshipDefaultDisplayType_2d52079a VARCHAR(20);
  p_UserFormGenerated_2d52079a BOOLEAN;
  p_EntityObjectSubclassName_2d52079a VARCHAR(255);
  p_EntityObjectSubclassImport_2d52079a VARCHAR(255);
  p_PreferredCommunicationField_2d52079a VARCHAR(255);
  p_Icon_2d52079a VARCHAR(500);
  p_ScopeDefault_2d52079a VARCHAR(100);
  p_RowsToPackWithSchema_2d52079a VARCHAR(20);
  p_RowsToPackSampleMethod_2d52079a VARCHAR(20);
  p_RowsToPackSampleCount_2d52079a INTEGER;
  p_RowsToPackSampleOrder_2d52079a TEXT;
  p_AutoRowCountFrequency_2d52079a INTEGER;
  p_RowCount_2d52079a BIGINT;
  p_RowCountRunAt_2d52079a TIMESTAMPTZ;
  p_Status_2d52079a VARCHAR(25);
  p_DisplayName_2d52079a VARCHAR(255);
  p_AllowMultipleSubtypes_2d52079a BOOLEAN;
  p_AutoUpdateFullTextSearch_2d52079a BOOLEAN;
  p_AutoUpdateAllowUserSearchAPI_2d52079a BOOLEAN;
  p_TrustServerCacheCompletely_2d52079a BOOLEAN;
  p_SupportsGeoCoding_2d52079a BOOLEAN;
  p_AutoUpdateSupportsGeoCoding_2d52079a BOOLEAN;
  p_AllowCaching_2d52079a BOOLEAN;
  p_DetectExternalChanges_2d52079a BOOLEAN;
  p_ExternalDataSourceID_2d52079a UUID;
  p_ExternalObjectName_2d52079a VARCHAR(255);
  p_GeneratedBaseViewName_2d52079a VARCHAR(255);
  p_AllowDirectSQLInsert_2d52079a BOOLEAN;
  p_AllowDirectSQLUpdate_2d52079a BOOLEAN;
  p_AllowDirectSQLDelete_2d52079a BOOLEAN;
  p_Configuration_2d52079a TEXT;
  p_SubtypeSelector_2d52079a TEXT;
  p_EnableFieldLevelSecurity_2d52079a BOOLEAN;
  p_ID_2d52079a UUID;
BEGIN
  p_Name_2d52079a := 'MJ_BizApps_Issues: Issue Comments';
  p_Description_2d52079a := 'Threaded discussion entry on an Issue. Author is a Person when internal; AuthorEmail carries the address for email / external sources.';
  p_AutoUpdateDescription_2d52079a := TRUE;
  p_BaseView_2d52079a := 'vwIssueComments';
  p_BaseViewGenerated_2d52079a := TRUE;
  p_VirtualEntity_2d52079a := FALSE;
  p_TrackRecordChanges_2d52079a := TRUE;
  p_AuditRecordAccess_2d52079a := FALSE;
  p_AuditViewRuns_2d52079a := FALSE;
  p_IncludeInAPI_2d52079a := TRUE;
  p_AllowAllRowsAPI_2d52079a := FALSE;
  p_AllowUpdateAPI_2d52079a := TRUE;
  p_AllowCreateAPI_2d52079a := TRUE;
  p_AllowDeleteAPI_2d52079a := TRUE;
  p_CustomResolverAPI_2d52079a := FALSE;
  p_AllowUserSearchAPI_2d52079a := FALSE;
  p_FullTextSearchEnabled_2d52079a := FALSE;
  p_FullTextCatalogGenerated_2d52079a := TRUE;
  p_FullTextIndexGenerated_2d52079a := TRUE;
  p_FullTextSearchFunctionGenerated_2d52079a := TRUE;
  p_UserViewMaxRows_2d52079a := 1000;
  p_spCreateGenerated_2d52079a := TRUE;
  p_spUpdateGenerated_2d52079a := TRUE;
  p_spDeleteGenerated_2d52079a := TRUE;
  p_CascadeDeletes_2d52079a := FALSE;
  p_DeleteType_2d52079a := 'Hard';
  p_AllowRecordMerge_2d52079a := FALSE;
  p_RelationshipDefaultDisplayType_2d52079a := 'Search';
  p_UserFormGenerated_2d52079a := TRUE;
  p_RowsToPackWithSchema_2d52079a := 'None';
  p_RowsToPackSampleMethod_2d52079a := 'random';
  p_RowsToPackSampleCount_2d52079a := 0;
  p_Status_2d52079a := 'Active';
  p_DisplayName_2d52079a := 'Issue Comments';
  p_AllowMultipleSubtypes_2d52079a := FALSE;
  p_AutoUpdateFullTextSearch_2d52079a := TRUE;
  p_AutoUpdateAllowUserSearchAPI_2d52079a := FALSE;
  p_TrustServerCacheCompletely_2d52079a := TRUE;
  p_SupportsGeoCoding_2d52079a := FALSE;
  p_AutoUpdateSupportsGeoCoding_2d52079a := TRUE;
  p_AllowCaching_2d52079a := FALSE;
  p_DetectExternalChanges_2d52079a := FALSE;
  p_AllowDirectSQLInsert_2d52079a := FALSE;
  p_AllowDirectSQLUpdate_2d52079a := FALSE;
  p_AllowDirectSQLDelete_2d52079a := FALSE;
  p_EnableFieldLevelSecurity_2d52079a := FALSE;
  p_ID_2d52079a := '7124A46D-EA35-4C8B-BBBB-F19287ED0F9B';
  PERFORM "${mjSchema}"."spUpdateEntity"(p_data := jsonb_build_object(
    'ParentID', p_ParentID_2d52079a,
    'Name', p_Name_2d52079a,
    'NameSuffix', p_NameSuffix_2d52079a,
    'Description', p_Description_2d52079a,
    'AutoUpdateDescription', p_AutoUpdateDescription_2d52079a,
    'BaseView', p_BaseView_2d52079a,
    'BaseViewGenerated', p_BaseViewGenerated_2d52079a,
    'VirtualEntity', p_VirtualEntity_2d52079a,
    'TrackRecordChanges', p_TrackRecordChanges_2d52079a,
    'AuditRecordAccess', p_AuditRecordAccess_2d52079a,
    'AuditViewRuns', p_AuditViewRuns_2d52079a,
    'IncludeInAPI', p_IncludeInAPI_2d52079a,
    'AllowAllRowsAPI', p_AllowAllRowsAPI_2d52079a,
    'AllowUpdateAPI', p_AllowUpdateAPI_2d52079a,
    'AllowCreateAPI', p_AllowCreateAPI_2d52079a,
    'AllowDeleteAPI', p_AllowDeleteAPI_2d52079a,
    'CustomResolverAPI', p_CustomResolverAPI_2d52079a,
    'AllowUserSearchAPI', p_AllowUserSearchAPI_2d52079a,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_2d52079a,
    'FullTextCatalog', p_FullTextCatalog_2d52079a,
    'FullTextCatalogGenerated', p_FullTextCatalogGenerated_2d52079a,
    'FullTextIndex', p_FullTextIndex_2d52079a,
    'FullTextIndexGenerated', p_FullTextIndexGenerated_2d52079a,
    'FullTextSearchFunction', p_FullTextSearchFunction_2d52079a,
    'FullTextSearchFunctionGenerated', p_FullTextSearchFunctionGenerated_2d52079a,
    'UserViewMaxRows', p_UserViewMaxRows_2d52079a,
    'spCreate', p_spCreate_2d52079a,
    'spUpdate', p_spUpdate_2d52079a,
    'spDelete', p_spDelete_2d52079a,
    'spCreateGenerated', p_spCreateGenerated_2d52079a,
    'spUpdateGenerated', p_spUpdateGenerated_2d52079a,
    'spDeleteGenerated', p_spDeleteGenerated_2d52079a,
    'CascadeDeletes', p_CascadeDeletes_2d52079a,
    'DeleteType', p_DeleteType_2d52079a,
    'AllowRecordMerge', p_AllowRecordMerge_2d52079a,
    'spMatch', p_spMatch_2d52079a,
    'RelationshipDefaultDisplayType', p_RelationshipDefaultDisplayType_2d52079a,
    'UserFormGenerated', p_UserFormGenerated_2d52079a,
    'EntityObjectSubclassName', p_EntityObjectSubclassName_2d52079a,
    'EntityObjectSubclassImport', p_EntityObjectSubclassImport_2d52079a,
    'PreferredCommunicationField', p_PreferredCommunicationField_2d52079a,
    'Icon', p_Icon_2d52079a,
    'ScopeDefault', p_ScopeDefault_2d52079a,
    'RowsToPackWithSchema', p_RowsToPackWithSchema_2d52079a,
    'RowsToPackSampleMethod', p_RowsToPackSampleMethod_2d52079a,
    'RowsToPackSampleCount', p_RowsToPackSampleCount_2d52079a,
    'RowsToPackSampleOrder', p_RowsToPackSampleOrder_2d52079a,
    'AutoRowCountFrequency', p_AutoRowCountFrequency_2d52079a,
    'RowCount', p_RowCount_2d52079a,
    'RowCountRunAt', p_RowCountRunAt_2d52079a
  ) ||
  jsonb_build_object(
    'Status', p_Status_2d52079a,
    'DisplayName', p_DisplayName_2d52079a,
    'AllowMultipleSubtypes', p_AllowMultipleSubtypes_2d52079a,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_2d52079a,
    'AutoUpdateAllowUserSearchAPI', p_AutoUpdateAllowUserSearchAPI_2d52079a,
    'TrustServerCacheCompletely', p_TrustServerCacheCompletely_2d52079a,
    'SupportsGeoCoding', p_SupportsGeoCoding_2d52079a,
    'AutoUpdateSupportsGeoCoding', p_AutoUpdateSupportsGeoCoding_2d52079a,
    'AllowCaching', p_AllowCaching_2d52079a,
    'DetectExternalChanges', p_DetectExternalChanges_2d52079a,
    'ExternalDataSourceID', p_ExternalDataSourceID_2d52079a,
    'ExternalObjectName', p_ExternalObjectName_2d52079a,
    'GeneratedBaseViewName', p_GeneratedBaseViewName_2d52079a,
    'AllowDirectSQLInsert', p_AllowDirectSQLInsert_2d52079a,
    'AllowDirectSQLUpdate', p_AllowDirectSQLUpdate_2d52079a,
    'AllowDirectSQLDelete', p_AllowDirectSQLDelete_2d52079a,
    'Configuration', p_Configuration_2d52079a,
    'SubtypeSelector', p_SubtypeSelector_2d52079a,
    'EnableFieldLevelSecurity', p_EnableFieldLevelSecurity_2d52079a,
    'ID', p_ID_2d52079a
  ));
END $mj$;

-- Save MJ: Entities (core SP call only)
DO $mj$
DECLARE
  p_ParentID_3542873d UUID;
  p_Name_3542873d VARCHAR(255);
  p_NameSuffix_3542873d VARCHAR(255);
  p_Description_3542873d TEXT;
  p_AutoUpdateDescription_3542873d BOOLEAN;
  p_BaseView_3542873d VARCHAR(255);
  p_BaseViewGenerated_3542873d BOOLEAN;
  p_VirtualEntity_3542873d BOOLEAN;
  p_TrackRecordChanges_3542873d BOOLEAN;
  p_AuditRecordAccess_3542873d BOOLEAN;
  p_AuditViewRuns_3542873d BOOLEAN;
  p_IncludeInAPI_3542873d BOOLEAN;
  p_AllowAllRowsAPI_3542873d BOOLEAN;
  p_AllowUpdateAPI_3542873d BOOLEAN;
  p_AllowCreateAPI_3542873d BOOLEAN;
  p_AllowDeleteAPI_3542873d BOOLEAN;
  p_CustomResolverAPI_3542873d BOOLEAN;
  p_AllowUserSearchAPI_3542873d BOOLEAN;
  p_FullTextSearchEnabled_3542873d BOOLEAN;
  p_FullTextCatalog_3542873d VARCHAR(255);
  p_FullTextCatalogGenerated_3542873d BOOLEAN;
  p_FullTextIndex_3542873d VARCHAR(255);
  p_FullTextIndexGenerated_3542873d BOOLEAN;
  p_FullTextSearchFunction_3542873d VARCHAR(255);
  p_FullTextSearchFunctionGenerated_3542873d BOOLEAN;
  p_UserViewMaxRows_3542873d INTEGER;
  p_spCreate_3542873d VARCHAR(255);
  p_spUpdate_3542873d VARCHAR(255);
  p_spDelete_3542873d VARCHAR(255);
  p_spCreateGenerated_3542873d BOOLEAN;
  p_spUpdateGenerated_3542873d BOOLEAN;
  p_spDeleteGenerated_3542873d BOOLEAN;
  p_CascadeDeletes_3542873d BOOLEAN;
  p_DeleteType_3542873d VARCHAR(10);
  p_AllowRecordMerge_3542873d BOOLEAN;
  p_spMatch_3542873d VARCHAR(255);
  p_RelationshipDefaultDisplayType_3542873d VARCHAR(20);
  p_UserFormGenerated_3542873d BOOLEAN;
  p_EntityObjectSubclassName_3542873d VARCHAR(255);
  p_EntityObjectSubclassImport_3542873d VARCHAR(255);
  p_PreferredCommunicationField_3542873d VARCHAR(255);
  p_Icon_3542873d VARCHAR(500);
  p_ScopeDefault_3542873d VARCHAR(100);
  p_RowsToPackWithSchema_3542873d VARCHAR(20);
  p_RowsToPackSampleMethod_3542873d VARCHAR(20);
  p_RowsToPackSampleCount_3542873d INTEGER;
  p_RowsToPackSampleOrder_3542873d TEXT;
  p_AutoRowCountFrequency_3542873d INTEGER;
  p_RowCount_3542873d BIGINT;
  p_RowCountRunAt_3542873d TIMESTAMPTZ;
  p_Status_3542873d VARCHAR(25);
  p_DisplayName_3542873d VARCHAR(255);
  p_AllowMultipleSubtypes_3542873d BOOLEAN;
  p_AutoUpdateFullTextSearch_3542873d BOOLEAN;
  p_AutoUpdateAllowUserSearchAPI_3542873d BOOLEAN;
  p_TrustServerCacheCompletely_3542873d BOOLEAN;
  p_SupportsGeoCoding_3542873d BOOLEAN;
  p_AutoUpdateSupportsGeoCoding_3542873d BOOLEAN;
  p_AllowCaching_3542873d BOOLEAN;
  p_DetectExternalChanges_3542873d BOOLEAN;
  p_ExternalDataSourceID_3542873d UUID;
  p_ExternalObjectName_3542873d VARCHAR(255);
  p_GeneratedBaseViewName_3542873d VARCHAR(255);
  p_AllowDirectSQLInsert_3542873d BOOLEAN;
  p_AllowDirectSQLUpdate_3542873d BOOLEAN;
  p_AllowDirectSQLDelete_3542873d BOOLEAN;
  p_Configuration_3542873d TEXT;
  p_SubtypeSelector_3542873d TEXT;
  p_EnableFieldLevelSecurity_3542873d BOOLEAN;
  p_ID_3542873d UUID;
BEGIN
  p_Name_3542873d := 'MJ_BizApps_Issues: Issue Number Sequences';
  p_Description_3542873d := 'Per-scope gap-free counter backing the human-readable Issue.IssueNumber. One row per normalized ScopeCode. Maintained ONLY by spAssignNextIssueNumber — never write directly.';
  p_AutoUpdateDescription_3542873d := TRUE;
  p_BaseView_3542873d := 'vwIssueNumberSequences';
  p_BaseViewGenerated_3542873d := TRUE;
  p_VirtualEntity_3542873d := FALSE;
  p_TrackRecordChanges_3542873d := TRUE;
  p_AuditRecordAccess_3542873d := FALSE;
  p_AuditViewRuns_3542873d := FALSE;
  p_IncludeInAPI_3542873d := TRUE;
  p_AllowAllRowsAPI_3542873d := FALSE;
  p_AllowUpdateAPI_3542873d := TRUE;
  p_AllowCreateAPI_3542873d := TRUE;
  p_AllowDeleteAPI_3542873d := TRUE;
  p_CustomResolverAPI_3542873d := FALSE;
  p_AllowUserSearchAPI_3542873d := FALSE;
  p_FullTextSearchEnabled_3542873d := FALSE;
  p_FullTextCatalogGenerated_3542873d := TRUE;
  p_FullTextIndexGenerated_3542873d := TRUE;
  p_FullTextSearchFunctionGenerated_3542873d := TRUE;
  p_UserViewMaxRows_3542873d := 1000;
  p_spCreateGenerated_3542873d := TRUE;
  p_spUpdateGenerated_3542873d := TRUE;
  p_spDeleteGenerated_3542873d := TRUE;
  p_CascadeDeletes_3542873d := FALSE;
  p_DeleteType_3542873d := 'Hard';
  p_AllowRecordMerge_3542873d := FALSE;
  p_RelationshipDefaultDisplayType_3542873d := 'Search';
  p_UserFormGenerated_3542873d := TRUE;
  p_RowsToPackWithSchema_3542873d := 'None';
  p_RowsToPackSampleMethod_3542873d := 'random';
  p_RowsToPackSampleCount_3542873d := 0;
  p_Status_3542873d := 'Active';
  p_DisplayName_3542873d := 'Issue Number Sequences';
  p_AllowMultipleSubtypes_3542873d := FALSE;
  p_AutoUpdateFullTextSearch_3542873d := TRUE;
  p_AutoUpdateAllowUserSearchAPI_3542873d := FALSE;
  p_TrustServerCacheCompletely_3542873d := TRUE;
  p_SupportsGeoCoding_3542873d := FALSE;
  p_AutoUpdateSupportsGeoCoding_3542873d := TRUE;
  p_AllowCaching_3542873d := FALSE;
  p_DetectExternalChanges_3542873d := FALSE;
  p_AllowDirectSQLInsert_3542873d := FALSE;
  p_AllowDirectSQLUpdate_3542873d := FALSE;
  p_AllowDirectSQLDelete_3542873d := FALSE;
  p_EnableFieldLevelSecurity_3542873d := FALSE;
  p_ID_3542873d := '595E3981-EE66-4B41-8579-2255A0C7610C';
  PERFORM "${mjSchema}"."spUpdateEntity"(p_data := jsonb_build_object(
    'ParentID', p_ParentID_3542873d,
    'Name', p_Name_3542873d,
    'NameSuffix', p_NameSuffix_3542873d,
    'Description', p_Description_3542873d,
    'AutoUpdateDescription', p_AutoUpdateDescription_3542873d,
    'BaseView', p_BaseView_3542873d,
    'BaseViewGenerated', p_BaseViewGenerated_3542873d,
    'VirtualEntity', p_VirtualEntity_3542873d,
    'TrackRecordChanges', p_TrackRecordChanges_3542873d,
    'AuditRecordAccess', p_AuditRecordAccess_3542873d,
    'AuditViewRuns', p_AuditViewRuns_3542873d,
    'IncludeInAPI', p_IncludeInAPI_3542873d,
    'AllowAllRowsAPI', p_AllowAllRowsAPI_3542873d,
    'AllowUpdateAPI', p_AllowUpdateAPI_3542873d,
    'AllowCreateAPI', p_AllowCreateAPI_3542873d,
    'AllowDeleteAPI', p_AllowDeleteAPI_3542873d,
    'CustomResolverAPI', p_CustomResolverAPI_3542873d,
    'AllowUserSearchAPI', p_AllowUserSearchAPI_3542873d,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_3542873d,
    'FullTextCatalog', p_FullTextCatalog_3542873d,
    'FullTextCatalogGenerated', p_FullTextCatalogGenerated_3542873d,
    'FullTextIndex', p_FullTextIndex_3542873d,
    'FullTextIndexGenerated', p_FullTextIndexGenerated_3542873d,
    'FullTextSearchFunction', p_FullTextSearchFunction_3542873d,
    'FullTextSearchFunctionGenerated', p_FullTextSearchFunctionGenerated_3542873d,
    'UserViewMaxRows', p_UserViewMaxRows_3542873d,
    'spCreate', p_spCreate_3542873d,
    'spUpdate', p_spUpdate_3542873d,
    'spDelete', p_spDelete_3542873d,
    'spCreateGenerated', p_spCreateGenerated_3542873d,
    'spUpdateGenerated', p_spUpdateGenerated_3542873d,
    'spDeleteGenerated', p_spDeleteGenerated_3542873d,
    'CascadeDeletes', p_CascadeDeletes_3542873d,
    'DeleteType', p_DeleteType_3542873d,
    'AllowRecordMerge', p_AllowRecordMerge_3542873d,
    'spMatch', p_spMatch_3542873d,
    'RelationshipDefaultDisplayType', p_RelationshipDefaultDisplayType_3542873d,
    'UserFormGenerated', p_UserFormGenerated_3542873d,
    'EntityObjectSubclassName', p_EntityObjectSubclassName_3542873d,
    'EntityObjectSubclassImport', p_EntityObjectSubclassImport_3542873d,
    'PreferredCommunicationField', p_PreferredCommunicationField_3542873d,
    'Icon', p_Icon_3542873d,
    'ScopeDefault', p_ScopeDefault_3542873d,
    'RowsToPackWithSchema', p_RowsToPackWithSchema_3542873d,
    'RowsToPackSampleMethod', p_RowsToPackSampleMethod_3542873d,
    'RowsToPackSampleCount', p_RowsToPackSampleCount_3542873d,
    'RowsToPackSampleOrder', p_RowsToPackSampleOrder_3542873d,
    'AutoRowCountFrequency', p_AutoRowCountFrequency_3542873d,
    'RowCount', p_RowCount_3542873d,
    'RowCountRunAt', p_RowCountRunAt_3542873d
  ) ||
  jsonb_build_object(
    'Status', p_Status_3542873d,
    'DisplayName', p_DisplayName_3542873d,
    'AllowMultipleSubtypes', p_AllowMultipleSubtypes_3542873d,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_3542873d,
    'AutoUpdateAllowUserSearchAPI', p_AutoUpdateAllowUserSearchAPI_3542873d,
    'TrustServerCacheCompletely', p_TrustServerCacheCompletely_3542873d,
    'SupportsGeoCoding', p_SupportsGeoCoding_3542873d,
    'AutoUpdateSupportsGeoCoding', p_AutoUpdateSupportsGeoCoding_3542873d,
    'AllowCaching', p_AllowCaching_3542873d,
    'DetectExternalChanges', p_DetectExternalChanges_3542873d,
    'ExternalDataSourceID', p_ExternalDataSourceID_3542873d,
    'ExternalObjectName', p_ExternalObjectName_3542873d,
    'GeneratedBaseViewName', p_GeneratedBaseViewName_3542873d,
    'AllowDirectSQLInsert', p_AllowDirectSQLInsert_3542873d,
    'AllowDirectSQLUpdate', p_AllowDirectSQLUpdate_3542873d,
    'AllowDirectSQLDelete', p_AllowDirectSQLDelete_3542873d,
    'Configuration', p_Configuration_3542873d,
    'SubtypeSelector', p_SubtypeSelector_3542873d,
    'EnableFieldLevelSecurity', p_EnableFieldLevelSecurity_3542873d,
    'ID', p_ID_3542873d
  ));
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_c99efdd0 VARCHAR(255);
  p_Description_c99efdd0 TEXT;
  p_AutoUpdateDescription_c99efdd0 BOOLEAN;
  p_IsPrimaryKey_c99efdd0 BOOLEAN;
  p_IsUnique_c99efdd0 BOOLEAN;
  p_Category_c99efdd0 VARCHAR(255);
  p_ValueListType_c99efdd0 VARCHAR(20);
  p_ExtendedType_c99efdd0 VARCHAR(50);
  p_CodeType_c99efdd0 VARCHAR(50);
  p_DefaultInView_c99efdd0 BOOLEAN;
  p_ViewCellTemplate_c99efdd0 TEXT;
  p_DefaultColumnWidth_c99efdd0 INTEGER;
  p_AllowUpdateAPI_c99efdd0 BOOLEAN;
  p_AllowUpdateInView_c99efdd0 BOOLEAN;
  p_IncludeInUserSearchAPI_c99efdd0 BOOLEAN;
  p_FullTextSearchEnabled_c99efdd0 BOOLEAN;
  p_UserSearchParamFormatAPI_c99efdd0 VARCHAR(500);
  p_IncludeInGeneratedForm_c99efdd0 BOOLEAN;
  p_GeneratedFormSection_c99efdd0 VARCHAR(10);
  p_IsNameField_c99efdd0 BOOLEAN;
  p_RelatedEntityID_c99efdd0 UUID;
  p_RelatedEntityFieldName_c99efdd0 VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_c99efdd0 BOOLEAN;
  p_RelatedEntityNameFieldMap_c99efdd0 VARCHAR(255);
  p_RelatedEntityDisplayType_c99efdd0 VARCHAR(20);
  p_EntityIDFieldName_c99efdd0 VARCHAR(100);
  p_ScopeDefault_c99efdd0 VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_c99efdd0 BOOLEAN;
  p_ValuesToPackWithSchema_c99efdd0 VARCHAR(10);
  p_Status_c99efdd0 VARCHAR(25);
  p_AutoUpdateIsNameField_c99efdd0 BOOLEAN;
  p_AutoUpdateDefaultInView_c99efdd0 BOOLEAN;
  p_AutoUpdateCategory_c99efdd0 BOOLEAN;
  p_AutoUpdateDisplayName_c99efdd0 BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_c99efdd0 BOOLEAN;
  p_Encrypt_c99efdd0 BOOLEAN;
  p_EncryptionKeyID_c99efdd0 UUID;
  p_AllowDecryptInAPI_c99efdd0 BOOLEAN;
  p_SendEncryptedValue_c99efdd0 BOOLEAN;
  p_IsSoftPrimaryKey_c99efdd0 BOOLEAN;
  p_IsSoftForeignKey_c99efdd0 BOOLEAN;
  p_RelatedEntityJoinFields_c99efdd0 TEXT;
  p_JSONType_c99efdd0 VARCHAR(255);
  p_JSONTypeIsArray_c99efdd0 BOOLEAN;
  p_JSONTypeDefinition_c99efdd0 TEXT;
  p_UserSearchPredicateAPI_c99efdd0 VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_c99efdd0 BOOLEAN;
  p_AutoUpdateFullTextSearch_c99efdd0 BOOLEAN;
  p_AutoUpdateExtendedType_c99efdd0 BOOLEAN;
  p_IsComputed_c99efdd0 BOOLEAN;
  p_EmbeddedRecord_c99efdd0 TEXT;
  p_Configuration_c99efdd0 TEXT;
  p_ID_c99efdd0 UUID;
BEGIN
  p_DisplayName_c99efdd0 := 'Issue Number';
  p_Description_c99efdd0 := 'Human-readable case identifier, format {SCOPE}-{seq} (e.g. ''MJC-42''), where SCOPE is the normalized (trim/UPPER) AppScope or ''ISS'' when none. Assigned once on insert by spAssignNextIssueNumber via IssueEntityServer; immutable thereafter. UNIQUE. Per-AppScope (globally sequential across orgs sharing a scope) — Izzy layers a separate per-org TKT-#### on top.';
  p_AutoUpdateDescription_c99efdd0 := TRUE;
  p_IsPrimaryKey_c99efdd0 := FALSE;
  p_IsUnique_c99efdd0 := TRUE;
  p_Category_c99efdd0 := 'Issue Overview';
  p_ValueListType_c99efdd0 := 'None';
  p_DefaultInView_c99efdd0 := FALSE;
  p_DefaultColumnWidth_c99efdd0 := 150;
  p_AllowUpdateAPI_c99efdd0 := TRUE;
  p_AllowUpdateInView_c99efdd0 := TRUE;
  p_IncludeInUserSearchAPI_c99efdd0 := TRUE;
  p_FullTextSearchEnabled_c99efdd0 := FALSE;
  p_IncludeInGeneratedForm_c99efdd0 := TRUE;
  p_GeneratedFormSection_c99efdd0 := 'Category';
  p_IsNameField_c99efdd0 := TRUE;
  p_IncludeRelatedEntityNameFieldInBaseView_c99efdd0 := FALSE;
  p_RelatedEntityDisplayType_c99efdd0 := 'Search';
  p_AutoUpdateRelatedEntityInfo_c99efdd0 := TRUE;
  p_ValuesToPackWithSchema_c99efdd0 := 'Auto';
  p_Status_c99efdd0 := 'Active';
  p_AutoUpdateIsNameField_c99efdd0 := TRUE;
  p_AutoUpdateDefaultInView_c99efdd0 := TRUE;
  p_AutoUpdateCategory_c99efdd0 := TRUE;
  p_AutoUpdateDisplayName_c99efdd0 := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_c99efdd0 := FALSE;
  p_Encrypt_c99efdd0 := FALSE;
  p_AllowDecryptInAPI_c99efdd0 := FALSE;
  p_SendEncryptedValue_c99efdd0 := FALSE;
  p_IsSoftPrimaryKey_c99efdd0 := FALSE;
  p_IsSoftForeignKey_c99efdd0 := FALSE;
  p_JSONTypeIsArray_c99efdd0 := FALSE;
  p_UserSearchPredicateAPI_c99efdd0 := 'Exact';
  p_AutoUpdateUserSearchPredicate_c99efdd0 := TRUE;
  p_AutoUpdateFullTextSearch_c99efdd0 := TRUE;
  p_AutoUpdateExtendedType_c99efdd0 := TRUE;
  p_IsComputed_c99efdd0 := FALSE;
  p_ID_c99efdd0 := 'ADDDCC67-6C31-4E40-8C22-AAAF2E9EB165';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_c99efdd0,
    'Description', p_Description_c99efdd0,
    'AutoUpdateDescription', p_AutoUpdateDescription_c99efdd0,
    'IsPrimaryKey', p_IsPrimaryKey_c99efdd0,
    'IsUnique', p_IsUnique_c99efdd0,
    'Category', p_Category_c99efdd0,
    'ValueListType', p_ValueListType_c99efdd0,
    'ExtendedType', p_ExtendedType_c99efdd0,
    'CodeType', p_CodeType_c99efdd0,
    'DefaultInView', p_DefaultInView_c99efdd0,
    'ViewCellTemplate', p_ViewCellTemplate_c99efdd0,
    'DefaultColumnWidth', p_DefaultColumnWidth_c99efdd0,
    'AllowUpdateAPI', p_AllowUpdateAPI_c99efdd0,
    'AllowUpdateInView', p_AllowUpdateInView_c99efdd0,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_c99efdd0,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_c99efdd0,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_c99efdd0,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_c99efdd0,
    'GeneratedFormSection', p_GeneratedFormSection_c99efdd0,
    'IsNameField', p_IsNameField_c99efdd0,
    'RelatedEntityID', p_RelatedEntityID_c99efdd0,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_c99efdd0,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_c99efdd0,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_c99efdd0,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_c99efdd0,
    'EntityIDFieldName', p_EntityIDFieldName_c99efdd0,
    'ScopeDefault', p_ScopeDefault_c99efdd0,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_c99efdd0,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_c99efdd0,
    'Status', p_Status_c99efdd0,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_c99efdd0,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_c99efdd0,
    'AutoUpdateCategory', p_AutoUpdateCategory_c99efdd0,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_c99efdd0,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_c99efdd0,
    'Encrypt', p_Encrypt_c99efdd0,
    'EncryptionKeyID', p_EncryptionKeyID_c99efdd0,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_c99efdd0,
    'SendEncryptedValue', p_SendEncryptedValue_c99efdd0,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_c99efdd0,
    'IsSoftForeignKey', p_IsSoftForeignKey_c99efdd0,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_c99efdd0,
    'JSONType', p_JSONType_c99efdd0,
    'JSONTypeIsArray', p_JSONTypeIsArray_c99efdd0,
    'JSONTypeDefinition', p_JSONTypeDefinition_c99efdd0,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_c99efdd0,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_c99efdd0,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_c99efdd0,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_c99efdd0,
    'IsComputed', p_IsComputed_c99efdd0
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_c99efdd0,
    'Configuration', p_Configuration_c99efdd0,
    'ID', p_ID_c99efdd0
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_c99efdd0, p_Description := p_Description_c99efdd0, p_AutoUpdateDescription := p_AutoUpdateDescription_c99efdd0, p_IsPrimaryKey := p_IsPrimaryKey_c99efdd0, p_IsUnique := p_IsUnique_c99efdd0, p_Category := p_Category_c99efdd0, p_ValueListType := p_ValueListType_c99efdd0, p_ExtendedType := p_ExtendedType_c99efdd0, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_c99efdd0, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_c99efdd0, p_ViewCellTemplate := p_ViewCellTemplate_c99efdd0, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_c99efdd0, p_AllowUpdateAPI := p_AllowUpdateAPI_c99efdd0, p_AllowUpdateInView := p_AllowUpdateInView_c99efdd0, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_c99efdd0, p_FullTextSearchEnabled := p_FullTextSearchEnabled_c99efdd0, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_c99efdd0, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_c99efdd0, p_GeneratedFormSection := p_GeneratedFormSection_c99efdd0, p_IsNameField := p_IsNameField_c99efdd0, p_RelatedEntityID := p_RelatedEntityID_c99efdd0, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_c99efdd0, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_c99efdd0, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_c99efdd0, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_c99efdd0, p_EntityIDFieldName := p_EntityIDFieldName_c99efdd0, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_c99efdd0, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_c99efdd0, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_c99efdd0, p_Status := p_Status_c99efdd0, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_c99efdd0, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_c99efdd0, p_AutoUpdateCategory := p_AutoUpdateCategory_c99efdd0, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_c99efdd0, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_c99efdd0, p_Encrypt := p_Encrypt_c99efdd0, p_EncryptionKeyID := p_EncryptionKeyID_c99efdd0, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_c99efdd0, p_SendEncryptedValue := p_SendEncryptedValue_c99efdd0, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_c99efdd0, p_IsSoftForeignKey := p_IsSoftForeignKey_c99efdd0, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_c99efdd0, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_c99efdd0, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_c99efdd0, p_JSONTypeDefinition := p_JSONTypeDefinition_c99efdd0, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_c99efdd0, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_c99efdd0, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_c99efdd0, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_c99efdd0, p_IsComputed := p_IsComputed_c99efdd0, p_EmbeddedRecord := p_EmbeddedRecord_c99efdd0, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_c99efdd0, p_Configuration_Clear := TRUE, p_ID := p_ID_c99efdd0);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_874a1598 VARCHAR(255);
  p_Description_874a1598 TEXT;
  p_AutoUpdateDescription_874a1598 BOOLEAN;
  p_IsPrimaryKey_874a1598 BOOLEAN;
  p_IsUnique_874a1598 BOOLEAN;
  p_Category_874a1598 VARCHAR(255);
  p_ValueListType_874a1598 VARCHAR(20);
  p_ExtendedType_874a1598 VARCHAR(50);
  p_CodeType_874a1598 VARCHAR(50);
  p_DefaultInView_874a1598 BOOLEAN;
  p_ViewCellTemplate_874a1598 TEXT;
  p_DefaultColumnWidth_874a1598 INTEGER;
  p_AllowUpdateAPI_874a1598 BOOLEAN;
  p_AllowUpdateInView_874a1598 BOOLEAN;
  p_IncludeInUserSearchAPI_874a1598 BOOLEAN;
  p_FullTextSearchEnabled_874a1598 BOOLEAN;
  p_UserSearchParamFormatAPI_874a1598 VARCHAR(500);
  p_IncludeInGeneratedForm_874a1598 BOOLEAN;
  p_GeneratedFormSection_874a1598 VARCHAR(10);
  p_IsNameField_874a1598 BOOLEAN;
  p_RelatedEntityID_874a1598 UUID;
  p_RelatedEntityFieldName_874a1598 VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_874a1598 BOOLEAN;
  p_RelatedEntityNameFieldMap_874a1598 VARCHAR(255);
  p_RelatedEntityDisplayType_874a1598 VARCHAR(20);
  p_EntityIDFieldName_874a1598 VARCHAR(100);
  p_ScopeDefault_874a1598 VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_874a1598 BOOLEAN;
  p_ValuesToPackWithSchema_874a1598 VARCHAR(10);
  p_Status_874a1598 VARCHAR(25);
  p_AutoUpdateIsNameField_874a1598 BOOLEAN;
  p_AutoUpdateDefaultInView_874a1598 BOOLEAN;
  p_AutoUpdateCategory_874a1598 BOOLEAN;
  p_AutoUpdateDisplayName_874a1598 BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_874a1598 BOOLEAN;
  p_Encrypt_874a1598 BOOLEAN;
  p_EncryptionKeyID_874a1598 UUID;
  p_AllowDecryptInAPI_874a1598 BOOLEAN;
  p_SendEncryptedValue_874a1598 BOOLEAN;
  p_IsSoftPrimaryKey_874a1598 BOOLEAN;
  p_IsSoftForeignKey_874a1598 BOOLEAN;
  p_RelatedEntityJoinFields_874a1598 TEXT;
  p_JSONType_874a1598 VARCHAR(255);
  p_JSONTypeIsArray_874a1598 BOOLEAN;
  p_JSONTypeDefinition_874a1598 TEXT;
  p_UserSearchPredicateAPI_874a1598 VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_874a1598 BOOLEAN;
  p_AutoUpdateFullTextSearch_874a1598 BOOLEAN;
  p_AutoUpdateExtendedType_874a1598 BOOLEAN;
  p_IsComputed_874a1598 BOOLEAN;
  p_EmbeddedRecord_874a1598 TEXT;
  p_Configuration_874a1598 TEXT;
  p_ID_874a1598 UUID;
BEGIN
  p_DisplayName_874a1598 := 'ID';
  p_Description_874a1598 := 'Unique identifier (UUID).';
  p_AutoUpdateDescription_874a1598 := TRUE;
  p_IsPrimaryKey_874a1598 := TRUE;
  p_IsUnique_874a1598 := TRUE;
  p_ValueListType_874a1598 := 'None';
  p_DefaultInView_874a1598 := FALSE;
  p_DefaultColumnWidth_874a1598 := 150;
  p_AllowUpdateAPI_874a1598 := FALSE;
  p_AllowUpdateInView_874a1598 := TRUE;
  p_IncludeInUserSearchAPI_874a1598 := FALSE;
  p_FullTextSearchEnabled_874a1598 := FALSE;
  p_IncludeInGeneratedForm_874a1598 := TRUE;
  p_GeneratedFormSection_874a1598 := 'Details';
  p_IsNameField_874a1598 := FALSE;
  p_IncludeRelatedEntityNameFieldInBaseView_874a1598 := FALSE;
  p_RelatedEntityDisplayType_874a1598 := 'Search';
  p_AutoUpdateRelatedEntityInfo_874a1598 := TRUE;
  p_ValuesToPackWithSchema_874a1598 := 'Auto';
  p_Status_874a1598 := 'Active';
  p_AutoUpdateIsNameField_874a1598 := TRUE;
  p_AutoUpdateDefaultInView_874a1598 := TRUE;
  p_AutoUpdateCategory_874a1598 := TRUE;
  p_AutoUpdateDisplayName_874a1598 := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_874a1598 := FALSE;
  p_Encrypt_874a1598 := FALSE;
  p_AllowDecryptInAPI_874a1598 := FALSE;
  p_SendEncryptedValue_874a1598 := FALSE;
  p_IsSoftPrimaryKey_874a1598 := FALSE;
  p_IsSoftForeignKey_874a1598 := FALSE;
  p_JSONTypeIsArray_874a1598 := FALSE;
  p_UserSearchPredicateAPI_874a1598 := 'Contains';
  p_AutoUpdateUserSearchPredicate_874a1598 := TRUE;
  p_AutoUpdateFullTextSearch_874a1598 := TRUE;
  p_AutoUpdateExtendedType_874a1598 := TRUE;
  p_IsComputed_874a1598 := FALSE;
  p_ID_874a1598 := 'D3CF7EAC-3527-47DD-87DD-DA8744CDA808';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_874a1598,
    'Description', p_Description_874a1598,
    'AutoUpdateDescription', p_AutoUpdateDescription_874a1598,
    'IsPrimaryKey', p_IsPrimaryKey_874a1598,
    'IsUnique', p_IsUnique_874a1598,
    'Category', p_Category_874a1598,
    'ValueListType', p_ValueListType_874a1598,
    'ExtendedType', p_ExtendedType_874a1598,
    'CodeType', p_CodeType_874a1598,
    'DefaultInView', p_DefaultInView_874a1598,
    'ViewCellTemplate', p_ViewCellTemplate_874a1598,
    'DefaultColumnWidth', p_DefaultColumnWidth_874a1598,
    'AllowUpdateAPI', p_AllowUpdateAPI_874a1598,
    'AllowUpdateInView', p_AllowUpdateInView_874a1598,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_874a1598,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_874a1598,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_874a1598,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_874a1598,
    'GeneratedFormSection', p_GeneratedFormSection_874a1598,
    'IsNameField', p_IsNameField_874a1598,
    'RelatedEntityID', p_RelatedEntityID_874a1598,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_874a1598,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_874a1598,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_874a1598,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_874a1598,
    'EntityIDFieldName', p_EntityIDFieldName_874a1598,
    'ScopeDefault', p_ScopeDefault_874a1598,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_874a1598,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_874a1598,
    'Status', p_Status_874a1598,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_874a1598,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_874a1598,
    'AutoUpdateCategory', p_AutoUpdateCategory_874a1598,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_874a1598,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_874a1598,
    'Encrypt', p_Encrypt_874a1598,
    'EncryptionKeyID', p_EncryptionKeyID_874a1598,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_874a1598,
    'SendEncryptedValue', p_SendEncryptedValue_874a1598,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_874a1598,
    'IsSoftForeignKey', p_IsSoftForeignKey_874a1598,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_874a1598,
    'JSONType', p_JSONType_874a1598,
    'JSONTypeIsArray', p_JSONTypeIsArray_874a1598,
    'JSONTypeDefinition', p_JSONTypeDefinition_874a1598,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_874a1598,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_874a1598,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_874a1598,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_874a1598,
    'IsComputed', p_IsComputed_874a1598
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_874a1598,
    'Configuration', p_Configuration_874a1598,
    'ID', p_ID_874a1598
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_874a1598, p_Description := p_Description_874a1598, p_AutoUpdateDescription := p_AutoUpdateDescription_874a1598, p_IsPrimaryKey := p_IsPrimaryKey_874a1598, p_IsUnique := p_IsUnique_874a1598, p_Category := p_Category_874a1598, p_Category_Clear := TRUE, p_ValueListType := p_ValueListType_874a1598, p_ExtendedType := p_ExtendedType_874a1598, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_874a1598, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_874a1598, p_ViewCellTemplate := p_ViewCellTemplate_874a1598, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_874a1598, p_AllowUpdateAPI := p_AllowUpdateAPI_874a1598, p_AllowUpdateInView := p_AllowUpdateInView_874a1598, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_874a1598, p_FullTextSearchEnabled := p_FullTextSearchEnabled_874a1598, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_874a1598, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_874a1598, p_GeneratedFormSection := p_GeneratedFormSection_874a1598, p_IsNameField := p_IsNameField_874a1598, p_RelatedEntityID := p_RelatedEntityID_874a1598, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_874a1598, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_874a1598, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_874a1598, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_874a1598, p_EntityIDFieldName := p_EntityIDFieldName_874a1598, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_874a1598, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_874a1598, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_874a1598, p_Status := p_Status_874a1598, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_874a1598, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_874a1598, p_AutoUpdateCategory := p_AutoUpdateCategory_874a1598, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_874a1598, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_874a1598, p_Encrypt := p_Encrypt_874a1598, p_EncryptionKeyID := p_EncryptionKeyID_874a1598, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_874a1598, p_SendEncryptedValue := p_SendEncryptedValue_874a1598, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_874a1598, p_IsSoftForeignKey := p_IsSoftForeignKey_874a1598, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_874a1598, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_874a1598, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_874a1598, p_JSONTypeDefinition := p_JSONTypeDefinition_874a1598, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_874a1598, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_874a1598, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_874a1598, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_874a1598, p_IsComputed := p_IsComputed_874a1598, p_EmbeddedRecord := p_EmbeddedRecord_874a1598, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_874a1598, p_Configuration_Clear := TRUE, p_ID := p_ID_874a1598);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_f8e90bf2 VARCHAR(255);
  p_Description_f8e90bf2 TEXT;
  p_AutoUpdateDescription_f8e90bf2 BOOLEAN;
  p_IsPrimaryKey_f8e90bf2 BOOLEAN;
  p_IsUnique_f8e90bf2 BOOLEAN;
  p_Category_f8e90bf2 VARCHAR(255);
  p_ValueListType_f8e90bf2 VARCHAR(20);
  p_ExtendedType_f8e90bf2 VARCHAR(50);
  p_CodeType_f8e90bf2 VARCHAR(50);
  p_DefaultInView_f8e90bf2 BOOLEAN;
  p_ViewCellTemplate_f8e90bf2 TEXT;
  p_DefaultColumnWidth_f8e90bf2 INTEGER;
  p_AllowUpdateAPI_f8e90bf2 BOOLEAN;
  p_AllowUpdateInView_f8e90bf2 BOOLEAN;
  p_IncludeInUserSearchAPI_f8e90bf2 BOOLEAN;
  p_FullTextSearchEnabled_f8e90bf2 BOOLEAN;
  p_UserSearchParamFormatAPI_f8e90bf2 VARCHAR(500);
  p_IncludeInGeneratedForm_f8e90bf2 BOOLEAN;
  p_GeneratedFormSection_f8e90bf2 VARCHAR(10);
  p_IsNameField_f8e90bf2 BOOLEAN;
  p_RelatedEntityID_f8e90bf2 UUID;
  p_RelatedEntityFieldName_f8e90bf2 VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_f8e90bf2 BOOLEAN;
  p_RelatedEntityNameFieldMap_f8e90bf2 VARCHAR(255);
  p_RelatedEntityDisplayType_f8e90bf2 VARCHAR(20);
  p_EntityIDFieldName_f8e90bf2 VARCHAR(100);
  p_ScopeDefault_f8e90bf2 VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_f8e90bf2 BOOLEAN;
  p_ValuesToPackWithSchema_f8e90bf2 VARCHAR(10);
  p_Status_f8e90bf2 VARCHAR(25);
  p_AutoUpdateIsNameField_f8e90bf2 BOOLEAN;
  p_AutoUpdateDefaultInView_f8e90bf2 BOOLEAN;
  p_AutoUpdateCategory_f8e90bf2 BOOLEAN;
  p_AutoUpdateDisplayName_f8e90bf2 BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_f8e90bf2 BOOLEAN;
  p_Encrypt_f8e90bf2 BOOLEAN;
  p_EncryptionKeyID_f8e90bf2 UUID;
  p_AllowDecryptInAPI_f8e90bf2 BOOLEAN;
  p_SendEncryptedValue_f8e90bf2 BOOLEAN;
  p_IsSoftPrimaryKey_f8e90bf2 BOOLEAN;
  p_IsSoftForeignKey_f8e90bf2 BOOLEAN;
  p_RelatedEntityJoinFields_f8e90bf2 TEXT;
  p_JSONType_f8e90bf2 VARCHAR(255);
  p_JSONTypeIsArray_f8e90bf2 BOOLEAN;
  p_JSONTypeDefinition_f8e90bf2 TEXT;
  p_UserSearchPredicateAPI_f8e90bf2 VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_f8e90bf2 BOOLEAN;
  p_AutoUpdateFullTextSearch_f8e90bf2 BOOLEAN;
  p_AutoUpdateExtendedType_f8e90bf2 BOOLEAN;
  p_IsComputed_f8e90bf2 BOOLEAN;
  p_EmbeddedRecord_f8e90bf2 TEXT;
  p_Configuration_f8e90bf2 TEXT;
  p_ID_f8e90bf2 UUID;
BEGIN
  p_DisplayName_f8e90bf2 := 'Name';
  p_Description_f8e90bf2 := 'Display name of the issue type (unique). E.g. ''Bug'', ''Feature Request''.';
  p_AutoUpdateDescription_f8e90bf2 := TRUE;
  p_IsPrimaryKey_f8e90bf2 := FALSE;
  p_IsUnique_f8e90bf2 := TRUE;
  p_ValueListType_f8e90bf2 := 'None';
  p_DefaultInView_f8e90bf2 := TRUE;
  p_DefaultColumnWidth_f8e90bf2 := 150;
  p_AllowUpdateAPI_f8e90bf2 := TRUE;
  p_AllowUpdateInView_f8e90bf2 := TRUE;
  p_IncludeInUserSearchAPI_f8e90bf2 := TRUE;
  p_FullTextSearchEnabled_f8e90bf2 := FALSE;
  p_IncludeInGeneratedForm_f8e90bf2 := TRUE;
  p_GeneratedFormSection_f8e90bf2 := 'Details';
  p_IsNameField_f8e90bf2 := TRUE;
  p_IncludeRelatedEntityNameFieldInBaseView_f8e90bf2 := FALSE;
  p_RelatedEntityDisplayType_f8e90bf2 := 'Search';
  p_AutoUpdateRelatedEntityInfo_f8e90bf2 := TRUE;
  p_ValuesToPackWithSchema_f8e90bf2 := 'Auto';
  p_Status_f8e90bf2 := 'Active';
  p_AutoUpdateIsNameField_f8e90bf2 := TRUE;
  p_AutoUpdateDefaultInView_f8e90bf2 := TRUE;
  p_AutoUpdateCategory_f8e90bf2 := TRUE;
  p_AutoUpdateDisplayName_f8e90bf2 := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_f8e90bf2 := FALSE;
  p_Encrypt_f8e90bf2 := FALSE;
  p_AllowDecryptInAPI_f8e90bf2 := FALSE;
  p_SendEncryptedValue_f8e90bf2 := FALSE;
  p_IsSoftPrimaryKey_f8e90bf2 := FALSE;
  p_IsSoftForeignKey_f8e90bf2 := FALSE;
  p_JSONTypeIsArray_f8e90bf2 := FALSE;
  p_UserSearchPredicateAPI_f8e90bf2 := 'BeginsWith';
  p_AutoUpdateUserSearchPredicate_f8e90bf2 := TRUE;
  p_AutoUpdateFullTextSearch_f8e90bf2 := TRUE;
  p_AutoUpdateExtendedType_f8e90bf2 := TRUE;
  p_IsComputed_f8e90bf2 := FALSE;
  p_ID_f8e90bf2 := '1B4A00A6-7843-49C4-93F3-D5C13272070B';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_f8e90bf2,
    'Description', p_Description_f8e90bf2,
    'AutoUpdateDescription', p_AutoUpdateDescription_f8e90bf2,
    'IsPrimaryKey', p_IsPrimaryKey_f8e90bf2,
    'IsUnique', p_IsUnique_f8e90bf2,
    'Category', p_Category_f8e90bf2,
    'ValueListType', p_ValueListType_f8e90bf2,
    'ExtendedType', p_ExtendedType_f8e90bf2,
    'CodeType', p_CodeType_f8e90bf2,
    'DefaultInView', p_DefaultInView_f8e90bf2,
    'ViewCellTemplate', p_ViewCellTemplate_f8e90bf2,
    'DefaultColumnWidth', p_DefaultColumnWidth_f8e90bf2,
    'AllowUpdateAPI', p_AllowUpdateAPI_f8e90bf2,
    'AllowUpdateInView', p_AllowUpdateInView_f8e90bf2,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_f8e90bf2,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_f8e90bf2,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_f8e90bf2,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_f8e90bf2,
    'GeneratedFormSection', p_GeneratedFormSection_f8e90bf2,
    'IsNameField', p_IsNameField_f8e90bf2,
    'RelatedEntityID', p_RelatedEntityID_f8e90bf2,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_f8e90bf2,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_f8e90bf2,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_f8e90bf2,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_f8e90bf2,
    'EntityIDFieldName', p_EntityIDFieldName_f8e90bf2,
    'ScopeDefault', p_ScopeDefault_f8e90bf2,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_f8e90bf2,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_f8e90bf2,
    'Status', p_Status_f8e90bf2,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_f8e90bf2,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_f8e90bf2,
    'AutoUpdateCategory', p_AutoUpdateCategory_f8e90bf2,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_f8e90bf2,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_f8e90bf2,
    'Encrypt', p_Encrypt_f8e90bf2,
    'EncryptionKeyID', p_EncryptionKeyID_f8e90bf2,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_f8e90bf2,
    'SendEncryptedValue', p_SendEncryptedValue_f8e90bf2,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_f8e90bf2,
    'IsSoftForeignKey', p_IsSoftForeignKey_f8e90bf2,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_f8e90bf2,
    'JSONType', p_JSONType_f8e90bf2,
    'JSONTypeIsArray', p_JSONTypeIsArray_f8e90bf2,
    'JSONTypeDefinition', p_JSONTypeDefinition_f8e90bf2,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_f8e90bf2,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_f8e90bf2,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_f8e90bf2,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_f8e90bf2,
    'IsComputed', p_IsComputed_f8e90bf2
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_f8e90bf2,
    'Configuration', p_Configuration_f8e90bf2,
    'ID', p_ID_f8e90bf2
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_f8e90bf2, p_Description := p_Description_f8e90bf2, p_AutoUpdateDescription := p_AutoUpdateDescription_f8e90bf2, p_IsPrimaryKey := p_IsPrimaryKey_f8e90bf2, p_IsUnique := p_IsUnique_f8e90bf2, p_Category := p_Category_f8e90bf2, p_Category_Clear := TRUE, p_ValueListType := p_ValueListType_f8e90bf2, p_ExtendedType := p_ExtendedType_f8e90bf2, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_f8e90bf2, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_f8e90bf2, p_ViewCellTemplate := p_ViewCellTemplate_f8e90bf2, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_f8e90bf2, p_AllowUpdateAPI := p_AllowUpdateAPI_f8e90bf2, p_AllowUpdateInView := p_AllowUpdateInView_f8e90bf2, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_f8e90bf2, p_FullTextSearchEnabled := p_FullTextSearchEnabled_f8e90bf2, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_f8e90bf2, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_f8e90bf2, p_GeneratedFormSection := p_GeneratedFormSection_f8e90bf2, p_IsNameField := p_IsNameField_f8e90bf2, p_RelatedEntityID := p_RelatedEntityID_f8e90bf2, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_f8e90bf2, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_f8e90bf2, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_f8e90bf2, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_f8e90bf2, p_EntityIDFieldName := p_EntityIDFieldName_f8e90bf2, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_f8e90bf2, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_f8e90bf2, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_f8e90bf2, p_Status := p_Status_f8e90bf2, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_f8e90bf2, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_f8e90bf2, p_AutoUpdateCategory := p_AutoUpdateCategory_f8e90bf2, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_f8e90bf2, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_f8e90bf2, p_Encrypt := p_Encrypt_f8e90bf2, p_EncryptionKeyID := p_EncryptionKeyID_f8e90bf2, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_f8e90bf2, p_SendEncryptedValue := p_SendEncryptedValue_f8e90bf2, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_f8e90bf2, p_IsSoftForeignKey := p_IsSoftForeignKey_f8e90bf2, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_f8e90bf2, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_f8e90bf2, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_f8e90bf2, p_JSONTypeDefinition := p_JSONTypeDefinition_f8e90bf2, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_f8e90bf2, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_f8e90bf2, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_f8e90bf2, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_f8e90bf2, p_IsComputed := p_IsComputed_f8e90bf2, p_EmbeddedRecord := p_EmbeddedRecord_f8e90bf2, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_f8e90bf2, p_Configuration_Clear := TRUE, p_ID := p_ID_f8e90bf2);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_b3645ac6 VARCHAR(255);
  p_Description_b3645ac6 TEXT;
  p_AutoUpdateDescription_b3645ac6 BOOLEAN;
  p_IsPrimaryKey_b3645ac6 BOOLEAN;
  p_IsUnique_b3645ac6 BOOLEAN;
  p_Category_b3645ac6 VARCHAR(255);
  p_ValueListType_b3645ac6 VARCHAR(20);
  p_ExtendedType_b3645ac6 VARCHAR(50);
  p_CodeType_b3645ac6 VARCHAR(50);
  p_DefaultInView_b3645ac6 BOOLEAN;
  p_ViewCellTemplate_b3645ac6 TEXT;
  p_DefaultColumnWidth_b3645ac6 INTEGER;
  p_AllowUpdateAPI_b3645ac6 BOOLEAN;
  p_AllowUpdateInView_b3645ac6 BOOLEAN;
  p_IncludeInUserSearchAPI_b3645ac6 BOOLEAN;
  p_FullTextSearchEnabled_b3645ac6 BOOLEAN;
  p_UserSearchParamFormatAPI_b3645ac6 VARCHAR(500);
  p_IncludeInGeneratedForm_b3645ac6 BOOLEAN;
  p_GeneratedFormSection_b3645ac6 VARCHAR(10);
  p_IsNameField_b3645ac6 BOOLEAN;
  p_RelatedEntityID_b3645ac6 UUID;
  p_RelatedEntityFieldName_b3645ac6 VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_b3645ac6 BOOLEAN;
  p_RelatedEntityNameFieldMap_b3645ac6 VARCHAR(255);
  p_RelatedEntityDisplayType_b3645ac6 VARCHAR(20);
  p_EntityIDFieldName_b3645ac6 VARCHAR(100);
  p_ScopeDefault_b3645ac6 VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_b3645ac6 BOOLEAN;
  p_ValuesToPackWithSchema_b3645ac6 VARCHAR(10);
  p_Status_b3645ac6 VARCHAR(25);
  p_AutoUpdateIsNameField_b3645ac6 BOOLEAN;
  p_AutoUpdateDefaultInView_b3645ac6 BOOLEAN;
  p_AutoUpdateCategory_b3645ac6 BOOLEAN;
  p_AutoUpdateDisplayName_b3645ac6 BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_b3645ac6 BOOLEAN;
  p_Encrypt_b3645ac6 BOOLEAN;
  p_EncryptionKeyID_b3645ac6 UUID;
  p_AllowDecryptInAPI_b3645ac6 BOOLEAN;
  p_SendEncryptedValue_b3645ac6 BOOLEAN;
  p_IsSoftPrimaryKey_b3645ac6 BOOLEAN;
  p_IsSoftForeignKey_b3645ac6 BOOLEAN;
  p_RelatedEntityJoinFields_b3645ac6 TEXT;
  p_JSONType_b3645ac6 VARCHAR(255);
  p_JSONTypeIsArray_b3645ac6 BOOLEAN;
  p_JSONTypeDefinition_b3645ac6 TEXT;
  p_UserSearchPredicateAPI_b3645ac6 VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_b3645ac6 BOOLEAN;
  p_AutoUpdateFullTextSearch_b3645ac6 BOOLEAN;
  p_AutoUpdateExtendedType_b3645ac6 BOOLEAN;
  p_IsComputed_b3645ac6 BOOLEAN;
  p_EmbeddedRecord_b3645ac6 TEXT;
  p_Configuration_b3645ac6 TEXT;
  p_ID_b3645ac6 UUID;
BEGIN
  p_DisplayName_b3645ac6 := 'ID';
  p_Description_b3645ac6 := 'Unique identifier (UUID).';
  p_AutoUpdateDescription_b3645ac6 := TRUE;
  p_IsPrimaryKey_b3645ac6 := TRUE;
  p_IsUnique_b3645ac6 := TRUE;
  p_ValueListType_b3645ac6 := 'None';
  p_DefaultInView_b3645ac6 := FALSE;
  p_DefaultColumnWidth_b3645ac6 := 150;
  p_AllowUpdateAPI_b3645ac6 := FALSE;
  p_AllowUpdateInView_b3645ac6 := TRUE;
  p_IncludeInUserSearchAPI_b3645ac6 := FALSE;
  p_FullTextSearchEnabled_b3645ac6 := FALSE;
  p_IncludeInGeneratedForm_b3645ac6 := TRUE;
  p_GeneratedFormSection_b3645ac6 := 'Details';
  p_IsNameField_b3645ac6 := FALSE;
  p_IncludeRelatedEntityNameFieldInBaseView_b3645ac6 := FALSE;
  p_RelatedEntityDisplayType_b3645ac6 := 'Search';
  p_AutoUpdateRelatedEntityInfo_b3645ac6 := TRUE;
  p_ValuesToPackWithSchema_b3645ac6 := 'Auto';
  p_Status_b3645ac6 := 'Active';
  p_AutoUpdateIsNameField_b3645ac6 := TRUE;
  p_AutoUpdateDefaultInView_b3645ac6 := TRUE;
  p_AutoUpdateCategory_b3645ac6 := TRUE;
  p_AutoUpdateDisplayName_b3645ac6 := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_b3645ac6 := FALSE;
  p_Encrypt_b3645ac6 := FALSE;
  p_AllowDecryptInAPI_b3645ac6 := FALSE;
  p_SendEncryptedValue_b3645ac6 := FALSE;
  p_IsSoftPrimaryKey_b3645ac6 := FALSE;
  p_IsSoftForeignKey_b3645ac6 := FALSE;
  p_JSONTypeIsArray_b3645ac6 := FALSE;
  p_UserSearchPredicateAPI_b3645ac6 := 'Contains';
  p_AutoUpdateUserSearchPredicate_b3645ac6 := TRUE;
  p_AutoUpdateFullTextSearch_b3645ac6 := TRUE;
  p_AutoUpdateExtendedType_b3645ac6 := TRUE;
  p_IsComputed_b3645ac6 := FALSE;
  p_ID_b3645ac6 := 'E6F9E9BB-4C8A-45B7-94DB-452B255DC1A1';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_b3645ac6,
    'Description', p_Description_b3645ac6,
    'AutoUpdateDescription', p_AutoUpdateDescription_b3645ac6,
    'IsPrimaryKey', p_IsPrimaryKey_b3645ac6,
    'IsUnique', p_IsUnique_b3645ac6,
    'Category', p_Category_b3645ac6,
    'ValueListType', p_ValueListType_b3645ac6,
    'ExtendedType', p_ExtendedType_b3645ac6,
    'CodeType', p_CodeType_b3645ac6,
    'DefaultInView', p_DefaultInView_b3645ac6,
    'ViewCellTemplate', p_ViewCellTemplate_b3645ac6,
    'DefaultColumnWidth', p_DefaultColumnWidth_b3645ac6,
    'AllowUpdateAPI', p_AllowUpdateAPI_b3645ac6,
    'AllowUpdateInView', p_AllowUpdateInView_b3645ac6,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_b3645ac6,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_b3645ac6,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_b3645ac6,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_b3645ac6,
    'GeneratedFormSection', p_GeneratedFormSection_b3645ac6,
    'IsNameField', p_IsNameField_b3645ac6,
    'RelatedEntityID', p_RelatedEntityID_b3645ac6,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_b3645ac6,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_b3645ac6,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_b3645ac6,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_b3645ac6,
    'EntityIDFieldName', p_EntityIDFieldName_b3645ac6,
    'ScopeDefault', p_ScopeDefault_b3645ac6,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_b3645ac6,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_b3645ac6,
    'Status', p_Status_b3645ac6,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_b3645ac6,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_b3645ac6,
    'AutoUpdateCategory', p_AutoUpdateCategory_b3645ac6,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_b3645ac6,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_b3645ac6,
    'Encrypt', p_Encrypt_b3645ac6,
    'EncryptionKeyID', p_EncryptionKeyID_b3645ac6,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_b3645ac6,
    'SendEncryptedValue', p_SendEncryptedValue_b3645ac6,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_b3645ac6,
    'IsSoftForeignKey', p_IsSoftForeignKey_b3645ac6,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_b3645ac6,
    'JSONType', p_JSONType_b3645ac6,
    'JSONTypeIsArray', p_JSONTypeIsArray_b3645ac6,
    'JSONTypeDefinition', p_JSONTypeDefinition_b3645ac6,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_b3645ac6,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_b3645ac6,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_b3645ac6,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_b3645ac6,
    'IsComputed', p_IsComputed_b3645ac6
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_b3645ac6,
    'Configuration', p_Configuration_b3645ac6,
    'ID', p_ID_b3645ac6
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_b3645ac6, p_Description := p_Description_b3645ac6, p_AutoUpdateDescription := p_AutoUpdateDescription_b3645ac6, p_IsPrimaryKey := p_IsPrimaryKey_b3645ac6, p_IsUnique := p_IsUnique_b3645ac6, p_Category := p_Category_b3645ac6, p_Category_Clear := TRUE, p_ValueListType := p_ValueListType_b3645ac6, p_ExtendedType := p_ExtendedType_b3645ac6, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_b3645ac6, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_b3645ac6, p_ViewCellTemplate := p_ViewCellTemplate_b3645ac6, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_b3645ac6, p_AllowUpdateAPI := p_AllowUpdateAPI_b3645ac6, p_AllowUpdateInView := p_AllowUpdateInView_b3645ac6, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_b3645ac6, p_FullTextSearchEnabled := p_FullTextSearchEnabled_b3645ac6, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_b3645ac6, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_b3645ac6, p_GeneratedFormSection := p_GeneratedFormSection_b3645ac6, p_IsNameField := p_IsNameField_b3645ac6, p_RelatedEntityID := p_RelatedEntityID_b3645ac6, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_b3645ac6, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_b3645ac6, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_b3645ac6, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_b3645ac6, p_EntityIDFieldName := p_EntityIDFieldName_b3645ac6, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_b3645ac6, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_b3645ac6, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_b3645ac6, p_Status := p_Status_b3645ac6, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_b3645ac6, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_b3645ac6, p_AutoUpdateCategory := p_AutoUpdateCategory_b3645ac6, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_b3645ac6, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_b3645ac6, p_Encrypt := p_Encrypt_b3645ac6, p_EncryptionKeyID := p_EncryptionKeyID_b3645ac6, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_b3645ac6, p_SendEncryptedValue := p_SendEncryptedValue_b3645ac6, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_b3645ac6, p_IsSoftForeignKey := p_IsSoftForeignKey_b3645ac6, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_b3645ac6, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_b3645ac6, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_b3645ac6, p_JSONTypeDefinition := p_JSONTypeDefinition_b3645ac6, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_b3645ac6, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_b3645ac6, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_b3645ac6, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_b3645ac6, p_IsComputed := p_IsComputed_b3645ac6, p_EmbeddedRecord := p_EmbeddedRecord_b3645ac6, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_b3645ac6, p_Configuration_Clear := TRUE, p_ID := p_ID_b3645ac6);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_d7c488ad VARCHAR(255);
  p_Description_d7c488ad TEXT;
  p_AutoUpdateDescription_d7c488ad BOOLEAN;
  p_IsPrimaryKey_d7c488ad BOOLEAN;
  p_IsUnique_d7c488ad BOOLEAN;
  p_Category_d7c488ad VARCHAR(255);
  p_ValueListType_d7c488ad VARCHAR(20);
  p_ExtendedType_d7c488ad VARCHAR(50);
  p_CodeType_d7c488ad VARCHAR(50);
  p_DefaultInView_d7c488ad BOOLEAN;
  p_ViewCellTemplate_d7c488ad TEXT;
  p_DefaultColumnWidth_d7c488ad INTEGER;
  p_AllowUpdateAPI_d7c488ad BOOLEAN;
  p_AllowUpdateInView_d7c488ad BOOLEAN;
  p_IncludeInUserSearchAPI_d7c488ad BOOLEAN;
  p_FullTextSearchEnabled_d7c488ad BOOLEAN;
  p_UserSearchParamFormatAPI_d7c488ad VARCHAR(500);
  p_IncludeInGeneratedForm_d7c488ad BOOLEAN;
  p_GeneratedFormSection_d7c488ad VARCHAR(10);
  p_IsNameField_d7c488ad BOOLEAN;
  p_RelatedEntityID_d7c488ad UUID;
  p_RelatedEntityFieldName_d7c488ad VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_d7c488ad BOOLEAN;
  p_RelatedEntityNameFieldMap_d7c488ad VARCHAR(255);
  p_RelatedEntityDisplayType_d7c488ad VARCHAR(20);
  p_EntityIDFieldName_d7c488ad VARCHAR(100);
  p_ScopeDefault_d7c488ad VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_d7c488ad BOOLEAN;
  p_ValuesToPackWithSchema_d7c488ad VARCHAR(10);
  p_Status_d7c488ad VARCHAR(25);
  p_AutoUpdateIsNameField_d7c488ad BOOLEAN;
  p_AutoUpdateDefaultInView_d7c488ad BOOLEAN;
  p_AutoUpdateCategory_d7c488ad BOOLEAN;
  p_AutoUpdateDisplayName_d7c488ad BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_d7c488ad BOOLEAN;
  p_Encrypt_d7c488ad BOOLEAN;
  p_EncryptionKeyID_d7c488ad UUID;
  p_AllowDecryptInAPI_d7c488ad BOOLEAN;
  p_SendEncryptedValue_d7c488ad BOOLEAN;
  p_IsSoftPrimaryKey_d7c488ad BOOLEAN;
  p_IsSoftForeignKey_d7c488ad BOOLEAN;
  p_RelatedEntityJoinFields_d7c488ad TEXT;
  p_JSONType_d7c488ad VARCHAR(255);
  p_JSONTypeIsArray_d7c488ad BOOLEAN;
  p_JSONTypeDefinition_d7c488ad TEXT;
  p_UserSearchPredicateAPI_d7c488ad VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_d7c488ad BOOLEAN;
  p_AutoUpdateFullTextSearch_d7c488ad BOOLEAN;
  p_AutoUpdateExtendedType_d7c488ad BOOLEAN;
  p_IsComputed_d7c488ad BOOLEAN;
  p_EmbeddedRecord_d7c488ad TEXT;
  p_Configuration_d7c488ad TEXT;
  p_ID_d7c488ad UUID;
BEGIN
  p_DisplayName_d7c488ad := 'Name';
  p_Description_d7c488ad := 'Display name of the status (unique). E.g. ''In Progress'', ''Resolved''.';
  p_AutoUpdateDescription_d7c488ad := TRUE;
  p_IsPrimaryKey_d7c488ad := FALSE;
  p_IsUnique_d7c488ad := TRUE;
  p_ValueListType_d7c488ad := 'None';
  p_DefaultInView_d7c488ad := TRUE;
  p_DefaultColumnWidth_d7c488ad := 150;
  p_AllowUpdateAPI_d7c488ad := TRUE;
  p_AllowUpdateInView_d7c488ad := TRUE;
  p_IncludeInUserSearchAPI_d7c488ad := TRUE;
  p_FullTextSearchEnabled_d7c488ad := FALSE;
  p_IncludeInGeneratedForm_d7c488ad := TRUE;
  p_GeneratedFormSection_d7c488ad := 'Details';
  p_IsNameField_d7c488ad := TRUE;
  p_IncludeRelatedEntityNameFieldInBaseView_d7c488ad := FALSE;
  p_RelatedEntityDisplayType_d7c488ad := 'Search';
  p_AutoUpdateRelatedEntityInfo_d7c488ad := TRUE;
  p_ValuesToPackWithSchema_d7c488ad := 'Auto';
  p_Status_d7c488ad := 'Active';
  p_AutoUpdateIsNameField_d7c488ad := TRUE;
  p_AutoUpdateDefaultInView_d7c488ad := TRUE;
  p_AutoUpdateCategory_d7c488ad := TRUE;
  p_AutoUpdateDisplayName_d7c488ad := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_d7c488ad := FALSE;
  p_Encrypt_d7c488ad := FALSE;
  p_AllowDecryptInAPI_d7c488ad := FALSE;
  p_SendEncryptedValue_d7c488ad := FALSE;
  p_IsSoftPrimaryKey_d7c488ad := FALSE;
  p_IsSoftForeignKey_d7c488ad := FALSE;
  p_JSONTypeIsArray_d7c488ad := FALSE;
  p_UserSearchPredicateAPI_d7c488ad := 'BeginsWith';
  p_AutoUpdateUserSearchPredicate_d7c488ad := TRUE;
  p_AutoUpdateFullTextSearch_d7c488ad := TRUE;
  p_AutoUpdateExtendedType_d7c488ad := TRUE;
  p_IsComputed_d7c488ad := FALSE;
  p_ID_d7c488ad := '71B2F634-7594-490A-9BFD-D130B8193C5E';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_d7c488ad,
    'Description', p_Description_d7c488ad,
    'AutoUpdateDescription', p_AutoUpdateDescription_d7c488ad,
    'IsPrimaryKey', p_IsPrimaryKey_d7c488ad,
    'IsUnique', p_IsUnique_d7c488ad,
    'Category', p_Category_d7c488ad,
    'ValueListType', p_ValueListType_d7c488ad,
    'ExtendedType', p_ExtendedType_d7c488ad,
    'CodeType', p_CodeType_d7c488ad,
    'DefaultInView', p_DefaultInView_d7c488ad,
    'ViewCellTemplate', p_ViewCellTemplate_d7c488ad,
    'DefaultColumnWidth', p_DefaultColumnWidth_d7c488ad,
    'AllowUpdateAPI', p_AllowUpdateAPI_d7c488ad,
    'AllowUpdateInView', p_AllowUpdateInView_d7c488ad,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_d7c488ad,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_d7c488ad,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_d7c488ad,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_d7c488ad,
    'GeneratedFormSection', p_GeneratedFormSection_d7c488ad,
    'IsNameField', p_IsNameField_d7c488ad,
    'RelatedEntityID', p_RelatedEntityID_d7c488ad,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_d7c488ad,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_d7c488ad,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_d7c488ad,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_d7c488ad,
    'EntityIDFieldName', p_EntityIDFieldName_d7c488ad,
    'ScopeDefault', p_ScopeDefault_d7c488ad,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_d7c488ad,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_d7c488ad,
    'Status', p_Status_d7c488ad,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_d7c488ad,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_d7c488ad,
    'AutoUpdateCategory', p_AutoUpdateCategory_d7c488ad,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_d7c488ad,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_d7c488ad,
    'Encrypt', p_Encrypt_d7c488ad,
    'EncryptionKeyID', p_EncryptionKeyID_d7c488ad,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_d7c488ad,
    'SendEncryptedValue', p_SendEncryptedValue_d7c488ad,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_d7c488ad,
    'IsSoftForeignKey', p_IsSoftForeignKey_d7c488ad,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_d7c488ad,
    'JSONType', p_JSONType_d7c488ad,
    'JSONTypeIsArray', p_JSONTypeIsArray_d7c488ad,
    'JSONTypeDefinition', p_JSONTypeDefinition_d7c488ad,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_d7c488ad,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_d7c488ad,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_d7c488ad,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_d7c488ad,
    'IsComputed', p_IsComputed_d7c488ad
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_d7c488ad,
    'Configuration', p_Configuration_d7c488ad,
    'ID', p_ID_d7c488ad
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_d7c488ad, p_Description := p_Description_d7c488ad, p_AutoUpdateDescription := p_AutoUpdateDescription_d7c488ad, p_IsPrimaryKey := p_IsPrimaryKey_d7c488ad, p_IsUnique := p_IsUnique_d7c488ad, p_Category := p_Category_d7c488ad, p_Category_Clear := TRUE, p_ValueListType := p_ValueListType_d7c488ad, p_ExtendedType := p_ExtendedType_d7c488ad, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_d7c488ad, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_d7c488ad, p_ViewCellTemplate := p_ViewCellTemplate_d7c488ad, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_d7c488ad, p_AllowUpdateAPI := p_AllowUpdateAPI_d7c488ad, p_AllowUpdateInView := p_AllowUpdateInView_d7c488ad, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_d7c488ad, p_FullTextSearchEnabled := p_FullTextSearchEnabled_d7c488ad, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_d7c488ad, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_d7c488ad, p_GeneratedFormSection := p_GeneratedFormSection_d7c488ad, p_IsNameField := p_IsNameField_d7c488ad, p_RelatedEntityID := p_RelatedEntityID_d7c488ad, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_d7c488ad, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_d7c488ad, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_d7c488ad, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_d7c488ad, p_EntityIDFieldName := p_EntityIDFieldName_d7c488ad, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_d7c488ad, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_d7c488ad, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_d7c488ad, p_Status := p_Status_d7c488ad, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_d7c488ad, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_d7c488ad, p_AutoUpdateCategory := p_AutoUpdateCategory_d7c488ad, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_d7c488ad, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_d7c488ad, p_Encrypt := p_Encrypt_d7c488ad, p_EncryptionKeyID := p_EncryptionKeyID_d7c488ad, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_d7c488ad, p_SendEncryptedValue := p_SendEncryptedValue_d7c488ad, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_d7c488ad, p_IsSoftForeignKey := p_IsSoftForeignKey_d7c488ad, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_d7c488ad, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_d7c488ad, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_d7c488ad, p_JSONTypeDefinition := p_JSONTypeDefinition_d7c488ad, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_d7c488ad, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_d7c488ad, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_d7c488ad, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_d7c488ad, p_IsComputed := p_IsComputed_d7c488ad, p_EmbeddedRecord := p_EmbeddedRecord_d7c488ad, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_d7c488ad, p_Configuration_Clear := TRUE, p_ID := p_ID_d7c488ad);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_32d0f9da VARCHAR(255);
  p_Description_32d0f9da TEXT;
  p_AutoUpdateDescription_32d0f9da BOOLEAN;
  p_IsPrimaryKey_32d0f9da BOOLEAN;
  p_IsUnique_32d0f9da BOOLEAN;
  p_Category_32d0f9da VARCHAR(255);
  p_ValueListType_32d0f9da VARCHAR(20);
  p_ExtendedType_32d0f9da VARCHAR(50);
  p_CodeType_32d0f9da VARCHAR(50);
  p_DefaultInView_32d0f9da BOOLEAN;
  p_ViewCellTemplate_32d0f9da TEXT;
  p_DefaultColumnWidth_32d0f9da INTEGER;
  p_AllowUpdateAPI_32d0f9da BOOLEAN;
  p_AllowUpdateInView_32d0f9da BOOLEAN;
  p_IncludeInUserSearchAPI_32d0f9da BOOLEAN;
  p_FullTextSearchEnabled_32d0f9da BOOLEAN;
  p_UserSearchParamFormatAPI_32d0f9da VARCHAR(500);
  p_IncludeInGeneratedForm_32d0f9da BOOLEAN;
  p_GeneratedFormSection_32d0f9da VARCHAR(10);
  p_IsNameField_32d0f9da BOOLEAN;
  p_RelatedEntityID_32d0f9da UUID;
  p_RelatedEntityFieldName_32d0f9da VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_32d0f9da BOOLEAN;
  p_RelatedEntityNameFieldMap_32d0f9da VARCHAR(255);
  p_RelatedEntityDisplayType_32d0f9da VARCHAR(20);
  p_EntityIDFieldName_32d0f9da VARCHAR(100);
  p_ScopeDefault_32d0f9da VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_32d0f9da BOOLEAN;
  p_ValuesToPackWithSchema_32d0f9da VARCHAR(10);
  p_Status_32d0f9da VARCHAR(25);
  p_AutoUpdateIsNameField_32d0f9da BOOLEAN;
  p_AutoUpdateDefaultInView_32d0f9da BOOLEAN;
  p_AutoUpdateCategory_32d0f9da BOOLEAN;
  p_AutoUpdateDisplayName_32d0f9da BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_32d0f9da BOOLEAN;
  p_Encrypt_32d0f9da BOOLEAN;
  p_EncryptionKeyID_32d0f9da UUID;
  p_AllowDecryptInAPI_32d0f9da BOOLEAN;
  p_SendEncryptedValue_32d0f9da BOOLEAN;
  p_IsSoftPrimaryKey_32d0f9da BOOLEAN;
  p_IsSoftForeignKey_32d0f9da BOOLEAN;
  p_RelatedEntityJoinFields_32d0f9da TEXT;
  p_JSONType_32d0f9da VARCHAR(255);
  p_JSONTypeIsArray_32d0f9da BOOLEAN;
  p_JSONTypeDefinition_32d0f9da TEXT;
  p_UserSearchPredicateAPI_32d0f9da VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_32d0f9da BOOLEAN;
  p_AutoUpdateFullTextSearch_32d0f9da BOOLEAN;
  p_AutoUpdateExtendedType_32d0f9da BOOLEAN;
  p_IsComputed_32d0f9da BOOLEAN;
  p_EmbeddedRecord_32d0f9da TEXT;
  p_Configuration_32d0f9da TEXT;
  p_ID_32d0f9da UUID;
BEGIN
  p_DisplayName_32d0f9da := 'ID';
  p_Description_32d0f9da := 'Unique identifier (UUID).';
  p_AutoUpdateDescription_32d0f9da := TRUE;
  p_IsPrimaryKey_32d0f9da := TRUE;
  p_IsUnique_32d0f9da := TRUE;
  p_ValueListType_32d0f9da := 'None';
  p_DefaultInView_32d0f9da := FALSE;
  p_DefaultColumnWidth_32d0f9da := 150;
  p_AllowUpdateAPI_32d0f9da := FALSE;
  p_AllowUpdateInView_32d0f9da := TRUE;
  p_IncludeInUserSearchAPI_32d0f9da := FALSE;
  p_FullTextSearchEnabled_32d0f9da := FALSE;
  p_IncludeInGeneratedForm_32d0f9da := TRUE;
  p_GeneratedFormSection_32d0f9da := 'Details';
  p_IsNameField_32d0f9da := FALSE;
  p_IncludeRelatedEntityNameFieldInBaseView_32d0f9da := FALSE;
  p_RelatedEntityDisplayType_32d0f9da := 'Search';
  p_AutoUpdateRelatedEntityInfo_32d0f9da := TRUE;
  p_ValuesToPackWithSchema_32d0f9da := 'Auto';
  p_Status_32d0f9da := 'Active';
  p_AutoUpdateIsNameField_32d0f9da := TRUE;
  p_AutoUpdateDefaultInView_32d0f9da := TRUE;
  p_AutoUpdateCategory_32d0f9da := TRUE;
  p_AutoUpdateDisplayName_32d0f9da := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_32d0f9da := FALSE;
  p_Encrypt_32d0f9da := FALSE;
  p_AllowDecryptInAPI_32d0f9da := FALSE;
  p_SendEncryptedValue_32d0f9da := FALSE;
  p_IsSoftPrimaryKey_32d0f9da := FALSE;
  p_IsSoftForeignKey_32d0f9da := FALSE;
  p_JSONTypeIsArray_32d0f9da := FALSE;
  p_UserSearchPredicateAPI_32d0f9da := 'Contains';
  p_AutoUpdateUserSearchPredicate_32d0f9da := TRUE;
  p_AutoUpdateFullTextSearch_32d0f9da := TRUE;
  p_AutoUpdateExtendedType_32d0f9da := TRUE;
  p_IsComputed_32d0f9da := FALSE;
  p_ID_32d0f9da := '53331D4B-D295-4DF9-A97B-9F63BCE62E71';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_32d0f9da,
    'Description', p_Description_32d0f9da,
    'AutoUpdateDescription', p_AutoUpdateDescription_32d0f9da,
    'IsPrimaryKey', p_IsPrimaryKey_32d0f9da,
    'IsUnique', p_IsUnique_32d0f9da,
    'Category', p_Category_32d0f9da,
    'ValueListType', p_ValueListType_32d0f9da,
    'ExtendedType', p_ExtendedType_32d0f9da,
    'CodeType', p_CodeType_32d0f9da,
    'DefaultInView', p_DefaultInView_32d0f9da,
    'ViewCellTemplate', p_ViewCellTemplate_32d0f9da,
    'DefaultColumnWidth', p_DefaultColumnWidth_32d0f9da,
    'AllowUpdateAPI', p_AllowUpdateAPI_32d0f9da,
    'AllowUpdateInView', p_AllowUpdateInView_32d0f9da,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_32d0f9da,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_32d0f9da,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_32d0f9da,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_32d0f9da,
    'GeneratedFormSection', p_GeneratedFormSection_32d0f9da,
    'IsNameField', p_IsNameField_32d0f9da,
    'RelatedEntityID', p_RelatedEntityID_32d0f9da,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_32d0f9da,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_32d0f9da,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_32d0f9da,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_32d0f9da,
    'EntityIDFieldName', p_EntityIDFieldName_32d0f9da,
    'ScopeDefault', p_ScopeDefault_32d0f9da,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_32d0f9da,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_32d0f9da,
    'Status', p_Status_32d0f9da,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_32d0f9da,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_32d0f9da,
    'AutoUpdateCategory', p_AutoUpdateCategory_32d0f9da,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_32d0f9da,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_32d0f9da,
    'Encrypt', p_Encrypt_32d0f9da,
    'EncryptionKeyID', p_EncryptionKeyID_32d0f9da,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_32d0f9da,
    'SendEncryptedValue', p_SendEncryptedValue_32d0f9da,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_32d0f9da,
    'IsSoftForeignKey', p_IsSoftForeignKey_32d0f9da,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_32d0f9da,
    'JSONType', p_JSONType_32d0f9da,
    'JSONTypeIsArray', p_JSONTypeIsArray_32d0f9da,
    'JSONTypeDefinition', p_JSONTypeDefinition_32d0f9da,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_32d0f9da,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_32d0f9da,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_32d0f9da,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_32d0f9da,
    'IsComputed', p_IsComputed_32d0f9da
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_32d0f9da,
    'Configuration', p_Configuration_32d0f9da,
    'ID', p_ID_32d0f9da
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_32d0f9da, p_Description := p_Description_32d0f9da, p_AutoUpdateDescription := p_AutoUpdateDescription_32d0f9da, p_IsPrimaryKey := p_IsPrimaryKey_32d0f9da, p_IsUnique := p_IsUnique_32d0f9da, p_Category := p_Category_32d0f9da, p_Category_Clear := TRUE, p_ValueListType := p_ValueListType_32d0f9da, p_ExtendedType := p_ExtendedType_32d0f9da, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_32d0f9da, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_32d0f9da, p_ViewCellTemplate := p_ViewCellTemplate_32d0f9da, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_32d0f9da, p_AllowUpdateAPI := p_AllowUpdateAPI_32d0f9da, p_AllowUpdateInView := p_AllowUpdateInView_32d0f9da, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_32d0f9da, p_FullTextSearchEnabled := p_FullTextSearchEnabled_32d0f9da, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_32d0f9da, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_32d0f9da, p_GeneratedFormSection := p_GeneratedFormSection_32d0f9da, p_IsNameField := p_IsNameField_32d0f9da, p_RelatedEntityID := p_RelatedEntityID_32d0f9da, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_32d0f9da, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_32d0f9da, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_32d0f9da, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_32d0f9da, p_EntityIDFieldName := p_EntityIDFieldName_32d0f9da, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_32d0f9da, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_32d0f9da, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_32d0f9da, p_Status := p_Status_32d0f9da, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_32d0f9da, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_32d0f9da, p_AutoUpdateCategory := p_AutoUpdateCategory_32d0f9da, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_32d0f9da, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_32d0f9da, p_Encrypt := p_Encrypt_32d0f9da, p_EncryptionKeyID := p_EncryptionKeyID_32d0f9da, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_32d0f9da, p_SendEncryptedValue := p_SendEncryptedValue_32d0f9da, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_32d0f9da, p_IsSoftForeignKey := p_IsSoftForeignKey_32d0f9da, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_32d0f9da, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_32d0f9da, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_32d0f9da, p_JSONTypeDefinition := p_JSONTypeDefinition_32d0f9da, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_32d0f9da, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_32d0f9da, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_32d0f9da, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_32d0f9da, p_IsComputed := p_IsComputed_32d0f9da, p_EmbeddedRecord := p_EmbeddedRecord_32d0f9da, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_32d0f9da, p_Configuration_Clear := TRUE, p_ID := p_ID_32d0f9da);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_bc4a9d7f VARCHAR(255);
  p_Description_bc4a9d7f TEXT;
  p_AutoUpdateDescription_bc4a9d7f BOOLEAN;
  p_IsPrimaryKey_bc4a9d7f BOOLEAN;
  p_IsUnique_bc4a9d7f BOOLEAN;
  p_Category_bc4a9d7f VARCHAR(255);
  p_ValueListType_bc4a9d7f VARCHAR(20);
  p_ExtendedType_bc4a9d7f VARCHAR(50);
  p_CodeType_bc4a9d7f VARCHAR(50);
  p_DefaultInView_bc4a9d7f BOOLEAN;
  p_ViewCellTemplate_bc4a9d7f TEXT;
  p_DefaultColumnWidth_bc4a9d7f INTEGER;
  p_AllowUpdateAPI_bc4a9d7f BOOLEAN;
  p_AllowUpdateInView_bc4a9d7f BOOLEAN;
  p_IncludeInUserSearchAPI_bc4a9d7f BOOLEAN;
  p_FullTextSearchEnabled_bc4a9d7f BOOLEAN;
  p_UserSearchParamFormatAPI_bc4a9d7f VARCHAR(500);
  p_IncludeInGeneratedForm_bc4a9d7f BOOLEAN;
  p_GeneratedFormSection_bc4a9d7f VARCHAR(10);
  p_IsNameField_bc4a9d7f BOOLEAN;
  p_RelatedEntityID_bc4a9d7f UUID;
  p_RelatedEntityFieldName_bc4a9d7f VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_bc4a9d7f BOOLEAN;
  p_RelatedEntityNameFieldMap_bc4a9d7f VARCHAR(255);
  p_RelatedEntityDisplayType_bc4a9d7f VARCHAR(20);
  p_EntityIDFieldName_bc4a9d7f VARCHAR(100);
  p_ScopeDefault_bc4a9d7f VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_bc4a9d7f BOOLEAN;
  p_ValuesToPackWithSchema_bc4a9d7f VARCHAR(10);
  p_Status_bc4a9d7f VARCHAR(25);
  p_AutoUpdateIsNameField_bc4a9d7f BOOLEAN;
  p_AutoUpdateDefaultInView_bc4a9d7f BOOLEAN;
  p_AutoUpdateCategory_bc4a9d7f BOOLEAN;
  p_AutoUpdateDisplayName_bc4a9d7f BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_bc4a9d7f BOOLEAN;
  p_Encrypt_bc4a9d7f BOOLEAN;
  p_EncryptionKeyID_bc4a9d7f UUID;
  p_AllowDecryptInAPI_bc4a9d7f BOOLEAN;
  p_SendEncryptedValue_bc4a9d7f BOOLEAN;
  p_IsSoftPrimaryKey_bc4a9d7f BOOLEAN;
  p_IsSoftForeignKey_bc4a9d7f BOOLEAN;
  p_RelatedEntityJoinFields_bc4a9d7f TEXT;
  p_JSONType_bc4a9d7f VARCHAR(255);
  p_JSONTypeIsArray_bc4a9d7f BOOLEAN;
  p_JSONTypeDefinition_bc4a9d7f TEXT;
  p_UserSearchPredicateAPI_bc4a9d7f VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_bc4a9d7f BOOLEAN;
  p_AutoUpdateFullTextSearch_bc4a9d7f BOOLEAN;
  p_AutoUpdateExtendedType_bc4a9d7f BOOLEAN;
  p_IsComputed_bc4a9d7f BOOLEAN;
  p_EmbeddedRecord_bc4a9d7f TEXT;
  p_Configuration_bc4a9d7f TEXT;
  p_ID_bc4a9d7f UUID;
BEGIN
  p_DisplayName_bc4a9d7f := 'Title';
  p_Description_bc4a9d7f := 'Short, one-line summary of the issue.';
  p_AutoUpdateDescription_bc4a9d7f := TRUE;
  p_IsPrimaryKey_bc4a9d7f := FALSE;
  p_IsUnique_bc4a9d7f := FALSE;
  p_Category_bc4a9d7f := 'Issue Overview';
  p_ValueListType_bc4a9d7f := 'None';
  p_DefaultInView_bc4a9d7f := FALSE;
  p_DefaultColumnWidth_bc4a9d7f := 150;
  p_AllowUpdateAPI_bc4a9d7f := TRUE;
  p_AllowUpdateInView_bc4a9d7f := TRUE;
  p_IncludeInUserSearchAPI_bc4a9d7f := TRUE;
  p_FullTextSearchEnabled_bc4a9d7f := FALSE;
  p_IncludeInGeneratedForm_bc4a9d7f := TRUE;
  p_GeneratedFormSection_bc4a9d7f := 'Category';
  p_IsNameField_bc4a9d7f := FALSE;
  p_IncludeRelatedEntityNameFieldInBaseView_bc4a9d7f := FALSE;
  p_RelatedEntityDisplayType_bc4a9d7f := 'Search';
  p_AutoUpdateRelatedEntityInfo_bc4a9d7f := TRUE;
  p_ValuesToPackWithSchema_bc4a9d7f := 'Auto';
  p_Status_bc4a9d7f := 'Active';
  p_AutoUpdateIsNameField_bc4a9d7f := TRUE;
  p_AutoUpdateDefaultInView_bc4a9d7f := TRUE;
  p_AutoUpdateCategory_bc4a9d7f := TRUE;
  p_AutoUpdateDisplayName_bc4a9d7f := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_bc4a9d7f := FALSE;
  p_Encrypt_bc4a9d7f := FALSE;
  p_AllowDecryptInAPI_bc4a9d7f := FALSE;
  p_SendEncryptedValue_bc4a9d7f := FALSE;
  p_IsSoftPrimaryKey_bc4a9d7f := FALSE;
  p_IsSoftForeignKey_bc4a9d7f := FALSE;
  p_JSONTypeIsArray_bc4a9d7f := FALSE;
  p_UserSearchPredicateAPI_bc4a9d7f := 'BeginsWith';
  p_AutoUpdateUserSearchPredicate_bc4a9d7f := TRUE;
  p_AutoUpdateFullTextSearch_bc4a9d7f := TRUE;
  p_AutoUpdateExtendedType_bc4a9d7f := TRUE;
  p_IsComputed_bc4a9d7f := FALSE;
  p_ID_bc4a9d7f := 'FBDA77B7-3EDB-4D32-A7D4-06FE401457BE';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_bc4a9d7f,
    'Description', p_Description_bc4a9d7f,
    'AutoUpdateDescription', p_AutoUpdateDescription_bc4a9d7f,
    'IsPrimaryKey', p_IsPrimaryKey_bc4a9d7f,
    'IsUnique', p_IsUnique_bc4a9d7f,
    'Category', p_Category_bc4a9d7f,
    'ValueListType', p_ValueListType_bc4a9d7f,
    'ExtendedType', p_ExtendedType_bc4a9d7f,
    'CodeType', p_CodeType_bc4a9d7f,
    'DefaultInView', p_DefaultInView_bc4a9d7f,
    'ViewCellTemplate', p_ViewCellTemplate_bc4a9d7f,
    'DefaultColumnWidth', p_DefaultColumnWidth_bc4a9d7f,
    'AllowUpdateAPI', p_AllowUpdateAPI_bc4a9d7f,
    'AllowUpdateInView', p_AllowUpdateInView_bc4a9d7f,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_bc4a9d7f,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_bc4a9d7f,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_bc4a9d7f,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_bc4a9d7f,
    'GeneratedFormSection', p_GeneratedFormSection_bc4a9d7f,
    'IsNameField', p_IsNameField_bc4a9d7f,
    'RelatedEntityID', p_RelatedEntityID_bc4a9d7f,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_bc4a9d7f,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_bc4a9d7f,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_bc4a9d7f,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_bc4a9d7f,
    'EntityIDFieldName', p_EntityIDFieldName_bc4a9d7f,
    'ScopeDefault', p_ScopeDefault_bc4a9d7f,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_bc4a9d7f,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_bc4a9d7f,
    'Status', p_Status_bc4a9d7f,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_bc4a9d7f,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_bc4a9d7f,
    'AutoUpdateCategory', p_AutoUpdateCategory_bc4a9d7f,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_bc4a9d7f,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_bc4a9d7f,
    'Encrypt', p_Encrypt_bc4a9d7f,
    'EncryptionKeyID', p_EncryptionKeyID_bc4a9d7f,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_bc4a9d7f,
    'SendEncryptedValue', p_SendEncryptedValue_bc4a9d7f,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_bc4a9d7f,
    'IsSoftForeignKey', p_IsSoftForeignKey_bc4a9d7f,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_bc4a9d7f,
    'JSONType', p_JSONType_bc4a9d7f,
    'JSONTypeIsArray', p_JSONTypeIsArray_bc4a9d7f,
    'JSONTypeDefinition', p_JSONTypeDefinition_bc4a9d7f,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_bc4a9d7f,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_bc4a9d7f,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_bc4a9d7f,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_bc4a9d7f,
    'IsComputed', p_IsComputed_bc4a9d7f
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_bc4a9d7f,
    'Configuration', p_Configuration_bc4a9d7f,
    'ID', p_ID_bc4a9d7f
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_bc4a9d7f, p_Description := p_Description_bc4a9d7f, p_AutoUpdateDescription := p_AutoUpdateDescription_bc4a9d7f, p_IsPrimaryKey := p_IsPrimaryKey_bc4a9d7f, p_IsUnique := p_IsUnique_bc4a9d7f, p_Category := p_Category_bc4a9d7f, p_ValueListType := p_ValueListType_bc4a9d7f, p_ExtendedType := p_ExtendedType_bc4a9d7f, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_bc4a9d7f, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_bc4a9d7f, p_ViewCellTemplate := p_ViewCellTemplate_bc4a9d7f, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_bc4a9d7f, p_AllowUpdateAPI := p_AllowUpdateAPI_bc4a9d7f, p_AllowUpdateInView := p_AllowUpdateInView_bc4a9d7f, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_bc4a9d7f, p_FullTextSearchEnabled := p_FullTextSearchEnabled_bc4a9d7f, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_bc4a9d7f, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_bc4a9d7f, p_GeneratedFormSection := p_GeneratedFormSection_bc4a9d7f, p_IsNameField := p_IsNameField_bc4a9d7f, p_RelatedEntityID := p_RelatedEntityID_bc4a9d7f, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_bc4a9d7f, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_bc4a9d7f, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_bc4a9d7f, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_bc4a9d7f, p_EntityIDFieldName := p_EntityIDFieldName_bc4a9d7f, p_EntityIDFieldName_Clear := TRUE, p_ScopeDefault := p_ScopeDefault_bc4a9d7f, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_bc4a9d7f, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_bc4a9d7f, p_Status := p_Status_bc4a9d7f, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_bc4a9d7f, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_bc4a9d7f, p_AutoUpdateCategory := p_AutoUpdateCategory_bc4a9d7f, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_bc4a9d7f, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_bc4a9d7f, p_Encrypt := p_Encrypt_bc4a9d7f, p_EncryptionKeyID := p_EncryptionKeyID_bc4a9d7f, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_bc4a9d7f, p_SendEncryptedValue := p_SendEncryptedValue_bc4a9d7f, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_bc4a9d7f, p_IsSoftForeignKey := p_IsSoftForeignKey_bc4a9d7f, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_bc4a9d7f, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_bc4a9d7f, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_bc4a9d7f, p_JSONTypeDefinition := p_JSONTypeDefinition_bc4a9d7f, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_bc4a9d7f, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_bc4a9d7f, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_bc4a9d7f, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_bc4a9d7f, p_IsComputed := p_IsComputed_bc4a9d7f, p_EmbeddedRecord := p_EmbeddedRecord_bc4a9d7f, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_bc4a9d7f, p_Configuration_Clear := TRUE, p_ID := p_ID_bc4a9d7f);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_e0640bed VARCHAR(255);
  p_Description_e0640bed TEXT;
  p_AutoUpdateDescription_e0640bed BOOLEAN;
  p_IsPrimaryKey_e0640bed BOOLEAN;
  p_IsUnique_e0640bed BOOLEAN;
  p_Category_e0640bed VARCHAR(255);
  p_ValueListType_e0640bed VARCHAR(20);
  p_ExtendedType_e0640bed VARCHAR(50);
  p_CodeType_e0640bed VARCHAR(50);
  p_DefaultInView_e0640bed BOOLEAN;
  p_ViewCellTemplate_e0640bed TEXT;
  p_DefaultColumnWidth_e0640bed INTEGER;
  p_AllowUpdateAPI_e0640bed BOOLEAN;
  p_AllowUpdateInView_e0640bed BOOLEAN;
  p_IncludeInUserSearchAPI_e0640bed BOOLEAN;
  p_FullTextSearchEnabled_e0640bed BOOLEAN;
  p_UserSearchParamFormatAPI_e0640bed VARCHAR(500);
  p_IncludeInGeneratedForm_e0640bed BOOLEAN;
  p_GeneratedFormSection_e0640bed VARCHAR(10);
  p_IsNameField_e0640bed BOOLEAN;
  p_RelatedEntityID_e0640bed UUID;
  p_RelatedEntityFieldName_e0640bed VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_e0640bed BOOLEAN;
  p_RelatedEntityNameFieldMap_e0640bed VARCHAR(255);
  p_RelatedEntityDisplayType_e0640bed VARCHAR(20);
  p_EntityIDFieldName_e0640bed VARCHAR(100);
  p_ScopeDefault_e0640bed VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_e0640bed BOOLEAN;
  p_ValuesToPackWithSchema_e0640bed VARCHAR(10);
  p_Status_e0640bed VARCHAR(25);
  p_AutoUpdateIsNameField_e0640bed BOOLEAN;
  p_AutoUpdateDefaultInView_e0640bed BOOLEAN;
  p_AutoUpdateCategory_e0640bed BOOLEAN;
  p_AutoUpdateDisplayName_e0640bed BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_e0640bed BOOLEAN;
  p_Encrypt_e0640bed BOOLEAN;
  p_EncryptionKeyID_e0640bed UUID;
  p_AllowDecryptInAPI_e0640bed BOOLEAN;
  p_SendEncryptedValue_e0640bed BOOLEAN;
  p_IsSoftPrimaryKey_e0640bed BOOLEAN;
  p_IsSoftForeignKey_e0640bed BOOLEAN;
  p_RelatedEntityJoinFields_e0640bed TEXT;
  p_JSONType_e0640bed VARCHAR(255);
  p_JSONTypeIsArray_e0640bed BOOLEAN;
  p_JSONTypeDefinition_e0640bed TEXT;
  p_UserSearchPredicateAPI_e0640bed VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_e0640bed BOOLEAN;
  p_AutoUpdateFullTextSearch_e0640bed BOOLEAN;
  p_AutoUpdateExtendedType_e0640bed BOOLEAN;
  p_IsComputed_e0640bed BOOLEAN;
  p_EmbeddedRecord_e0640bed TEXT;
  p_Configuration_e0640bed TEXT;
  p_ID_e0640bed UUID;
BEGIN
  p_DisplayName_e0640bed := 'Assignee Record ID';
  p_Description_e0640bed := 'Polymorphic assignee: the primary key (as string) of the assignee record within AssigneeEntityID.';
  p_AutoUpdateDescription_e0640bed := TRUE;
  p_IsPrimaryKey_e0640bed := FALSE;
  p_IsUnique_e0640bed := FALSE;
  p_Category_e0640bed := 'Stakeholders';
  p_ValueListType_e0640bed := 'None';
  p_DefaultInView_e0640bed := FALSE;
  p_DefaultColumnWidth_e0640bed := 150;
  p_AllowUpdateAPI_e0640bed := TRUE;
  p_AllowUpdateInView_e0640bed := TRUE;
  p_IncludeInUserSearchAPI_e0640bed := FALSE;
  p_FullTextSearchEnabled_e0640bed := FALSE;
  p_IncludeInGeneratedForm_e0640bed := TRUE;
  p_GeneratedFormSection_e0640bed := 'Category';
  p_IsNameField_e0640bed := FALSE;
  p_IncludeRelatedEntityNameFieldInBaseView_e0640bed := FALSE;
  p_RelatedEntityDisplayType_e0640bed := 'Search';
  p_EntityIDFieldName_e0640bed := 'AssigneeEntityID';
  p_AutoUpdateRelatedEntityInfo_e0640bed := TRUE;
  p_ValuesToPackWithSchema_e0640bed := 'Auto';
  p_Status_e0640bed := 'Active';
  p_AutoUpdateIsNameField_e0640bed := TRUE;
  p_AutoUpdateDefaultInView_e0640bed := TRUE;
  p_AutoUpdateCategory_e0640bed := TRUE;
  p_AutoUpdateDisplayName_e0640bed := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_e0640bed := TRUE;
  p_Encrypt_e0640bed := FALSE;
  p_AllowDecryptInAPI_e0640bed := FALSE;
  p_SendEncryptedValue_e0640bed := FALSE;
  p_IsSoftPrimaryKey_e0640bed := FALSE;
  p_IsSoftForeignKey_e0640bed := FALSE;
  p_JSONTypeIsArray_e0640bed := FALSE;
  p_UserSearchPredicateAPI_e0640bed := 'Contains';
  p_AutoUpdateUserSearchPredicate_e0640bed := TRUE;
  p_AutoUpdateFullTextSearch_e0640bed := TRUE;
  p_AutoUpdateExtendedType_e0640bed := TRUE;
  p_IsComputed_e0640bed := FALSE;
  p_ID_e0640bed := '24653D3B-FAED-4A91-BD7F-8C903B8AD018';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_e0640bed,
    'Description', p_Description_e0640bed,
    'AutoUpdateDescription', p_AutoUpdateDescription_e0640bed,
    'IsPrimaryKey', p_IsPrimaryKey_e0640bed,
    'IsUnique', p_IsUnique_e0640bed,
    'Category', p_Category_e0640bed,
    'ValueListType', p_ValueListType_e0640bed,
    'ExtendedType', p_ExtendedType_e0640bed,
    'CodeType', p_CodeType_e0640bed,
    'DefaultInView', p_DefaultInView_e0640bed,
    'ViewCellTemplate', p_ViewCellTemplate_e0640bed,
    'DefaultColumnWidth', p_DefaultColumnWidth_e0640bed,
    'AllowUpdateAPI', p_AllowUpdateAPI_e0640bed,
    'AllowUpdateInView', p_AllowUpdateInView_e0640bed,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_e0640bed,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_e0640bed,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_e0640bed,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_e0640bed,
    'GeneratedFormSection', p_GeneratedFormSection_e0640bed,
    'IsNameField', p_IsNameField_e0640bed,
    'RelatedEntityID', p_RelatedEntityID_e0640bed,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_e0640bed,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_e0640bed,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_e0640bed,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_e0640bed,
    'EntityIDFieldName', p_EntityIDFieldName_e0640bed,
    'ScopeDefault', p_ScopeDefault_e0640bed,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_e0640bed,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_e0640bed,
    'Status', p_Status_e0640bed,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_e0640bed,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_e0640bed,
    'AutoUpdateCategory', p_AutoUpdateCategory_e0640bed,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_e0640bed,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_e0640bed,
    'Encrypt', p_Encrypt_e0640bed,
    'EncryptionKeyID', p_EncryptionKeyID_e0640bed,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_e0640bed,
    'SendEncryptedValue', p_SendEncryptedValue_e0640bed,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_e0640bed,
    'IsSoftForeignKey', p_IsSoftForeignKey_e0640bed,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_e0640bed,
    'JSONType', p_JSONType_e0640bed,
    'JSONTypeIsArray', p_JSONTypeIsArray_e0640bed,
    'JSONTypeDefinition', p_JSONTypeDefinition_e0640bed,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_e0640bed,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_e0640bed,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_e0640bed,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_e0640bed,
    'IsComputed', p_IsComputed_e0640bed
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_e0640bed,
    'Configuration', p_Configuration_e0640bed,
    'ID', p_ID_e0640bed
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_e0640bed, p_Description := p_Description_e0640bed, p_AutoUpdateDescription := p_AutoUpdateDescription_e0640bed, p_IsPrimaryKey := p_IsPrimaryKey_e0640bed, p_IsUnique := p_IsUnique_e0640bed, p_Category := p_Category_e0640bed, p_ValueListType := p_ValueListType_e0640bed, p_ExtendedType := p_ExtendedType_e0640bed, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_e0640bed, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_e0640bed, p_ViewCellTemplate := p_ViewCellTemplate_e0640bed, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_e0640bed, p_AllowUpdateAPI := p_AllowUpdateAPI_e0640bed, p_AllowUpdateInView := p_AllowUpdateInView_e0640bed, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_e0640bed, p_FullTextSearchEnabled := p_FullTextSearchEnabled_e0640bed, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_e0640bed, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_e0640bed, p_GeneratedFormSection := p_GeneratedFormSection_e0640bed, p_IsNameField := p_IsNameField_e0640bed, p_RelatedEntityID := p_RelatedEntityID_e0640bed, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_e0640bed, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_e0640bed, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_e0640bed, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_e0640bed, p_EntityIDFieldName := p_EntityIDFieldName_e0640bed, p_ScopeDefault := p_ScopeDefault_e0640bed, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_e0640bed, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_e0640bed, p_Status := p_Status_e0640bed, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_e0640bed, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_e0640bed, p_AutoUpdateCategory := p_AutoUpdateCategory_e0640bed, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_e0640bed, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_e0640bed, p_Encrypt := p_Encrypt_e0640bed, p_EncryptionKeyID := p_EncryptionKeyID_e0640bed, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_e0640bed, p_SendEncryptedValue := p_SendEncryptedValue_e0640bed, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_e0640bed, p_IsSoftForeignKey := p_IsSoftForeignKey_e0640bed, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_e0640bed, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_e0640bed, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_e0640bed, p_JSONTypeDefinition := p_JSONTypeDefinition_e0640bed, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_e0640bed, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_e0640bed, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_e0640bed, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_e0640bed, p_IsComputed := p_IsComputed_e0640bed, p_EmbeddedRecord := p_EmbeddedRecord_e0640bed, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_e0640bed, p_Configuration_Clear := TRUE, p_ID := p_ID_e0640bed);
  END IF;
END $mj$;

-- Save MJ: Entity Fields (core SP call only)
DO $mj$
DECLARE
  p_DisplayName_c25bd974 VARCHAR(255);
  p_Description_c25bd974 TEXT;
  p_AutoUpdateDescription_c25bd974 BOOLEAN;
  p_IsPrimaryKey_c25bd974 BOOLEAN;
  p_IsUnique_c25bd974 BOOLEAN;
  p_Category_c25bd974 VARCHAR(255);
  p_ValueListType_c25bd974 VARCHAR(20);
  p_ExtendedType_c25bd974 VARCHAR(50);
  p_CodeType_c25bd974 VARCHAR(50);
  p_DefaultInView_c25bd974 BOOLEAN;
  p_ViewCellTemplate_c25bd974 TEXT;
  p_DefaultColumnWidth_c25bd974 INTEGER;
  p_AllowUpdateAPI_c25bd974 BOOLEAN;
  p_AllowUpdateInView_c25bd974 BOOLEAN;
  p_IncludeInUserSearchAPI_c25bd974 BOOLEAN;
  p_FullTextSearchEnabled_c25bd974 BOOLEAN;
  p_UserSearchParamFormatAPI_c25bd974 VARCHAR(500);
  p_IncludeInGeneratedForm_c25bd974 BOOLEAN;
  p_GeneratedFormSection_c25bd974 VARCHAR(10);
  p_IsNameField_c25bd974 BOOLEAN;
  p_RelatedEntityID_c25bd974 UUID;
  p_RelatedEntityFieldName_c25bd974 VARCHAR(255);
  p_IncludeRelatedEntityNameFieldInBaseView_c25bd974 BOOLEAN;
  p_RelatedEntityNameFieldMap_c25bd974 VARCHAR(255);
  p_RelatedEntityDisplayType_c25bd974 VARCHAR(20);
  p_EntityIDFieldName_c25bd974 VARCHAR(100);
  p_ScopeDefault_c25bd974 VARCHAR(100);
  p_AutoUpdateRelatedEntityInfo_c25bd974 BOOLEAN;
  p_ValuesToPackWithSchema_c25bd974 VARCHAR(10);
  p_Status_c25bd974 VARCHAR(25);
  p_AutoUpdateIsNameField_c25bd974 BOOLEAN;
  p_AutoUpdateDefaultInView_c25bd974 BOOLEAN;
  p_AutoUpdateCategory_c25bd974 BOOLEAN;
  p_AutoUpdateDisplayName_c25bd974 BOOLEAN;
  p_AutoUpdateIncludeInUserSearchAPI_c25bd974 BOOLEAN;
  p_Encrypt_c25bd974 BOOLEAN;
  p_EncryptionKeyID_c25bd974 UUID;
  p_AllowDecryptInAPI_c25bd974 BOOLEAN;
  p_SendEncryptedValue_c25bd974 BOOLEAN;
  p_IsSoftPrimaryKey_c25bd974 BOOLEAN;
  p_IsSoftForeignKey_c25bd974 BOOLEAN;
  p_RelatedEntityJoinFields_c25bd974 TEXT;
  p_JSONType_c25bd974 VARCHAR(255);
  p_JSONTypeIsArray_c25bd974 BOOLEAN;
  p_JSONTypeDefinition_c25bd974 TEXT;
  p_UserSearchPredicateAPI_c25bd974 VARCHAR(20);
  p_AutoUpdateUserSearchPredicate_c25bd974 BOOLEAN;
  p_AutoUpdateFullTextSearch_c25bd974 BOOLEAN;
  p_AutoUpdateExtendedType_c25bd974 BOOLEAN;
  p_IsComputed_c25bd974 BOOLEAN;
  p_EmbeddedRecord_c25bd974 TEXT;
  p_Configuration_c25bd974 TEXT;
  p_ID_c25bd974 UUID;
BEGIN
  p_DisplayName_c25bd974 := 'Source Record ID';
  p_Description_c25bd974 := 'Polymorphic source: the primary key (as string) of the source record within SourceEntityID.';
  p_AutoUpdateDescription_c25bd974 := TRUE;
  p_IsPrimaryKey_c25bd974 := FALSE;
  p_IsUnique_c25bd974 := FALSE;
  p_Category_c25bd974 := 'Context';
  p_ValueListType_c25bd974 := 'None';
  p_DefaultInView_c25bd974 := FALSE;
  p_DefaultColumnWidth_c25bd974 := 150;
  p_AllowUpdateAPI_c25bd974 := TRUE;
  p_AllowUpdateInView_c25bd974 := TRUE;
  p_IncludeInUserSearchAPI_c25bd974 := FALSE;
  p_FullTextSearchEnabled_c25bd974 := FALSE;
  p_IncludeInGeneratedForm_c25bd974 := TRUE;
  p_GeneratedFormSection_c25bd974 := 'Category';
  p_IsNameField_c25bd974 := FALSE;
  p_IncludeRelatedEntityNameFieldInBaseView_c25bd974 := FALSE;
  p_RelatedEntityDisplayType_c25bd974 := 'Search';
  p_EntityIDFieldName_c25bd974 := 'SourceEntityID';
  p_AutoUpdateRelatedEntityInfo_c25bd974 := TRUE;
  p_ValuesToPackWithSchema_c25bd974 := 'Auto';
  p_Status_c25bd974 := 'Active';
  p_AutoUpdateIsNameField_c25bd974 := TRUE;
  p_AutoUpdateDefaultInView_c25bd974 := TRUE;
  p_AutoUpdateCategory_c25bd974 := TRUE;
  p_AutoUpdateDisplayName_c25bd974 := TRUE;
  p_AutoUpdateIncludeInUserSearchAPI_c25bd974 := TRUE;
  p_Encrypt_c25bd974 := FALSE;
  p_AllowDecryptInAPI_c25bd974 := FALSE;
  p_SendEncryptedValue_c25bd974 := FALSE;
  p_IsSoftPrimaryKey_c25bd974 := FALSE;
  p_IsSoftForeignKey_c25bd974 := FALSE;
  p_JSONTypeIsArray_c25bd974 := FALSE;
  p_UserSearchPredicateAPI_c25bd974 := 'Contains';
  p_AutoUpdateUserSearchPredicate_c25bd974 := TRUE;
  p_AutoUpdateFullTextSearch_c25bd974 := TRUE;
  p_AutoUpdateExtendedType_c25bd974 := TRUE;
  p_IsComputed_c25bd974 := FALSE;
  p_ID_c25bd974 := '5E4D5272-5F71-4E7F-99B0-F0D9DE5C3641';
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = '${mjSchema}' AND p.proname = 'spUpdateEntityField'
       AND p.pronargs = 1 AND p.proargtypes[0] = 'jsonb'::regtype
  ) THEN
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_data := jsonb_build_object(
    'DisplayName', p_DisplayName_c25bd974,
    'Description', p_Description_c25bd974,
    'AutoUpdateDescription', p_AutoUpdateDescription_c25bd974,
    'IsPrimaryKey', p_IsPrimaryKey_c25bd974,
    'IsUnique', p_IsUnique_c25bd974,
    'Category', p_Category_c25bd974,
    'ValueListType', p_ValueListType_c25bd974,
    'ExtendedType', p_ExtendedType_c25bd974,
    'CodeType', p_CodeType_c25bd974,
    'DefaultInView', p_DefaultInView_c25bd974,
    'ViewCellTemplate', p_ViewCellTemplate_c25bd974,
    'DefaultColumnWidth', p_DefaultColumnWidth_c25bd974,
    'AllowUpdateAPI', p_AllowUpdateAPI_c25bd974,
    'AllowUpdateInView', p_AllowUpdateInView_c25bd974,
    'IncludeInUserSearchAPI', p_IncludeInUserSearchAPI_c25bd974,
    'FullTextSearchEnabled', p_FullTextSearchEnabled_c25bd974,
    'UserSearchParamFormatAPI', p_UserSearchParamFormatAPI_c25bd974,
    'IncludeInGeneratedForm', p_IncludeInGeneratedForm_c25bd974,
    'GeneratedFormSection', p_GeneratedFormSection_c25bd974,
    'IsNameField', p_IsNameField_c25bd974,
    'RelatedEntityID', p_RelatedEntityID_c25bd974,
    'RelatedEntityFieldName', p_RelatedEntityFieldName_c25bd974,
    'IncludeRelatedEntityNameFieldInBaseView', p_IncludeRelatedEntityNameFieldInBaseView_c25bd974,
    'RelatedEntityNameFieldMap', p_RelatedEntityNameFieldMap_c25bd974,
    'RelatedEntityDisplayType', p_RelatedEntityDisplayType_c25bd974,
    'EntityIDFieldName', p_EntityIDFieldName_c25bd974,
    'ScopeDefault', p_ScopeDefault_c25bd974,
    'AutoUpdateRelatedEntityInfo', p_AutoUpdateRelatedEntityInfo_c25bd974,
    'ValuesToPackWithSchema', p_ValuesToPackWithSchema_c25bd974,
    'Status', p_Status_c25bd974,
    'AutoUpdateIsNameField', p_AutoUpdateIsNameField_c25bd974,
    'AutoUpdateDefaultInView', p_AutoUpdateDefaultInView_c25bd974,
    'AutoUpdateCategory', p_AutoUpdateCategory_c25bd974,
    'AutoUpdateDisplayName', p_AutoUpdateDisplayName_c25bd974,
    'AutoUpdateIncludeInUserSearchAPI', p_AutoUpdateIncludeInUserSearchAPI_c25bd974,
    'Encrypt', p_Encrypt_c25bd974,
    'EncryptionKeyID', p_EncryptionKeyID_c25bd974,
    'AllowDecryptInAPI', p_AllowDecryptInAPI_c25bd974,
    'SendEncryptedValue', p_SendEncryptedValue_c25bd974,
    'IsSoftPrimaryKey', p_IsSoftPrimaryKey_c25bd974,
    'IsSoftForeignKey', p_IsSoftForeignKey_c25bd974,
    'RelatedEntityJoinFields', p_RelatedEntityJoinFields_c25bd974,
    'JSONType', p_JSONType_c25bd974,
    'JSONTypeIsArray', p_JSONTypeIsArray_c25bd974,
    'JSONTypeDefinition', p_JSONTypeDefinition_c25bd974,
    'UserSearchPredicateAPI', p_UserSearchPredicateAPI_c25bd974,
    'AutoUpdateUserSearchPredicate', p_AutoUpdateUserSearchPredicate_c25bd974,
    'AutoUpdateFullTextSearch', p_AutoUpdateFullTextSearch_c25bd974,
    'AutoUpdateExtendedType', p_AutoUpdateExtendedType_c25bd974,
    'IsComputed', p_IsComputed_c25bd974
  ) ||
  jsonb_build_object(
    'EmbeddedRecord', p_EmbeddedRecord_c25bd974,
    'Configuration', p_Configuration_c25bd974,
    'ID', p_ID_c25bd974
  ));
  ELSE
    PERFORM "${mjSchema}"."spUpdateEntityField"(p_DisplayName := p_DisplayName_c25bd974, p_Description := p_Description_c25bd974, p_AutoUpdateDescription := p_AutoUpdateDescription_c25bd974, p_IsPrimaryKey := p_IsPrimaryKey_c25bd974, p_IsUnique := p_IsUnique_c25bd974, p_Category := p_Category_c25bd974, p_ValueListType := p_ValueListType_c25bd974, p_ExtendedType := p_ExtendedType_c25bd974, p_ExtendedType_Clear := TRUE, p_CodeType := p_CodeType_c25bd974, p_CodeType_Clear := TRUE, p_DefaultInView := p_DefaultInView_c25bd974, p_ViewCellTemplate := p_ViewCellTemplate_c25bd974, p_ViewCellTemplate_Clear := TRUE, p_DefaultColumnWidth := p_DefaultColumnWidth_c25bd974, p_AllowUpdateAPI := p_AllowUpdateAPI_c25bd974, p_AllowUpdateInView := p_AllowUpdateInView_c25bd974, p_IncludeInUserSearchAPI := p_IncludeInUserSearchAPI_c25bd974, p_FullTextSearchEnabled := p_FullTextSearchEnabled_c25bd974, p_UserSearchParamFormatAPI := p_UserSearchParamFormatAPI_c25bd974, p_UserSearchParamFormatAPI_Clear := TRUE, p_IncludeInGeneratedForm := p_IncludeInGeneratedForm_c25bd974, p_GeneratedFormSection := p_GeneratedFormSection_c25bd974, p_IsNameField := p_IsNameField_c25bd974, p_RelatedEntityID := p_RelatedEntityID_c25bd974, p_RelatedEntityID_Clear := TRUE, p_RelatedEntityFieldName := p_RelatedEntityFieldName_c25bd974, p_RelatedEntityFieldName_Clear := TRUE, p_IncludeRelatedEntityNameFieldInBaseView := p_IncludeRelatedEntityNameFieldInBaseView_c25bd974, p_RelatedEntityNameFieldMap := p_RelatedEntityNameFieldMap_c25bd974, p_RelatedEntityNameFieldMap_Clear := TRUE, p_RelatedEntityDisplayType := p_RelatedEntityDisplayType_c25bd974, p_EntityIDFieldName := p_EntityIDFieldName_c25bd974, p_ScopeDefault := p_ScopeDefault_c25bd974, p_ScopeDefault_Clear := TRUE, p_AutoUpdateRelatedEntityInfo := p_AutoUpdateRelatedEntityInfo_c25bd974, p_ValuesToPackWithSchema := p_ValuesToPackWithSchema_c25bd974, p_Status := p_Status_c25bd974, p_AutoUpdateIsNameField := p_AutoUpdateIsNameField_c25bd974, p_AutoUpdateDefaultInView := p_AutoUpdateDefaultInView_c25bd974, p_AutoUpdateCategory := p_AutoUpdateCategory_c25bd974, p_AutoUpdateDisplayName := p_AutoUpdateDisplayName_c25bd974, p_AutoUpdateIncludeInUserSearchAPI := p_AutoUpdateIncludeInUserSearchAPI_c25bd974, p_Encrypt := p_Encrypt_c25bd974, p_EncryptionKeyID := p_EncryptionKeyID_c25bd974, p_EncryptionKeyID_Clear := TRUE, p_AllowDecryptInAPI := p_AllowDecryptInAPI_c25bd974, p_SendEncryptedValue := p_SendEncryptedValue_c25bd974, p_IsSoftPrimaryKey := p_IsSoftPrimaryKey_c25bd974, p_IsSoftForeignKey := p_IsSoftForeignKey_c25bd974, p_RelatedEntityJoinFields := p_RelatedEntityJoinFields_c25bd974, p_RelatedEntityJoinFields_Clear := TRUE, p_JSONType := p_JSONType_c25bd974, p_JSONType_Clear := TRUE, p_JSONTypeIsArray := p_JSONTypeIsArray_c25bd974, p_JSONTypeDefinition := p_JSONTypeDefinition_c25bd974, p_JSONTypeDefinition_Clear := TRUE, p_UserSearchPredicateAPI := p_UserSearchPredicateAPI_c25bd974, p_AutoUpdateUserSearchPredicate := p_AutoUpdateUserSearchPredicate_c25bd974, p_AutoUpdateFullTextSearch := p_AutoUpdateFullTextSearch_c25bd974, p_AutoUpdateExtendedType := p_AutoUpdateExtendedType_c25bd974, p_IsComputed := p_IsComputed_c25bd974, p_EmbeddedRecord := p_EmbeddedRecord_c25bd974, p_EmbeddedRecord_Clear := TRUE, p_Configuration := p_Configuration_c25bd974, p_Configuration_Clear := TRUE, p_ID := p_ID_c25bd974);
  END IF;
END $mj$;
