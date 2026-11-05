import 'dart:io';

import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDirectory;
  late Box box;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('theme-preferences-');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox('authBox');
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('uses System by default and persists through Hive reopen', () async {
    final store = HiveThemePreferenceStore(box);
    expect(store.read('user-a'), ThemeMode.system);

    await store.write('user-a', ThemeMode.dark);
    await box.close();
    final reopened = await Hive.openBox('authBox');

    expect(HiveThemePreferenceStore(reopened).read('user-a'), ThemeMode.dark);
  });

  test('theme choices remain isolated by uid', () async {
    final store = HiveThemePreferenceStore(box);
    await store.write('user-a', ThemeMode.dark);
    await store.write('user-b', ThemeMode.light);

    expect(store.read('user-a'), ThemeMode.dark);
    expect(store.read('user-b'), ThemeMode.light);
    expect(store.read('user-c'), ThemeMode.system);
  });

  test('rejects writes without a user id', () async {
    await expectLater(
      HiveThemePreferenceStore(box).write('', ThemeMode.dark),
      throwsStateError,
    );
  });
}
