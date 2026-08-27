import { RunView, type IMetadataProvider } from '@memberjunction/core';
import type { IntegrationCheckContext } from '@memberjunction/testing-integration/registry';
import { Assert } from '@memberjunction/testing-integration/registry';

export function Quote(v: string): string { return v.replace(/'/g, "''"); }
export function View(ctx: IntegrationCheckContext): RunView {
    return RunView.FromMetadataProvider(ctx.Provider as IMetadataProvider);
}
export async function FindRows<T extends object>(ctx: IntegrationCheckContext, entityName: string, extraFilter: string, fields: string[]): Promise<T[]> {
    const res = await View(ctx).RunView<T>({ EntityName: entityName, ExtraFilter: extraFilter, Fields: fields, ResultType: 'simple' }, ctx.User);
    Assert(res.Success, `RunView ${entityName}: ${res.ErrorMessage ?? 'unknown'}`);
    return res.Results ?? [];
}
export async function FindId(ctx: IntegrationCheckContext, entityName: string, extraFilter: string): Promise<string | null> {
    const rows = await FindRows<{ ID: string }>(ctx, entityName, extraFilter, ['ID']);
    return rows[0]?.ID ?? null;
}
export async function RequireSave(entity: { Save: () => Promise<boolean>; LatestResult?: { CompleteMessage?: string } }, what: string): Promise<void> {
    Assert(await entity.Save(), `${what}: ${entity.LatestResult?.CompleteMessage ?? 'unknown'}`);
}
