import { createHash, randomUUID } from 'node:crypto';
import { logger } from 'firebase-functions';
import type { Clock, IdGenerator, LogFields, StructuredLogger } from '../application/runtimePorts';

export const systemClock: Clock = { nowMs: () => Date.now() };

export const randomIds: IdGenerator = { newId: () => randomUUID() };

/** Cloud Logging adapter (JSON payloads, severity per level). */
export const cloudLogger: StructuredLogger = {
  info: (event: string, fields?: LogFields) => logger.info(event, { event, ...fields }),
  warn: (event: string, fields?: LogFields) => logger.warn(event, { event, ...fields }),
  error: (event: string, fields?: LogFields) => logger.error(event, { event, ...fields }),
};

/**
 * Short, stable pseudonym for logs: lets operators correlate one user's or
 * one token's events without logging the uid or the token itself.
 */
export function pseudonymForLogs(value: string): string {
  return createHash('sha256').update(`ae-log:${value}`).digest('hex').slice(0, 12);
}
