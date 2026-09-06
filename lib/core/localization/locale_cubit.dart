import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// App-wide language switch (Arabic default, English optional).
///
/// Independent of every feature Cubit — it only ever touches the
/// existing `authBox` (already opened before `runApp`) to remember the
/// user's language choice under the `appLocale` key. Never touches
/// workout/auth/measurement business logic or their Hive boxes.
class LocaleCubit extends Cubit<Locale> {
  static const String _boxName = 'authBox';
  static const String _prefsKey = 'appLocale';

  LocaleCubit() : super(_readInitialLocale());

  static Locale _readInitialLocale() {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return const Locale('ar');
      }
      final box = Hive.box(_boxName);
      final code = box.get(_prefsKey, defaultValue: 'ar') as String;
      return Locale(code);
    } catch (_) {
      return const Locale('ar');
    }
  }

  Future<void> toggle() => setLocale(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));

  Future<void> setLocale(Locale locale) async {
    emit(locale);
    try {
      final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
      await box.put(_prefsKey, locale.languageCode);
    } catch (_) {
      // Non-fatal: the UI already switched language for this session even
      // if persisting the preference failed.
    }
  }
}
