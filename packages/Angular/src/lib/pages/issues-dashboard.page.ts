import { Component, OnInit, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RunView, CompositeKey } from '@memberjunction/core';
import { NavigationService } from '@memberjunction/ng-shared';
import type { mjBizAppsIssuesIssueStatusEntity, mjBizAppsIssuesIssueTypeEntity } from '@mj-biz-apps/issues-entities';
import { IssueKanbanComponent, IssueCardItem } from '../components/issue-kanban/issue-kanban.component';
import { IssueListComponent } from '../components/issue-list/issue-list.component';
import { IssueDetailPanelComponent } from '../components/issue-detail-panel/issue-detail-panel.component';
import { IssueEditPanelComponent } from '../components/issue-edit-panel/issue-edit-panel.component';

export type IssueViewMode = 'kanban' | 'list';

export interface IssueKPIs {
    TotalActive: number;
    Critical: number;
    InTriage: number;
    Resolved: number;
    Closed: number;
}

const DASHBOARD_CSS = `
.mji-dashboard {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 20px;
    height: 100%;
    overflow-y: auto;
    background: var(--mj-bg-surface-sunken, #090e1a);
    scrollbar-width: thin;
}

.mji-header-card {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: var(--mj-radius-lg, 14px);
    padding: 18px 22px;
    display: flex;
    flex-direction: column;
    gap: 16px;
}

.mji-header-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    flex-wrap: wrap;
}

.mji-identity {
    display: flex;
    align-items: center;
    gap: 14px;
}

.mji-avatar {
    width: 44px;
    height: 44px;
    border-radius: 10px;
    background: linear-gradient(135deg, #f43f5e, #be123c);
    color: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    flex-shrink: 0;
}

.mji-title {
    font-size: 18px;
    font-weight: 700;
    color: var(--mj-text-primary, #f8fafc);
    margin: 0;
}

.mji-subtitle {
    font-size: 12.5px;
    color: var(--mj-text-secondary, #94a3b8);
    margin: 2px 0 0 0;
}

.mji-actions-strip {
    display: flex;
    align-items: center;
    gap: 10px;
}

.mji-view-toggle {
    display: flex;
    background: var(--mj-bg-surface-sunken, #090e1a);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    padding: 2px;
}

.mji-view-btn {
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    color: var(--mj-text-secondary, #94a3b8);
    background: none;
    border: none;
    cursor: pointer;
    transition: all 0.15s ease;
    display: flex;
    align-items: center;
    gap: 6px;
}

.mji-view-btn.active {
    background: var(--mj-bg-surface-elevated, #1a2744);
    color: var(--mj-text-primary, #f8fafc);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

.mji-btn-primary {
    background: var(--mj-brand-primary, #38bdf8);
    color: #090e1a;
    font-size: 12.5px;
    font-weight: 700;
    padding: 8px 16px;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 6px;
    transition: all 0.15s ease;
}

.mji-btn-primary:hover {
    filter: brightness(1.1);
    transform: translateY(-1px);
}

.mji-kpi-bar {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
    gap: 12px;
    padding-top: 14px;
    border-top: 1px solid rgba(255, 255, 255, 0.04);
}

.mji-kpi-tile {
    display: flex;
    flex-direction: column;
    gap: 2px;
}

.mji-kpi-label {
    font-size: 10.5px;
    font-weight: 700;
    color: var(--mj-text-muted, #64748b);
    text-transform: uppercase;
    letter-spacing: 0.04em;
}

.mji-kpi-val {
    font-size: 18px;
    font-weight: 800;
    color: var(--mj-text-primary, #f8fafc);
}

.mji-val--red { color: #f43f5e; }
.mji-val--amber { color: #f59e0b; }
.mji-val--green { color: #10b981; }
.mji-val--blue { color: #38bdf8; }

.mji-filters-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
}

.mji-search-box {
    position: relative;
    width: 260px;
}

.mji-search-input {
    width: 100%;
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    color: var(--mj-text-primary, #f8fafc);
    padding: 8px 12px 8px 32px;
    font-size: 12.5px;
}

.mji-search-icon {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--mj-text-muted, #64748b);
    font-size: 12px;
}

.mji-filter-group {
    display: flex;
    align-items: center;
    gap: 8px;
}

.mji-select-filter {
    background: var(--mj-bg-surface-card, #141f36);
    border: 1px solid var(--mj-border-default, #223254);
    border-radius: 8px;
    color: var(--mj-text-primary, #f8fafc);
    padding: 6px 10px;
    font-size: 12px;
}
`;

