import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract interface class ThemePreferenceStore {
  ThemeMode read(String uid);
  Future<void> write(String uid, ThemeMode mode);
}

class HiveThemePreferenceStore implements ThemePreferenceStore {
  final Box _box;

  const HiveThemePreferenceStore(this._box);

  static String keyFor(String uid) => 'themeMode.$uid';

  @override
  ThemeMode read(String uid) {
    if (uid.isEmpty) return ThemeMode.system;
    return switch (_box.get(keyFor(uid))) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @override
  Future<void> write(String uid, ThemeMode mode) async {
    if (uid.isEmpty) throw StateError('A user is required to save a theme.');
    await _box.put(keyFor(uid), switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
