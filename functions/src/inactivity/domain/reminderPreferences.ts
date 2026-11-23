import type { ReminderLanguage, ReminderPolicy } from './reminderPolicy';
import { effectiveTimeZone } from './reminderSchedule';

/** Untrusted preference values as stored (any field may be absent or wrong). */
export interface RawReminderPreferences {
  readonly inactivityRemindersEnabled?: unknown;
  readonly language?: unknown;
  readonly timeZone?: unknown;
}

export interface ReminderPreferences {
  readonly enabled: boolean;
  readonly language: ReminderLanguage;
  readonly timeZone: string;
}

export function isReminderLanguage(value: unknown): value is ReminderLanguage {
  return value === 'ar' || value === 'en';
}

/**
 * Resolves stored preferences. A missing document or field falls back to the
 * policy defaults, which mirror the app (reminders ON, Arabic). Invalid
 * values also fall back, except `enabled`: anything other than an explicit
 * boolean keeps the default, and only an explicit `false` disables.
 */
export function resolveReminderPreferences(
  raw: RawReminderPreferences | null,
  policy: ReminderPolicy,
): ReminderPreferences {
  const enabled = raw?.inactivityRemindersEnabled;
  return {
    enabled: typeof enabled === 'boolean' ? enabled : policy.defaults.enabled,
    language: isReminderLanguage(raw?.language) ? raw.language : policy.defaults.language,
    timeZone: effectiveTimeZone(raw?.timeZone, policy),
  };
}