@Component({
    selector: 'bizapps-issues-dashboard-page',
    standalone: true,
    imports: [
        CommonModule,
        FormsModule,
        IssueKanbanComponent,
        IssueListComponent,
        IssueDetailPanelComponent,
        IssueEditPanelComponent,
    ],
    changeDetection: ChangeDetectionStrategy.OnPush,
    template: `
        <div class="mji-dashboard">
            <!-- 1. Header Toolbar & Quick Stats -->
            <div class="mji-header-card">
                <div class="mji-header-top">
                    <div class="mji-identity">
                        <div class="mji-avatar">
                            <i class="fa-solid fa-bug" aria-hidden="true"></i>
                        </div>
                        <div>
                            <h1 class="mji-title">Issues &amp; Defect Triage</h1>
                            <p class="mji-subtitle">Incident tracking, defect triage, Kanban workflows, and resolution lifecycle.</p>
                        </div>
                    </div>

                    <div class="mji-actions-strip">
                        <!-- View Toggle -->
                        <div class="mji-view-toggle">
                            <button
                                type="button"
                                class="mji-view-btn"
                                [class.active]="ViewMode === 'kanban'"
                                (click)="SetView('kanban')">
                                <i class="fa-solid fa-columns"></i> Board
                            </button>
                            <button
                                type="button"
                                class="mji-view-btn"
                                [class.active]="ViewMode === 'list'"
                                (click)="SetView('list')">
                                <i class="fa-solid fa-list"></i> List
                            </button>
                        </div>

                        <button type="button" class="mji-btn-primary" (click)="ShowNewDialog = true">
                            <i class="fa-solid fa-plus"></i> Report Issue
                        </button>
                    </div>
                </div>

                <!-- Live KPI Strip -->
                <div class="mji-kpi-bar">
                    <div class="mji-kpi-tile">
                        <span class="mji-kpi-label">Active Issues</span>
                        <span class="mji-kpi-val">{{ KPIs.TotalActive }}</span>
                    </div>
                    <div class="mji-kpi-tile">
                        <span class="mji-kpi-label">Critical Severity</span>
                        <span class="mji-kpi-val" [class.mji-val--red]="KPIs.Critical > 0">{{ KPIs.Critical }}</span>
                    </div>
                    <div class="mji-kpi-tile">
                        <span class="mji-kpi-label">In Triage</span>
                        <span class="mji-kpi-val mji-val--amber">{{ KPIs.InTriage }}</span>
                    </div>
                    <div class="mji-kpi-tile">
                        <span class="mji-kpi-label">Resolved</span>
                        <span class="mji-kpi-val mji-val--green">{{ KPIs.Resolved }}</span>
                    </div>
                    <div class="mji-kpi-tile">
                        <span class="mji-kpi-label">Closed</span>
                        <span class="mji-kpi-val mji-val--blue">{{ KPIs.Closed }}</span>
                    </div>
                </div>
            </div>

            <!-- 2. Search & Filter Bar -->
            <div class="mji-filters-row">
                <div class="mji-search-box">
                    <i class="fa-solid fa-magnifying-glass mji-search-icon"></i>
                    <input
                        class="mji-search-input"
                        [(ngModel)]="SearchTerm"
                        (ngModelChange)="ApplyFilters()"
                        placeholder="Search issues..." />
                </div>

                <div class="mji-filter-group">
                    <select class="mji-select-filter" [(ngModel)]="SeverityFilter" (ngModelChange)="ApplyFilters()">
                        <option value="all">All Severities</option>
                        <option value="Critical">Critical</option>
                        <option value="High">High</option>
                        <option value="Medium">Medium</option>
                        <option value="Low">Low</option>
                    </select>

                    <select class="mji-select-filter" [(ngModel)]="ScopeFilter" (ngModelChange)="ApplyFilters()">
                        <option value="all">All Scopes</option>
                        @for (scope of AppScopes; track scope) {
                            <option [value]="scope">{{ scope }}</option>
                        }
                    </select>
                </div>
            </div>

            <!-- 3. Primary Content Views -->
            @if (ViewMode === 'kanban') {
                <bizapps-issue-kanban
                    [Issues]="FilteredIssues"
                    [Statuses]="Statuses"
                    (IssueSelected)="OnIssueSelect($event)">
                </bizapps-issue-kanban>
            } @else {
                <bizapps-issue-list
                    [Issues]="FilteredIssues"
                    (IssueSelected)="OnIssueSelect($event)">
                </bizapps-issue-list>
            }

            <!-- 4. Slide-in Detail Drawer -->
            @if (SelectedIssue) {
                <bizapps-issue-detail-panel
                    [Issue]="SelectedIssue"
                    (Close)="SelectedIssue = null">
                </bizapps-issue-detail-panel>
            }

            <!-- 5. Create Issue Modal -->
            @if (ShowNewDialog) {
                <bizapps-issue-edit-panel
                    [IssueTypes]="IssueTypes"
                    [Statuses]="Statuses"
                    (Saved)="OnIssueSaved()"
                    (Cancel)="ShowNewDialog = false">
                </bizapps-issue-edit-panel>
            }
        </div>
    `,
    styles: [DASHBOARD_CSS]
})
export class IssuesDashboardPageComponent implements OnInit {
    private cdr = inject(ChangeDetectorRef);
    private navService = inject(NavigationService, { optional: true });

