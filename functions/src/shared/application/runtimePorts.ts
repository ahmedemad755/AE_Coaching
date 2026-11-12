/** Current time as UTC epoch milliseconds. Injected so tests control time. */
export interface Clock {
  nowMs(): number;
}

/** Unique, unguessable identifiers (lease owners). */
export interface IdGenerator {
  newId(): string;
}

/** Values allowed in structured log fields: never raw tokens or payloads. */
export type LogFields = Readonly<Record<string, string | number | boolean | null>>;

/**
 * Structured, privacy-safe logging. Callers pass pseudonymous identifiers
 * only (never a raw uid, token or message payload); implementations must
 * not add raw user data.
 */
export interface StructuredLogger {
  info(event: string, fields?: LogFields): void;
  warn(event: string, fields?: LogFields): void;
  error(event: string, fields?: LogFields): void;
}
