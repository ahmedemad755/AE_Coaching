import { FakeSmsProvider, otpMessageBody } from '../../src/smsProvider';

describe('FakeSmsProvider', () => {
  test('records the destination and body, performs no external call', async () => {
    const provider = new FakeSmsProvider();
    await provider.send('+201012345678', otpMessageBody('123456'));
    expect(provider.sentMessages).toHaveLength(1);
    expect(provider.sentMessages[0].toE164Phone).toBe('+201012345678');
    expect(provider.sentMessages[0].body).toContain('123456');
  });

  test('failNext causes the next call(s) to reject', async () => {
    const provider = new FakeSmsProvider();
    provider.failNext(2);
    await expect(provider.send('+201012345678', 'x')).rejects.toThrow();
    await expect(provider.send('+201012345678', 'x')).rejects.toThrow();
    // Third call succeeds again.
    await provider.send('+201012345678', 'x');
    expect(provider.sentMessages).toHaveLength(1);
  });
});

describe('otpMessageBody', () => {
  test('embeds the exact OTP digits and mentions expiry', () => {
    const body = otpMessageBody('042817');
    expect(body).toContain('042817');
    expect(body.toLowerCase()).toContain('expires');
  });
});
