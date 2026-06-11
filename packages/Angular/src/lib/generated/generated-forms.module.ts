/**********************************************************************************
* GENERATED FILE - This file is automatically managed by the MJ CodeGen tool, 
* 
* DO NOT MODIFY THIS FILE - any changes you make will be wiped out the next time the file is
* generated
* 
**********************************************************************************/
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

// MemberJunction Imports
import { BaseFormsModule } from '@memberjunction/ng-base-forms';
import { EntityViewerModule } from '@memberjunction/ng-entity-viewer';
import { LinkDirectivesModule } from '@memberjunction/ng-link-directives';

// Import Generated Components
import { mjBizAppsIssuesIssueCommentFormComponent } from "./Entities/mjBizAppsIssuesIssueComment/mjbizappsissuesissuecomment.form.component";
import { mjBizAppsIssuesIssueNumberSequenceFormComponent } from "./Entities/mjBizAppsIssuesIssueNumberSequence/mjbizappsissuesissuenumbersequence.form.component";
import { mjBizAppsIssuesIssueStatusFormComponent } from "./Entities/mjBizAppsIssuesIssueStatus/mjbizappsissuesissuestatus.form.component";
import { mjBizAppsIssuesIssueTypeFormComponent } from "./Entities/mjBizAppsIssuesIssueType/mjbizappsissuesissuetype.form.component";
import { mjBizAppsIssuesIssueFormComponent } from "./Entities/mjBizAppsIssuesIssue/mjbizappsissuesissue.form.component";
   

@NgModule({
declarations: [
    mjBizAppsIssuesIssueCommentFormComponent,
    mjBizAppsIssuesIssueNumberSequenceFormComponent,
    mjBizAppsIssuesIssueStatusFormComponent,
    mjBizAppsIssuesIssueTypeFormComponent,
    mjBizAppsIssuesIssueFormComponent],
imports: [
    CommonModule,
    FormsModule,
    BaseFormsModule,
    EntityViewerModule,
    LinkDirectivesModule
],
exports: [
]
})
export class GeneratedForms_SubModule_0 { }
    


@NgModule({
declarations: [
],
imports: [
    GeneratedForms_SubModule_0
]
})
export class GeneratedFormsModule { }
    
// Note: LoadXXXGeneratedForms() functions have been removed. Tree-shaking prevention
// is now handled by the pre-built class registration manifest system.
// See packages/CodeGenLib/CLASS_MANIFEST_GUIDE.md for details.
    