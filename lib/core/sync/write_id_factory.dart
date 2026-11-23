import 'dart:math';

import 'package:hive/hive.dart';

/// Unique ids for cloud writes: `<installId>-<time>-<random>` (≤ 40 chars,
/// the rules allow 64). The install id is random and identifies nothing
/// about the user; it only lets a device recognise its own writes.
class WriteIdFactory {
  WriteIdFactory(this._store);

  static const installIdKey = 'syncInstallId';

  final Box _store;
  final Random _random = _secureOrDefault();
  late final String _installId = _loadInstallId();

  static Random _secureOrDefault() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random();
    }
  }

  String _chars(int length) {
    const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
    ]);
  }

  String _loadInstallId() {
    final existing = _store.get(installIdKey);
    if (existing is String && existing.isNotEmpty) return existing;
    final created = _chars(12);
    _store.put(installIdKey, created);
    return created;
  }

  String next() =>
      '$_installId-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_chars(6)}';
}
