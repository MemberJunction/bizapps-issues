import { Component } from '@angular/core';
import { mjBizAppsIssuesIssueNumberSequenceEntity } from '@mj-biz-apps/issues-entities';
import { RegisterClass } from '@memberjunction/global';
import { BaseFormComponent } from '@memberjunction/ng-base-forms';

@RegisterClass(BaseFormComponent, 'MJ_BizApps_Issues: Issue Number Sequences') // Tell MemberJunction about this class
@Component({
    standalone: false,
    selector: 'gen-mjbizappsissuesissuenumbersequence-form',
    templateUrl: './mjbizappsissuesissuenumbersequence.form.component.html'
})
export class mjBizAppsIssuesIssueNumberSequenceFormComponent extends BaseFormComponent {
    public record!: mjBizAppsIssuesIssueNumberSequenceEntity;

    override async ngOnInit() {
        await super.ngOnInit();
        this.initSections([
            { sectionKey: 'details', sectionName: 'Details', isExpanded: true }
        ]);
    }
}

