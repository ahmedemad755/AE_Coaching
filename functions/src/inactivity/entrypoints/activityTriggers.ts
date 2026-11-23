import { type FirestoreEvent, onDocumentCreated, type QueryDocumentSnapshot } from 'firebase-functions/v2/firestore';
import { appServices } from '../../compositionRoot';
import type { ActivitySource } from '../domain/activityTime';
import { occurredAtOf } from '../infrastructure/workoutActivityDocuments';

/**
 * Qualifying workout activity, derived server-side from the documents the
 * app already uploads. Only CREATION counts: editing a set, completing or
 * updating a session (writes to an existing document) and deletes do not.
 *
 * Retries are enabled: the handler is idempotent (a repeated delivery is
 * "not newer" and writes nothing). Bad data never throws, so a retry only
 * happens for transient infrastructure failures.
 */
async function recordActivity(
  event: FirestoreEvent<QueryDocumentSnapshot | undefined, { uid: string }>,
  source: ActivitySource,
): Promise<void> {
  const snapshot = event.data;
  if (snapshot === undefined) return;
  await appServices().recordWorkoutActivity.execute({
    uid: event.params.uid,
    source,
    occurredAtRaw: occurredAtOf(source, snapshot.data()),
    receivedAtMs: snapshot.createTime.toMillis(),
  });
}

export const onWorkoutSessionCreated = onDocumentCreated(
  { document: 'users/{uid}/workout_sessions/{sessionId}', retry: true },
  (event) => recordActivity(event, 'session'),
);

export const onWorkoutSetCreated = onDocumentCreated(
  { document: 'users/{uid}/exercise_sets/{setId}', retry: true },
  (event) => recordActivity(event, 'set'),
);
