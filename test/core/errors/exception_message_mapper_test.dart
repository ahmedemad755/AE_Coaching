import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomSafeException implements Exception {
  final String reason;
  const _CustomSafeException(this.reason);

  @override
  String toString() => reason;
}

void main() {
  const fallback = 'Something went wrong. Please try again.';

  group('mapGenericExceptionToMessage', () {
    test('a plain Exception(...) unwraps to its exact message', () {
      expect(
        mapGenericExceptionToMessage(Exception('known message')),
        equals('known message'),
      );
    });

    test('replaceFirst semantics: only the first "Exception: " occurrence is '
        'stripped, so a message that itself contains the literal text is '
        'preserved rather than fully unwrapped', () {
      expect(
        mapGenericExceptionToMessage(Exception('Exception: nested')),
        equals('Exception: nested'),
      );
    });

    test('ArgumentError never reaches the user as raw toString()', () {
      expect(
        mapGenericExceptionToMessage(ArgumentError('bad argument')),
        equals(fallback),
      );
    });

    test('StateError never reaches the user as raw toString()', () {
      expect(
        mapGenericExceptionToMessage(StateError('bad state')),
        equals(fallback),
      );
    });

    test('a custom Error subtype never reaches the user as raw toString()', () {
      expect(
        mapGenericExceptionToMessage(RangeError('out of range')),
        equals(fallback),
      );
    });

    test('a custom class that implements Exception but does not use the '
        "'Exception: ' wrapper is NOT trusted — arbitrary Exception "
        'implementations are not automatically user-safe', () {
      expect(
        mapGenericExceptionToMessage(
          const _CustomSafeException('crafted domain reason'),
        ),
        equals(fallback),
      );
    });

    test('is deterministic for the same input', () {
      final error = Exception('same message');
      final first = mapGenericExceptionToMessage(error);
      final second = mapGenericExceptionToMessage(error);
      expect(first, equals(second));
    });

    test('never throws for any input type', () {
      expect(() => mapGenericExceptionToMessage(Exception()), returnsNormally);
      expect(
        () => mapGenericExceptionToMessage('a bare string'),
        returnsNormally,
      );
      expect(() => mapGenericExceptionToMessage(42), returnsNormally);
    });
  });
}
