import type { ActivitySource } from '../domain/activityTime';

/**
 * Where the client-reported occurrence time lives in the app's documents
 * (WorkoutSession.toJson / ExerciseSet.toJson):
 * - `users/{uid}/workout_sessions/{id}`: `startedAt` (falls back to `date`);
 * - `users/{uid}/exercise_sets/{id}`: `date`.
 * Both are Dart local-time ISO strings without an offset. Returned unparsed:
 * the domain policy interprets and bounds them.
 */
export function occurredAtOf(source: ActivitySource, data: Readonly<Record<string, unknown>>): unknown {
  if (source === 'session') return data.startedAt ?? data.date ?? null;
  return data.date ?? null;
}
