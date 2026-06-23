import { Component } from '@angular/core';
import { mjBizAppsIssuesIssueTypeEntity } from '@mj-biz-apps/issues-entities';
import { RegisterClass } from '@memberjunction/global';
import { BaseFormComponent } from '@memberjunction/ng-base-forms';
import {  } from "@memberjunction/ng-entity-viewer"

@RegisterClass(BaseFormComponent, 'MJ_BizApps_Issues: Issue Types') // Tell MemberJunction about this class
@Component({
    standalone: false,
    selector: 'gen-mjbizappsissuesissuetype-form',
    templateUrl: './mjbizappsissuesissuetype.form.component.html'
})
export class mjBizAppsIssuesIssueTypeFormComponent extends BaseFormComponent {
    public record!: mjBizAppsIssuesIssueTypeEntity;

    override async ngOnInit() {
        await super.ngOnInit();
        this.initSections([
            { sectionKey: 'details', sectionName: 'Details', isExpanded: true },
            { sectionKey: 'mJBizAppsIssuesIssues', sectionName: 'Issues', isExpanded: false }
        ]);
    }
}

