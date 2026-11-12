import { DeliverDueReminder } from '../../src/inactivity/application/deliverDueReminder';
import { RecordWorkoutActivity } from '../../src/inactivity/application/recordWorkoutActivity';
import { type ReminderPassLimits, RunReminderPass } from '../../src/inactivity/application/runReminderPass';
import { SyncReminderPreferences } from '../../src/inactivity/application/syncReminderPreferences';
import type { ActivitySource } from '../../src/inactivity/domain/activityTime';
import { defaultReminderPolicy } from '../../src/inactivity/domain/reminderPolicy';
import { pseudonymForLogs } from '../../src/shared/infrastructure/runtimeAdapters';
import {
  FakeClock,
  FakeDeliveryGate,
  FakePreferences,
  FakeSender,
  FakeTokens,
  InMemoryDueFinder,
  InMemoryStateStore,
  RecordingLogger,
  SequentialIds,
} from './inactivityFakes';

/** Saturday 2026-11-07 18:00 in Cairo (UTC+2): the approved example. */
export const SATURDAY_18_CAIRO = Date.UTC(2026, 10, 7, 16, 0);

/** The app's offset-less Dart `toIso8601String()` for a Cairo wall time. */
export function dartLocalIso(utcMs: number, offsetHours = 2): string {
  return new Date(utcMs + offsetHours * 3600_000).toISOString().replace('Z', '');
}

/** Real use cases wired to in-memory adapters, as the composition root does. */
export function inactivityHarness(startMs: number, limits?: Partial<ReminderPassLimits>) {
  const policy = defaultReminderPolicy;
  const clock = new FakeClock(startMs);
  const store = new InMemoryStateStore();
  const finder = new InMemoryDueFinder(store);
  const preferences = new FakePreferences();
  const tokens = new FakeTokens();
  const sender = new FakeSender();
  const logger = new RecordingLogger();
  const ids = new SequentialIds();
  const gate = new FakeDeliveryGate();
  const runtime = { clock, logger, pseudonym: pseudonymForLogs };

  const record = new RecordWorkoutActivity({ ...runtime, store, preferences, policy });
  const sync = new SyncReminderPreferences({ ...runtime, store, preferences, policy });
  const deliver = new DeliverDueReminder({ ...runtime, store, tokens, sender, ids, policy });
  const pass = new RunReminderPass({
    finder,
    deliver,
    gate,
    clock,
    logger,
    limits: { pageSize: 200, concurrency: 10, maxUsersPerRun: 5000, timeBudgetMs: 7 * 60_000, ...limits },
  });

  /** An activity document created now (server arrival = clock). */
  const activity = (uid: string, source: ActivitySource, occurredAtRaw: unknown = dartLocalIso(clock.nowMs())) =>
    record.execute({ uid, source, occurredAtRaw, receivedAtMs: clock.nowMs() });

  return { policy, clock, store, finder, preferences, tokens, sender, logger, ids, gate, record, sync, deliver, pass, activity };
}

export type InactivityHarness = ReturnType<typeof inactivityHarness>;
