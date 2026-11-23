import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { DeliverDueReminder } from './inactivity/application/deliverDueReminder';
import { RecordWorkoutActivity } from './inactivity/application/recordWorkoutActivity';
import { defaultReminderPassLimits, RunReminderPass } from './inactivity/application/runReminderPass';
import { SyncReminderPreferences } from './inactivity/application/syncReminderPreferences';
import { defaultReminderPolicy } from './inactivity/domain/reminderPolicy';
import { FcmReminderPushSender } from './inactivity/infrastructure/fcmReminderPushSender';
import {
  FirestoreDueReminderFinder,
  FirestoreInactivityStateStore,
} from './inactivity/infrastructure/firestoreInactivityStateStore';
import { FirestoreDeliveryGateReader } from './inactivity/infrastructure/firestoreDeliveryGateReader';
import { FirestoreReminderPreferencesReader } from './inactivity/infrastructure/firestoreReminderPreferencesReader';
import { cloudLogger, pseudonymForLogs, randomIds, systemClock } from './shared/infrastructure/runtimeAdapters';
import { DeliverableTokenDirectory } from './tokens/application/deliverableTokenDirectory';
import { ReconcileTokenOwnership } from './tokens/application/reconcileTokenOwnership';
import {
  FirestoreTokenOwnershipRegistry,
  FirestoreUserTokenStore,
} from './tokens/infrastructure/firestoreTokenStores';

/**
 * Contract with the Flutter app: the routing `type` its
 * FcmNotificationRouting understands, and its existing Android channel.
 */
const reminderNotificationContract = {
  notificationType: 'inactivity_reminder',
  androidChannelId: 'inactivity_reminders',
} as const;

export interface AppServices {
  readonly recordWorkoutActivity: RecordWorkoutActivity;
  readonly syncReminderPreferences: SyncReminderPreferences;
  readonly runReminderPass: RunReminderPass;
  readonly reconcileTokenOwnership: ReconcileTokenOwnership;
}

function buildAppServices(): AppServices {
  const db = getFirestore();
  const policy = defaultReminderPolicy;
  const runtime = { clock: systemClock, logger: cloudLogger, pseudonym: pseudonymForLogs };

  const store = new FirestoreInactivityStateStore(db, policy);
  const preferences = new FirestoreReminderPreferencesReader(db);
  const registry = new FirestoreTokenOwnershipRegistry(db);
  const userTokens = new FirestoreUserTokenStore(db);

  const deliverDueReminder = new DeliverDueReminder({
    ...runtime,
    store,
    // Satisfies the inactivity feature's ReminderRecipientTokens port
    // structurally; neither feature imports the other.
    tokens: new DeliverableTokenDirectory({ registry, userTokens }),
    sender: new FcmReminderPushSender(getMessaging(), reminderNotificationContract),
    ids: randomIds,
    policy,
  });

  return {
    recordWorkoutActivity: new RecordWorkoutActivity({ ...runtime, store, preferences, policy }),
    syncReminderPreferences: new SyncReminderPreferences({ ...runtime, store, preferences, policy }),
    runReminderPass: new RunReminderPass({
      finder: new FirestoreDueReminderFinder(db),
      deliver: deliverDueReminder,
      // Off unless an operator enables it (serverConfig/inactivityReminders).
      gate: new FirestoreDeliveryGateReader(db),
      clock: systemClock,
      logger: cloudLogger,
      limits: defaultReminderPassLimits,
    }),
    reconcileTokenOwnership: new ReconcileTokenOwnership({ ...runtime, registry, userTokens }),
  };
}

// Justified module state: a lazily built, immutable object graph, created
// once per function instance on first use (not at import, so loading this
// module never touches Firebase).
let services: AppServices | undefined;

export function appServices(): AppServices {
  services ??= buildAppServices();
  return services;
}
