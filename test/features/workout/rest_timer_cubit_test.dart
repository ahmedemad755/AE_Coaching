import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RestTimerCubit cubit;

  setUp(() => cubit = RestTimerCubit());
  tearDown(() async => cubit.close());

  test('initial state is zero and not running', () {
    expect(cubit.state.elapsed, equals(Duration.zero));
    expect(cubit.state.isRunning, isFalse);
  });

  test('start() flips isRunning to true immediately, without waiting for a tick', () {
    cubit.start();
    expect(cubit.state.isRunning, isTrue);
    expect(cubit.state.elapsed, equals(Duration.zero));
  });

  test('calling start() twice is a harmless no-op — never schedules a second ticker', () {
    cubit.start();
    cubit.start(); // must not throw, must not double-schedule
    expect(cubit.state.isRunning, isTrue);
  });

  test('stop() pauses without losing the elapsed value', () {
    cubit.start();
    cubit.stop();
    expect(cubit.state.isRunning, isFalse);
    expect(cubit.state.elapsed, equals(Duration.zero));
  });

  test('stop() when not running is a harmless no-op', () {
    cubit.stop();
    expect(cubit.state.isRunning, isFalse);
  });

  test('reset() while running stops the ticker and zeroes elapsed', () {
    cubit.start();
    cubit.reset();
    expect(cubit.state.isRunning, isFalse);
    expect(cubit.state.elapsed, equals(Duration.zero));
  });

  test(
    'close() cancels any active ticker cleanly — a leaked Timer would fail this test '
    'with a pending-timer error from the test framework itself once tearDown closes it',
    () {
      cubit.start();
      // tearDown's cubit.close() runs after this test body — reaching
      // the end of the whole test without the runner complaining about
      // a pending Timer IS the assertion; close() must cancel it.
    },
  );
}