    public ViewMode: IssueViewMode = 'kanban';
    public AllIssues: IssueCardItem[] = [];
    public FilteredIssues: IssueCardItem[] = [];
    public Statuses: mjBizAppsIssuesIssueStatusEntity[] = [];
    public IssueTypes: mjBizAppsIssuesIssueTypeEntity[] = [];
    public AppScopes: string[] = [];

    public SearchTerm = '';
    public SeverityFilter = 'all';
    public ScopeFilter = 'all';

    public SelectedIssue: IssueCardItem | null = null;
    public ShowNewDialog = false;

    public KPIs: IssueKPIs = {
        TotalActive: 0,
        Critical: 0,
        InTriage: 0,
        Resolved: 0,
        Closed: 0
    };

    public ngOnInit(): void {
        this.LoadData();
    }

    public SetView(mode: IssueViewMode): void {
        this.ViewMode = mode;
        this.cdr.markForCheck();
    }

    public async LoadData(): Promise<void> {
        try {
            const rv = new RunView();

            // Load statuses
            const statusRes = await rv.RunView<mjBizAppsIssuesIssueStatusEntity>({
                EntityName: 'MJ_BizApps_Issues: Issue Status',
                OrderBy: 'Sequence ASC',
                ResultType: 'entity_object'
            });
            if (statusRes?.Success && statusRes.Results) {
                this.Statuses = statusRes.Results;
            }

            // Load issue types
            const typeRes = await rv.RunView<mjBizAppsIssuesIssueTypeEntity>({
                EntityName: 'MJ_BizApps_Issues: Issue Types',
                ResultType: 'entity_object'
            });
            if (typeRes?.Success && typeRes.Results) {
                this.IssueTypes = typeRes.Results;
            }

            // Load issues
            const issueRes = await rv.RunView<Record<string, unknown>>({
                EntityName: 'MJ_BizApps_Issues: Issues',
                OrderBy: '__mj_CreatedAt DESC',
                MaxRows: 100,
                ResultType: 'simple'
            });

            if (issueRes?.Success && issueRes.Results) {
                this.AllIssues = issueRes.Results.map(r => ({
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

                const scopes = new Set<string>();
                this.AllIssues.forEach(i => { if (i.AppScope) scopes.add(i.AppScope); });
                this.AppScopes = Array.from(scopes);

                this.ComputeKPIs();
                this.ApplyFilters();
            }
        } catch (e) {
            console.error('[IssuesDashboard] Failed to load data:', e);
        } finally {
            this.cdr.markForCheck();
        }
    }

    public ComputeKPIs(): void {
        this.KPIs = {
            TotalActive: this.AllIssues.filter(i => !i.ResolvedAt).length,
            Critical: this.AllIssues.filter(i => i.Severity === 'Critical' && !i.ResolvedAt).length,
            InTriage: this.AllIssues.filter(i => i.StatusName?.toLowerCase().includes('triage') || i.StatusName?.toLowerCase() === 'reported').length,
            Resolved: this.AllIssues.filter(i => !!i.ResolvedAt).length,
            Closed: this.AllIssues.filter(i => i.StatusName?.toLowerCase() === 'closed').length
        };
    }

    public ApplyFilters(): void {
        const q = this.SearchTerm.trim().toLowerCase();
        this.FilteredIssues = this.AllIssues.filter(i => {
            const matchesSearch = !q || i.Title.toLowerCase().includes(q) || i.IssueNumber.toLowerCase().includes(q) || i.Description.toLowerCase().includes(q);
            const matchesSev = this.SeverityFilter === 'all' || i.Severity === this.SeverityFilter;
            const matchesScope = this.ScopeFilter === 'all' || i.AppScope === this.ScopeFilter;
            return matchesSearch && matchesSev && matchesScope;
        });
        this.cdr.markForCheck();
    }

    public OnIssueSelect(item: IssueCardItem): void {
        this.SelectedIssue = item;
        this.cdr.markForCheck();
    }

    public async OnIssueSaved(): Promise<void> {
        this.ShowNewDialog = false;
        await this.LoadData();
    }
}
