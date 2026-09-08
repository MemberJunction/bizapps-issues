import { Component, OnInit, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Metadata, RunView } from '@memberjunction/core';
import { IssueListComponent } from '../components/issue-list/issue-list.component';
import { IssueDetailPanelComponent } from '../components/issue-detail-panel/issue-detail-panel.component';
import type { IssueCardItem } from '../components/issue-kanban/issue-kanban.component';

const MY_ISSUES_CSS = `
.mji-my-issues {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    height: 100%;
    overflow-y: auto;
    background: var(--mj-bg-surface-sunken, #090e1a);
}

.mji-header {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 12px;
    padding: 16px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.mji-tabs {
    display: flex;
    gap: 8px;
}

.mji-tab-btn {
    padding: 6px 14px;
    border-radius: 8px;
    font-size: 12.5px;
    font-weight: 600;
    color: var(--mj-text-secondary, #94a3b8);
    background: none;
    border: 1px solid transparent;
    cursor: pointer;
    transition: all 0.15s ease;
}

.mji-tab-btn.active {
    background: var(--mj-bg-surface-elevated, #1a2744);
    border-color: var(--mj-border-default, #223254);
    color: var(--mj-text-primary, #f8fafc);
}
`;

@Component({
    selector: 'bizapps-my-issues-page',
    standalone: true,
    imports: [CommonModule, FormsModule, IssueListComponent, IssueDetailPanelComponent],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="mji-my-issues">
            <div class="mji-header">
                <div style="display:flex; align-items:center; gap:12px;">
                    <div style="width:38px; height:38px; border-radius:8px; background:linear-gradient(135deg, #10b981, #059669); color:#fff; display:flex; align-items:center; justify-content:center; font-size:16px;">
                        <i class="fa-solid fa-user-shield"></i>
                    </div>
                    <div>
                        <h2 style="font-size:16px; font-weight:700; color:var(--mj-text-primary); margin:0;">My Issues Hub</h2>
                        <p style="font-size:12px; color:var(--mj-text-secondary); margin:2px 0 0 0;">Issues reported by or assigned to you.</p>
                    </div>
                </div>

                <div class="mji-tabs">
                    <button
                        type="button"
                        class="mji-tab-btn"
                        [class.active]="ActiveTab === 'reported'"
                        (click)="SetTab('reported')">
                        Reported by Me ({{ ReportedIssues.length }})
                    </button>
                    <button
                        type="button"
                        class="mji-tab-btn"
                        [class.active]="ActiveTab === 'open'"
                        (click)="SetTab('open')">
                        Active Unresolved ({{ OpenIssues.length }})
                    </button>
                </div>
            </div>

            <bizapps-issue-list
                [Issues]="DisplayedIssues"
                (IssueSelected)="SelectedIssue = $event">
            </bizapps-issue-list>

            @if (SelectedIssue) {
                <bizapps-issue-detail-panel
                    [Issue]="SelectedIssue"
                    (Close)="SelectedIssue = null">
                </bizapps-issue-detail-panel>
            }
        </div>
    `,
    styles: [MY_ISSUES_CSS]
})
export class MyIssuesPageComponent implements OnInit {
    private cdr = inject(ChangeDetectorRef);

    public ActiveTab: 'reported' | 'open' = 'reported';
    public ReportedIssues: IssueCardItem[] = [];
    public OpenIssues: IssueCardItem[] = [];
    public SelectedIssue: IssueCardItem | null = null;

    public get DisplayedIssues(): IssueCardItem[] {
        return this.ActiveTab === 'reported' ? this.ReportedIssues : this.OpenIssues;
    }

    public ngOnInit(): void {
        this.LoadData();
    }

    public SetTab(tab: 'reported' | 'open'): void {
        this.ActiveTab = tab;
        this.cdr.markForCheck();
    }

    public async LoadData(): Promise<void> {
        try {
            // This page is "My Issues" — scope the query to the current user's own reports.
            // Without this filter the page listed the newest 50 issues of the WHOLE system
            // (including every reporter's email) and labeled them "Reported by Me".
            const currentEmail = new Metadata().CurrentUser?.Email?.trim();
            if (!currentEmail) {
                this.ReportedIssues = [];
                this.OpenIssues = [];
                return;
            }
            const escapedEmail = currentEmail.replace(/'/g, "''");

            const rv = new RunView();
            const res = await rv.RunView<Record<string, unknown>>({
                EntityName: 'MJ_BizApps_Issues: Issues',
                ExtraFilter: `ReporterEmail = '${escapedEmail}'`,
                OrderBy: '__mj_CreatedAt DESC',
                MaxRows: 50,
                ResultType: 'simple'
            });

            if (res?.Success && res.Results) {
                const items: IssueCardItem[] = res.Results.map(r => ({
                    ID: String(r['ID'] || ''),
                    IssueNumber: String(r['IssueNumber'] || 'ISSUE'),
                    Title: String(r['Title'] || 'Untitled Issue'),
                    Description: String(r['Description'] || ''),
                    Severity: (r['Severity'] as 'Critical' | 'High' | 'Low' | 'Medium') || 'Medium',
                    Priority: (r['Priority'] as 'Critical' | 'High' | 'Low' | 'Medium') || 'Medium',
                    StatusID: String(r['StatusID'] || ''),
                    StatusName: String(r['Status'] || r['StatusName'] || 'Reported'),
                    ReporterEmail: String(r['ReporterEmail'] || ''),
                    AppScope: String(r['AppScope'] || 'Explorer'),
                    CreatedAt: new Date(String(r['__mj_CreatedAt'] || Date.now())),
                    ResolvedAt: r['ResolvedAt'] ? new Date(String(r['ResolvedAt'])) : null
                }));

                this.ReportedIssues = items;
                this.OpenIssues = items.filter(i => !i.ResolvedAt);
            }
        } catch (e) {
            console.error('[MyIssues] Failed to load issues:', e);
        } finally {
            this.cdr.markForCheck();
        }
    }
}
