import 'dart:io';

import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('locale_cubit_reminder_test_');
    Hive.init(directory.path);
    await Hive.openBox('authBox');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('a language change is passed on to the reminder preference sync', () async {
    final changes = <String>[];
    final cubit = LocaleCubit(onLanguageChanged: (code) async => changes.add(code));
    await cubit.setLocale(const Locale('en'));
    await cubit.setLocale(const Locale('ar'));
    await pumpEventQueue();
    expect(changes, ['en', 'ar']);
    await cubit.close();
  });

  test('a failing sync never affects the app language', () async {
    final cubit = LocaleCubit(onLanguageChanged: (_) async => throw StateError('offline'));
    await cubit.setLocale(const Locale('en'));
    await pumpEventQueue();
    expect(cubit.state, const Locale('en'));
    expect(Hive.box('authBox').get('appLocale'), 'en');
    await cubit.close();
  });

  test('works without a listener', () async {
    final cubit = LocaleCubit();
    await cubit.setLocale(const Locale('en'));
    expect(cubit.state, const Locale('en'));
    await cubit.close();
  });
}
