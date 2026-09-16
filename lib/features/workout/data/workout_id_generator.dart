import 'dart:math';

/// Generates unique, offline-safe IDs for workout entities (programs,
/// templates, sessions) — used directly as both the Hive box key and
/// the Firestore document ID for that record.
///
/// ## Why not `DateTime.now().microsecondsSinceEpoch` alone
///
/// That was the original scheme, and it silently collided: this
/// project's target Windows environment was confirmed directly to
/// have clock resolution far coarser than a microsecond — five
/// successive calls in a tight loop returned the *exact same* value.
/// Two records created back-to-back then generated the same id, and
/// the second `box.put(id, ...)` silently overwrote the first —
/// permanent data loss. (Found via the Phase 6 reorder test: a
/// WorkoutTemplate vanished after rapid-fire creation.)
///
/// ## Why `Random.secure()` instead of adding a dependency (e.g. `uuid`)
///
/// `Random.secure()` ships in `dart:math` — part of the Dart/Flutter
/// SDK itself, available on every platform this app targets (Android,
/// iOS, Windows) with zero added packages. It's cryptographically
/// seeded, so unlike a plain monotonic counter it stays unpredictable
/// across app restarts (no risk of two devices/sessions producing
/// overlapping sequences). It is only unavailable on a handful of
/// unusual/sandboxed platforms with no OS entropy source — for that
/// edge case this falls back to a plain `Random()`, still combined
/// with the timestamp and enough random characters that collision
/// remains negligible.
class WorkoutIdGenerator {
  WorkoutIdGenerator._();

  static Random? _random;

  static Random get _rng {
    final cached = _random;
    if (cached != null) return cached;
    try {
      return _random = Random.secure();
    } catch (_) {
      // Platform has no secure entropy source — extremely rare.
      return _random = Random();
    }
  }

  /// Returns an id like `program_1789263670483378_k3f8a1z9m2p0` —
  /// unique even when called many times within the same clock tick.
  /// Safe as a Hive key and a Firestore document ID (lowercase
  /// letters, digits, and underscores only).
  static String generate(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _rng.nextInt(0x7FFFFFFF).toRadixString(36) + _rng.nextInt(0x7FFFFFFF).toRadixString(36);
    return '${prefix}_${timestamp}_$randomPart';
  }
}
