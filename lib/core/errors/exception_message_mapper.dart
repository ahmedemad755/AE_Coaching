/// Core fallback exception-to-user-message mapper.
///
/// Trust boundary: this function trusts exactly one shape — a plain
/// [Exception] (Dart's own `Exception('...')` factory) whose
/// `toString()` starts with the literal `'Exception: '` prefix that
/// factory always adds. That prefix is stripped (first occurrence
/// only) and the remaining text is returned as-is, because every
/// caller in this codebase that reaches this function already wraps
/// its own pre-crafted, user-safe message in `Exception(...)` before
/// throwing.
///
/// Nothing else is trusted. A custom class that merely
/// `implements Exception` (and so satisfies `error is Exception`) but
/// overrides `toString()` to skip the `'Exception: '` prefix is NOT
/// unwrapped here — such classes carry their own crafted message and
/// must be caught and handled locally by their own call site, ahead
/// of the generic catch that reaches this mapper (see
/// `WorkoutSessionCubit` for the precedent). Any other error type
/// (`ArgumentError`, `StateError`, a raw `FirebaseException`, or
/// anything unrecognized) maps to a single stable generic fallback,
/// never its own `toString()`.
String mapGenericExceptionToMessage(Object error) {
  if (error is Exception) {
    final text = error.toString();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length);
    }
  }
  return 'Something went wrong. Please try again.';
}
