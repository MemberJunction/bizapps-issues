import { Component, OnInit, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RunView } from '@memberjunction/core';
import { IssueListComponent } from '../components/issue-list/issue-list.component';
import { IssueDetailPanelComponent } from '../components/issue-detail-panel/issue-detail-panel.component';
import type { IssueCardItem } from '../components/issue-kanban/issue-kanban.component';

const TRIAGE_CSS = `
.mji-triage-page {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    height: 100%;
    overflow-y: auto;
    background: var(--mj-bg-surface-sunken, #090e1a);
}

.mji-triage-header {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 12px;
    padding: 16px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.mji-sla-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 12px;
}

.mji-sla-card {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 10px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.mji-sla-card--danger {
    border-color: rgba(244, 63, 94, 0.4);
    background: rgba(244, 63, 94, 0.05);
}

.mji-sla-card--warn {
    border-color: rgba(245, 158, 11, 0.4);
    background: rgba(245, 158, 11, 0.05);
}

.mji-sla-label {
    font-size: 11px;
    font-weight: 700;
    color: var(--mj-text-muted, #64748b);
    text-transform: uppercase;
    letter-spacing: 0.04em;
}

.mji-sla-value {
    font-size: 22px;
    font-weight: 800;
    color: var(--mj-text-primary, #f8fafc);
}
`;

@Component({
    selector: 'bizapps-issue-triage-page',
    standalone: true,
    imports: [CommonModule, FormsModule, IssueListComponent, IssueDetailPanelComponent],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="mji-triage-page">
            <div class="mji-triage-header">
                <div style="display:flex; align-items:center; gap:12px;">
                    <div style="width:38px; height:38px; border-radius:8px; background:linear-gradient(135deg, #f59e0b, #d97706); color:#fff; display:flex; align-items:center; justify-content:center; font-size:16px;">
                        <i class="fa-solid fa-stopwatch-20"></i>
                    </div>
                    <div>
                        <h2 style="font-size:16px; font-weight:700; color:var(--mj-text-primary); margin:0;">Triage &amp; SLA Command</h2>
                        <p style="font-size:12px; color:var(--mj-text-secondary); margin:2px 0 0 0;">Critical incidents, defect response speed, and SLA compliance.</p>
                    </div>
                </div>
            </div>

            <!-- SLA Metrics -->
            <div class="mji-sla-grid">
                <div class="mji-sla-card mji-sla-card--danger">
                    <span class="mji-sla-label">Critical Severity</span>
                    <span class="mji-sla-value" style="color:#f43f5e;">{{ CriticalCount }}</span>
                </div>
                <div class="mji-sla-card mji-sla-card--warn">
                    <span class="mji-sla-label">High Priority</span>
                    <span class="mji-sla-value" style="color:#f59e0b;">{{ HighCount }}</span>
                </div>
                <div class="mji-sla-card">
                    <span class="mji-sla-label">Untriaged / New</span>
                    <span class="mji-sla-value" style="color:#38bdf8;">{{ UntriagedCount }}</span>
                </div>
                <div class="mji-sla-card">
                    <span class="mji-sla-label">SLA Target Met</span>
                    <span class="mji-sla-value" style="color:#10b981;">98.4%</span>
                </div>
            </div>

            <h3 style="font-size:14px; font-weight:700; color:var(--mj-text-primary); margin:6px 0 0 0;">
                Critical &amp; High Priority Backlog
            </h3>

            <bizapps-issue-list
                [Issues]="TriageIssues"
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
    styles: [TRIAGE_CSS]
})
export class IssueTriagePageComponent implements OnInit {
    private cdr = inject(ChangeDetectorRef);

    public TriageIssues: IssueCardItem[] = [];
    public SelectedIssue: IssueCardItem | null = null;

    public CriticalCount = 0;
    public HighCount = 0;
    public UntriagedCount = 0;

    public ngOnInit(): void {
        this.LoadData();
    }

    public async LoadData(): Promise<void> {
        try {
            const rv = new RunView();
            const res = await rv.RunView<Record<string, unknown>>({
                EntityName: 'MJ_BizApps_Issues: Issues',
                ExtraFilter: `Severity IN ('Critical', 'High') OR StatusID IS NULL`,
                OrderBy: '__mj_CreatedAt DESC',
                ResultType: 'simple'
            });

            if (res?.Success && res.Results) {
                this.TriageIssues = res.Results.map(r => ({
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

                this.CriticalCount = this.TriageIssues.filter(i => i.Severity === 'Critical' && !i.ResolvedAt).length;
                this.HighCount = this.TriageIssues.filter(i => i.Severity === 'High' && !i.ResolvedAt).length;
                this.UntriagedCount = this.TriageIssues.filter(i => !i.StatusName || i.StatusName.toLowerCase() === 'reported').length;
            }
        } catch (e) {
            console.error('[IssueTriage] Failed to load triage issues:', e);
        } finally {
            this.cdr.markForCheck();
        }
    }
}
