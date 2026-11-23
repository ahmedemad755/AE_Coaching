import 'package:ae_coaching/core/utils/close_safe_emit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends Cubit<int> with CloseSafeEmit<int> {
  _Counter() : super(0);

  void set(int value) => emit(value);
}

class _Plain extends Cubit<int> {
  _Plain() : super(0);

  void set(int value) => emit(value);
}

void main() {
  test('a state after close is dropped instead of throwing; before close it '
      'is emitted as usual', () async {
    final counter = _Counter();
    final seen = <int>[];
    final sub = counter.stream.listen(seen.add);
    counter.set(1);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [1]);
    await counter.close();
    expect(() => counter.set(2), returnsNormally);
    expect(counter.state, 1);
    await sub.cancel();
  });

  test(
    'without it, the same late state throws (the error seen in the app)',
    () async {
      final plain = _Plain();
      await plain.close();
      expect(
        () => plain.set(2),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot emit new states after calling close'),
          ),
        ),
      );
    },
  );
}
