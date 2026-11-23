import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A stable, canonical JSON text for content fingerprints.
///
/// The same logical content always gives the same text, whatever the
/// order in which a map's keys were inserted or how a number round-tripped
/// through storage:
/// - map keys are sorted (by UTF-16 code unit) and must be strings;
/// - map entries whose value is `null` are dropped (`{a: null}` == `{}`);
/// - integral doubles are written as integers (`5.0` == `5`), so a value
///   that Firestore or Hive returns as a different numeric type does not
///   change the fingerprint; NaN and infinities are rejected;
/// - lists keep their order (order is meaningful, e.g. activity order);
/// - strings are compared exactly as stored (no Unicode normalization).
///
/// Anything else (DateTime, custom objects…) is rejected: callers convert
/// such values to strings explicitly, so the format can never drift.
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  _write(buffer, value);
  return buffer.toString();
}

/// SHA-256 (lowercase hex, 64 characters) of [canonicalJson].
String contentHash(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();

void _write(StringBuffer out, Object? value) {
  switch (value) {
    case null:
      out.write('null');
    case bool():
      out.write(value ? 'true' : 'false');
    case int():
      out.write(value);
    case double():
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'value', 'Not a finite number');
      }
      if (value == value.truncateToDouble() && value.abs() < 9e15) {
        out.write(value.toInt());
      } else {
        out.write(value.toString());
      }
    case String():
      out.write(jsonEncode(value));
    case List():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _write(out, value[i]);
      }
      out.write(']');
    case Map():
      final keys = <String>[];
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw ArgumentError.value(key, 'key', 'Map keys must be strings');
        }
        if (entry.value != null) keys.add(key);
      }
      keys.sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        _write(out, value[keys[i]]);
      }
      out.write('}');
    default:
      throw ArgumentError.value(
        value,
        'value',
        'Unsupported type ${value.runtimeType} in canonical content',
      );
  }
}
