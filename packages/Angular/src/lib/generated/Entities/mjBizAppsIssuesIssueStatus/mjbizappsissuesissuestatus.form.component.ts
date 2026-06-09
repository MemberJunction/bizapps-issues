import { Component } from '@angular/core';
import { mjBizAppsIssuesIssueStatusEntity } from '@mj-biz-apps/issues-entities';
import { RegisterClass } from '@memberjunction/global';
import { BaseFormComponent } from '@memberjunction/ng-base-forms';
import {  } from "@memberjunction/ng-entity-viewer"

@RegisterClass(BaseFormComponent, 'MJ_BizApps_Issues: Issue Status') // Tell MemberJunction about this class
@Component({
    standalone: false,
    selector: 'gen-mjbizappsissuesissuestatus-form',
    templateUrl: './mjbizappsissuesissuestatus.form.component.html'
})
export class mjBizAppsIssuesIssueStatusFormComponent extends BaseFormComponent {
    public record!: mjBizAppsIssuesIssueStatusEntity;

    override async ngOnInit() {
        await super.ngOnInit();
        this.initSections([
            { sectionKey: 'details', sectionName: 'Details', isExpanded: true },
            { sectionKey: 'mJBizAppsIssuesIssues', sectionName: 'Issues', isExpanded: false }
        ]);
    }
}

