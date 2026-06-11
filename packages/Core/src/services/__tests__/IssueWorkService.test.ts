import { describe, it, expect, beforeEach, vi } from 'vitest';

// ---------------------------------------------------------------------------
// IssueWorkService uses:
//   - new Metadata().GetEntityObject(name, user) → Task / TaskLink entities
//   - new Metadata().EntityByName('MJ_BizApps_Issues: Issues') → { ID }
//   - IssueEngine.Instance.IssueTypeByID(id) → { DefaultTaskTypeID }
// We mock all of it. Fake Task/TaskLink expose plain writable props + Save().
// ---------------------------------------------------------------------------

const getEntityObjectMock = vi.fn();
const entityByNameMock = vi.fn();

vi.mock('@memberjunction/core', () => ({
  Metadata: class {
    GetEntityObject(...args: unknown[]) {
      return getEntityObjectMock(...args);
    }
    EntityByName(...args: unknown[]) {
      return entityByNameMock(...args);
    }
  },
  UserInfo: class {},
  LogError: vi.fn(),
}));

const typeById = new Map<string, { ID: string; DefaultTaskTypeID: string | null }>();
vi.mock('../IssueEngine.js', () => ({
  IssueEngine: {
    Instance: {
      Config: vi.fn(async () => undefined),
      IssueTypeByID: (id: string) => typeById.get(id),
    },
  },
}));

import { IssueWorkService } from '../IssueWorkService.js';

function makeFake(saveResult = true) {
  return {
    NewRecord: vi.fn(),
    Save: vi.fn(async () => saveResult),
    LatestResult: { CompleteMessage: 'err' },
  } as Record<string, unknown> & { NewRecord: ReturnType<typeof vi.fn>; Save: ReturnType<typeof vi.fn> };
}

const issue = {
  ID: 'ISS-1',
  Title: 'Broken thing',
  Description: 'details',
  IssueTypeID: 'T-BUG',
  Priority: 'High',
} as never;

const ctx = {} as never;

beforeEach(() => {
  vi.clearAllMocks();
  typeById.clear();
  typeById.set('T-BUG', { ID: 'T-BUG', DefaultTaskTypeID: 'TT-DEFAULT' });
  entityByNameMock.mockReturnValue({ ID: 'ENT-ISSUES' });
});

describe('IssueWorkService.SpawnTask', () => {
  it('creates a Task (from the IssueType default task type) and a TaskLink back to the issue', async () => {
    const task = makeFake();
    task.ID = 'TASK-1';
    const link = makeFake();
    getEntityObjectMock.mockResolvedValueOnce(task).mockResolvedValueOnce(link);

    const result = await new IssueWorkService().SpawnTask(issue, ctx);

    expect(result).toBe(task);
    // Task fields
    expect(task.Name).toBe('Broken thing');
    expect(task.TypeID).toBe('TT-DEFAULT'); // from IssueType.DefaultTaskTypeID
    expect(task.Status).toBe('Open');
    expect(task.Priority).toBe('High'); // inherited from issue
    // TaskLink fields (polymorphic back-reference)
    expect(link.TaskID).toBe('TASK-1');
    expect(link.EntityID).toBe('ENT-ISSUES');
    expect(link.RecordID).toBe('ISS-1');
    expect(link.Save).toHaveBeenCalledOnce();
  });

  it('prefers an explicit TaskTypeID param over the IssueType default', async () => {
    const task = makeFake();
    task.ID = 'TASK-2';
    getEntityObjectMock.mockResolvedValueOnce(task).mockResolvedValueOnce(makeFake());

    await new IssueWorkService().SpawnTask(issue, ctx, { TaskTypeID: 'TT-EXPLICIT', Name: 'Custom', Priority: 'Low' });

    expect(task.TypeID).toBe('TT-EXPLICIT');
    expect(task.Name).toBe('Custom');
    expect(task.Priority).toBe('Low');
  });

  it('returns null when no TaskType can be resolved (param missing AND no IssueType default)', async () => {
    typeById.set('T-BUG', { ID: 'T-BUG', DefaultTaskTypeID: null });
    const result = await new IssueWorkService().SpawnTask(issue, ctx);
    expect(result).toBeNull();
    expect(getEntityObjectMock).not.toHaveBeenCalled();
  });

  it('returns null when the Issues entity ID cannot be resolved', async () => {
    entityByNameMock.mockReturnValue(undefined);
    const result = await new IssueWorkService().SpawnTask(issue, ctx);
    expect(result).toBeNull();
  });

  it('returns null when the Task save fails (no link attempted)', async () => {
    const task = makeFake(false);
    getEntityObjectMock.mockResolvedValueOnce(task);
    const result = await new IssueWorkService().SpawnTask(issue, ctx);
    expect(result).toBeNull();
    expect(getEntityObjectMock).toHaveBeenCalledTimes(1); // link never requested
  });
});
