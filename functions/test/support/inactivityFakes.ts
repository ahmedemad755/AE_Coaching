import type {
  DeliveryGateReader,
  DeviceSendOutcome,
  DueReminderFinder,
  DueReminderPage,
  InactivityStateStore,
  RecipientToken,
  ReminderPreferencesReader,
  ReminderPush,
  ReminderPushSender,
  ReminderRecipientTokens,
} from '../../src/inactivity/application/ports';
import { type DeliveryGate, DEFAULT_MAX_SENDS_PER_PASS } from '../../src/inactivity/domain/deliveryGate';
import type { InactivityState } from '../../src/inactivity/domain/inactivityState';
import type { RawReminderPreferences } from '../../src/inactivity/domain/reminderPreferences';
import type { Clock, IdGenerator, LogFields, StructuredLogger } from '../../src/shared/application/runtimePorts';

export const HOUR = 3600_000;
export const DAY = 24 * HOUR;

export class FakeClock implements Clock {
  constructor(public current: number) {}
  nowMs(): number {
    return this.current;
  }
  advance(ms: number): void {
    this.current += ms;
  }
  set(ms: number): void {
    this.current = ms;
  }
}

export class SequentialIds implements IdGenerator {
  private next = 0;
  newId(): string {
    this.next += 1;
    return `lease-${this.next}`;
  }
}

/**
 * Behaves like a Firestore transaction: the mutation sees a snapshot, the
 * commit fails (and the mutation re-runs) if another update committed in
 * between, so parallel callers really race. [crashOnCommit] makes the Nth
 * commit throw before writing, simulating a process crash at that point.
 */
export class InMemoryStateStore implements InactivityStateStore {
  readonly docs = new Map<string, { state: InactivityState; version: number }>();
  commits = 0;
  crashOnCommit: number | null = null;

  async update<T>(
    uid: string,
    mutate: (current: InactivityState | null) => { readonly next: InactivityState | null; readonly result: T },
  ): Promise<T> {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const before = this.docs.get(uid);
      const version = before?.version ?? 0;
      const { next, result } = mutate(before === undefined ? null : structuredClone(before.state));
      await new Promise((resolve) => setImmediate(resolve));
      if ((this.docs.get(uid)?.version ?? 0) !== version) continue;
      this.commits += 1;
      if (this.crashOnCommit === this.commits) throw new Error('simulated crash');
      if (next !== null) this.docs.set(uid, { state: structuredClone(next), version: version + 1 });
      return result;
    }
    throw new Error('transaction contention');
  }

  get(uid: string): InactivityState | undefined {
    return this.docs.get(uid)?.state;
  }

  put(uid: string, state: InactivityState): void {
    this.docs.set(uid, { state: structuredClone(state), version: (this.docs.get(uid)?.version ?? 0) + 1 });
  }
}

/**
 * Mirrors the Firestore query: only `nextReminderAt <= now`, ordered by
 * (nextReminderAt, document). The cursor captures the last returned
 * document's ordering values at query time, like `startAfter(snapshot)`, so
 * documents that change after being returned neither repeat nor shift pages.
 */
export class InMemoryDueFinder implements DueReminderFinder {
  queries = 0;
  constructor(private readonly store: InMemoryStateStore) {}

  async findDue(nowMs: number, limit: number, cursor: unknown | null): Promise<DueReminderPage> {
    this.queries += 1;
    const after = cursor as { atMs: number; uid: string } | null;
    const due = [...this.store.docs.entries()]
      .flatMap(([uid, doc]) => {
        const atMs = doc.state.nextReminderAtMs;
        return atMs !== null && atMs <= nowMs ? [{ uid, atMs }] : [];
      })
      .sort((a, b) => a.atMs - b.atMs || a.uid.localeCompare(b.uid))
      .filter((d) => after === null || d.atMs > after.atMs || (d.atMs === after.atMs && d.uid.localeCompare(after.uid) > 0));
    const page = due.slice(0, limit);
    const last = page.at(-1);
    return { uids: page.map((d) => d.uid), cursor: page.length < limit || last === undefined ? null : { ...last } };
  }
}

export class FakePreferences implements ReminderPreferencesReader {
  readonly byUid = new Map<string, RawReminderPreferences>();
  reads = 0;
  /**
   * Users without an explicit document still have one (empty: all
   * defaults), i.e. they run an app build that writes its preferences.
   * Set false to model users still on an older build (no document).
   */
  documentByDefault = true;
  async read(uid: string): Promise<RawReminderPreferences | null> {
    this.reads += 1;
    return this.byUid.get(uid) ?? (this.documentByDefault ? {} : null);
  }
}

/** The operator's delivery switch; `all` unless a test closes it. */
export class FakeDeliveryGate implements DeliveryGateReader {
  gate: DeliveryGate = { mode: 'all', maxSendsPerPass: DEFAULT_MAX_SENDS_PER_PASS };
  reads = 0;
  fail = false;
  /** Called on every read, e.g. to switch the gate mid-pass. */
  onRead: ((read: number) => void) | null = null;
  async read(): Promise<DeliveryGate> {
    this.reads += 1;
    this.onRead?.(this.reads);
    if (this.fail) throw new Error('config unavailable');
    return this.gate;
  }
}

export class FakeTokens implements ReminderRecipientTokens {
  readonly byUid = new Map<string, RecipientToken[]>();
  readonly discardByUid = new Map<string, string[]>();
  readonly removed: { uid: string; ids: string[] }[] = [];
  failListing = false;
  /** Runs while devices are being looked up (between claim and sending). */
  duringListing: (() => Promise<void>) | null = null;

  async listDeliverableTokens(uid: string) {
    if (this.duringListing !== null) await this.duringListing();
    if (this.failListing) throw new Error('token listing unavailable');
    return { deliverable: [...(this.byUid.get(uid) ?? [])], discard: [...(this.discardByUid.get(uid) ?? [])] };
  }

  async removeTokens(uid: string, tokenIds: readonly string[]): Promise<void> {
    this.removed.push({ uid, ids: [...tokenIds] });
    this.byUid.set(
      uid,
      (this.byUid.get(uid) ?? []).filter((token) => !tokenIds.includes(token.id)),
    );
  }
}

export class FakeSender implements ReminderPushSender {
  readonly sends: ReminderPush[] = [];
  /** Outcome per token id; default 'accepted'. */
  readonly outcomes = new Map<string, DeviceSendOutcome>();
  throwError = false;
  /** Runs while "FCM" handles the request (e.g. activity arrives). */
  duringSend: (() => Promise<void>) | null = null;

  async send(push: ReminderPush) {
    this.sends.push(push);
    if (this.duringSend !== null) await this.duringSend();
    if (this.throwError) throw new Error('fcm unavailable');
    return push.tokens.map((token) => ({ tokenId: token.id, outcome: this.outcomes.get(token.id) ?? 'accepted' }));
  }
}

export class RecordingLogger implements StructuredLogger {
  readonly entries: { level: string; event: string; fields?: LogFields }[] = [];
  info(event: string, fields?: LogFields): void {
    this.entries.push({ level: 'info', event, fields });
  }
  warn(event: string, fields?: LogFields): void {
    this.entries.push({ level: 'warn', event, fields });
  }
  error(event: string, fields?: LogFields): void {
    this.entries.push({ level: 'error', event, fields });
  }
  text(): string {
    return JSON.stringify(this.entries);
  }
}

export function token(id: string): RecipientToken {
  return { id, token: `raw-device-token-${id}` };
}
