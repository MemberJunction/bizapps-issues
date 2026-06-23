import { Component } from '@angular/core';
import { mjBizAppsIssuesIssueEntity } from '@mj-biz-apps/issues-entities';
import { RegisterClass } from '@memberjunction/global';
import { BaseFormComponent } from '@memberjunction/ng-base-forms';
import {  } from "@memberjunction/ng-entity-viewer"

@RegisterClass(BaseFormComponent, 'MJ_BizApps_Issues: Issues') // Tell MemberJunction about this class
@Component({
    standalone: false,
    selector: 'gen-mjbizappsissuesissue-form',
    templateUrl: './mjbizappsissuesissue.form.component.html'
})
export class mjBizAppsIssuesIssueFormComponent extends BaseFormComponent {
    public record!: mjBizAppsIssuesIssueEntity;

    override async ngOnInit() {
        await super.ngOnInit();
        this.initSections([
            { sectionKey: 'details', sectionName: 'Details', isExpanded: true },
            { sectionKey: 'mJBizAppsIssuesIssueComments', sectionName: 'Issue Comments', isExpanded: false }
        ]);
    }
}

