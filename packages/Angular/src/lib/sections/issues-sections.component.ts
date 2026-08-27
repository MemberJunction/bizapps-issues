import { Component, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RegisterClass } from '@memberjunction/global';
import { BaseResourceComponent } from '@memberjunction/ng-shared';
import type { ResourceData } from '@memberjunction/core-entities';
import { IssuesDashboardPageComponent } from '../pages/issues-dashboard.page';
import { MyIssuesPageComponent } from '../pages/my-issues.page';
import { IssueTriagePageComponent } from '../pages/issue-triage.page';
import { IssueTypesPageComponent } from '../pages/issue-types.page';

/**
 * 1. Issues Section Resource — Main Issues Dashboard Tab
 */
@Component({
    selector: 'bizapps-issues-section-resource',
    standalone: true,
    imports: [CommonModule, IssuesDashboardPageComponent],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `<bizapps-issues-dashboard-page></bizapps-issues-dashboard-page>`,
    styles: [`:host { display: block; width: 100%; height: 100%; }`],
})
@RegisterClass(BaseResourceComponent, 'IssuesSectionResource')
export class IssuesSectionResource extends BaseResourceComponent {
    override ngOnInit(): void {
        super.ngOnInit();
        this.NotifyLoadComplete();
    }

    async GetResourceDisplayName(_data: ResourceData): Promise<string> {
        return 'Issues';
    }

    async GetResourceIconClass(_data: ResourceData): Promise<string> {
        return 'fa-solid fa-bug';
    }
}

/**
 * 2. My Issues Section Resource — User Assigned / Reported Tab
 */
@Component({
    selector: 'bizapps-my-issues-section-resource',
    standalone: true,
    imports: [CommonModule, MyIssuesPageComponent],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `<bizapps-my-issues-page></bizapps-my-issues-page>`,
    styles: [`:host { display: block; width: 100%; height: 100%; }`],
})
@RegisterClass(BaseResourceComponent, 'MyIssuesSectionResource')
export class MyIssuesSectionResource extends BaseResourceComponent {
    override ngOnInit(): void {
        super.ngOnInit();
        this.NotifyLoadComplete();
    }

    async GetResourceDisplayName(_data: ResourceData): Promise<string> {
        return 'My Issues';
    }

    async GetResourceIconClass(_data: ResourceData): Promise<string> {
        return 'fa-solid fa-user-shield';
    }
}

/**
 * 3. Triage & SLAs Section Resource — Defect Escalation & SLA Tab
 */
@Component({
    selector: 'bizapps-issue-triage-section-resource',
    standalone: true,
    imports: [CommonModule, IssueTriagePageComponent],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `<bizapps-issue-triage-page></bizapps-issue-triage-page>`,
    styles: [`:host { display: block; width: 100%; height: 100%; }`],
})
@RegisterClass(BaseResourceComponent, 'IssueTriageSectionResource')
export class IssueTriageSectionResource extends BaseResourceComponent {
    override ngOnInit(): void {
        super.ngOnInit();
        this.NotifyLoadComplete();
    }

    async GetResourceDisplayName(_data: ResourceData): Promise<string> {
        return 'Triage & SLAs';
    }

    async GetResourceIconClass(_data: ResourceData): Promise<string> {
        return 'fa-solid fa-stopwatch-20';
    }
}

/**
 * 4. Issue Types Section Resource — Types & Workflows Tab
 */
@Component({
    selector: 'bizapps-issue-types-section-resource',
    standalone: true,
    imports: [CommonModule, IssueTypesPageComponent],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `<bizapps-issue-types-page></bizapps-issue-types-page>`,
    styles: [`:host { display: block; width: 100%; height: 100%; }`],
})
@RegisterClass(BaseResourceComponent, 'IssueTypesSectionResource')
export class IssueTypesSectionResource extends BaseResourceComponent {
    override ngOnInit(): void {
        super.ngOnInit();
        this.NotifyLoadComplete();
    }

    async GetResourceDisplayName(_data: ResourceData): Promise<string> {
        return 'Types & Workflows';
    }

    async GetResourceIconClass(_data: ResourceData): Promise<string> {
        return 'fa-solid fa-tags';
    }
}

/**
 * Tree-shaking prevention anchor
 */
export function LoadIssuesSectionResources(): void {
    void IssuesSectionResource;
    void MyIssuesSectionResource;
    void IssueTriageSectionResource;
    void IssueTypesSectionResource;
}
