import { reminderMessagesFor, selectReminderMessage } from '../../../src/inactivity/domain/reminderMessages';

describe('reminder messages', () => {
  for (const language of ['en', 'ar'] as const) {
    test(`${language}: successive reminders differ and selection is deterministic`, () => {
      const messages = reminderMessagesFor(language);
      expect(messages.length).toBeGreaterThanOrEqual(5);
      const firstFive = [1, 2, 3, 4, 5].map((n) => selectReminderMessage(language, n).title);
      expect(new Set(firstFive).size).toBe(5);
      expect(selectReminderMessage(language, 3)).toEqual(selectReminderMessage(language, 3));
      expect(selectReminderMessage(language, messages.length + 1)).toEqual(selectReminderMessage(language, 1));
    });

    test(`${language}: notification-friendly lengths and no time or personal claims`, () => {
      for (const { title, body } of reminderMessagesFor(language)) {
        expect(title.length).toBeLessThanOrEqual(45);
        expect(body.length).toBeLessThanOrEqual(110);
        // No durations ("48 hours", "2 days", "3 أيام", "يومين") and no
        // numbers (counts, weights). "today"/"اليوم" is an invitation, fine.
        expect(`${title} ${body}`).not.toMatch(/\d|\bhours?\b|\bdays?\b|\bweeks?\b|يومين|أيام|ساعات?|أسبوع/i);
      }
    });
  }

  test('Arabic copy is Arabic and English copy is English', () => {
    expect(selectReminderMessage('ar', 1).title).toMatch(/[؀-ۿ]/);
    expect(selectReminderMessage('en', 1).title).not.toMatch(/[؀-ۿ]/);
  });
});
