import type { ReminderLanguage } from './reminderPolicy';

export interface ReminderMessage {
  readonly title: string;
  readonly body: string;
}

/**
 * Encouraging, non-judgmental copy. It never states how long the user has
 * been inactive (the cadence varies), never includes workout details or
 * names, and only implies past training, which is true: users without any
 * workout history never receive reminders.
 */
const catalog: Readonly<Record<ReminderLanguage, readonly ReminderMessage[]>> = {
  en: [
    {
      title: 'Ready for your next workout?',
      body: 'Your training plan is waiting whenever you are. Even a short session counts.',
    },
    {
      title: 'Small steps add up',
      body: 'A few sets today keep your progress moving. Start whenever it suits you.',
    },
    {
      title: 'Your workout is one tap away',
      body: 'Pick up where you left off. Your programs are ready for you.',
    },
    {
      title: "Let's get moving again",
      body: 'Consistency beats perfection. A quick session is a great restart.',
    },
    {
      title: 'We saved your spot',
      body: 'Your workouts are right where you left them. Come back anytime.',
    },
    {
      title: 'Time for a fresh start?',
      body: 'Every session is a new beginning. Open AE Coaching and start yours.',
    },
  ],
  ar: [
    {
      title: 'جاهز لتمرينك القادم؟',
      body: 'خطة تمرينك بانتظارك متى كنت مستعدًا. حتى الجلسة القصيرة تُحدث فرقًا.',
    },
    {
      title: 'خطوات صغيرة تصنع الفرق',
      body: 'بضع مجموعات اليوم تُبقي تقدمك مستمرًا. ابدأ في الوقت الذي يناسبك.',
    },
    {
      title: 'تمرينك على بُعد لمسة',
      body: 'تابع من حيث توقفت. برامجك جاهزة لك.',
    },
    {
      title: 'لنعد إلى الحركة من جديد',
      body: 'الاستمرارية أهم من الكمال. جلسة سريعة بداية رائعة.',
    },
    {
      title: 'مكانك محفوظ',
      body: 'تمارينك في انتظارك كما تركتها. عُد في أي وقت.',
    },
    {
      title: 'هل حان وقت بداية جديدة؟',
      body: 'كل جلسة بداية جديدة. افتح AE Coaching وابدأ جلستك.',
    },
  ],
};

/** Messages available for [language] (for tests and length checks). */
export function reminderMessagesFor(language: ReminderLanguage): readonly ReminderMessage[] {
  return catalog[language];
}

/**
 * Deterministic choice: successive reminders rotate through the catalog, so
 * the same reminder number always produces the same message.
 */
export function selectReminderMessage(language: ReminderLanguage, reminderNumber: number): ReminderMessage {
  const messages = catalog[language];
  const index = (((Math.trunc(reminderNumber) - 1) % messages.length) + messages.length) % messages.length;
  return messages[index];
}
