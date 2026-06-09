import { Component } from '@angular/core';
import { mjBizAppsIssuesIssueCommentEntity } from '@mj-biz-apps/issues-entities';
import { RegisterClass } from '@memberjunction/global';
import { BaseFormComponent } from '@memberjunction/ng-base-forms';

@RegisterClass(BaseFormComponent, 'MJ_BizApps_Issues: Issue Comments') // Tell MemberJunction about this class
@Component({
    standalone: false,
    selector: 'gen-mjbizappsissuesissuecomment-form',
    templateUrl: './mjbizappsissuesissuecomment.form.component.html'
})
export class mjBizAppsIssuesIssueCommentFormComponent extends BaseFormComponent {
    public record!: mjBizAppsIssuesIssueCommentEntity;

    override async ngOnInit() {
        await super.ngOnInit();
        this.initSections([
            { sectionKey: 'details', sectionName: 'Details', isExpanded: true }
        ]);
    }
}

