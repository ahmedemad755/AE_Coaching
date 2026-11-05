import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RestTimerCubit cubit;

  setUp(() => cubit = RestTimerCubit());
  tearDown(() async => cubit.close());

  test('starts with a one-minute configurable rest', () {
    expect(cubit.state.configuredDuration, const Duration(minutes: 1));
    expect(cubit.state.remaining, const Duration(minutes: 1));
    expect(cubit.state.progress, 1);
    expect(cubit.state.isRunning, isFalse);
  });

  test('accepts a user-configured duration and resets the remaining time', () {
    cubit.configure(const Duration(minutes: 2, seconds: 15));

    expect(
      cubit.state.configuredDuration,
      const Duration(minutes: 2, seconds: 15),
    );
    expect(cubit.state.remaining, const Duration(minutes: 2, seconds: 15));
  });

  test('startCountdown starts or restarts from the configured duration', () {
    cubit.configure(const Duration(seconds: 30));
    cubit.startCountdown();
    expect(cubit.state.isRunning, isTrue);
    expect(cubit.state.remaining, const Duration(seconds: 30));

    cubit.startCountdown();
    expect(cubit.state.isRunning, isTrue);
    expect(cubit.state.remaining, const Duration(seconds: 30));
  });

  test('configuration is not changed during a running rest', () {
    cubit.startCountdown();
    cubit.configure(const Duration(minutes: 3));

    expect(cubit.state.configuredDuration, const Duration(minutes: 1));
  });

  test('stop pauses and reset restores the configured duration', () {
    cubit.configure(const Duration(seconds: 35));
    cubit.startCountdown();
    cubit.stop();
    expect(cubit.state.isRunning, isFalse);

    cubit.configure(const Duration(minutes: 2));
    cubit.reset();
    expect(cubit.state.remaining, const Duration(minutes: 2));
    expect(cubit.state.progress, 1);
  });

  test('zero duration cannot be started', () {
    cubit.configure(Duration.zero);
    cubit.startCountdown();

    expect(cubit.state.isRunning, isFalse);
    expect(cubit.state.progress, 0);
  });

  test('close cancels an active timer', () async {
    cubit.startCountdown();
    await cubit.close();
  });
}
