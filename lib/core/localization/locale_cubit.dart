import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ae_coaching/core/notifications/inactivity_reminder_service.dart';

/// App-wide language switch (Arabic default, English optional).
///
/// Independent of every feature Cubit — it only ever touches the
/// existing `authBox` (already opened before `runApp`) to remember the
/// user's language choice under the `appLocale` key. Never touches
/// workout/auth/measurement business logic or their Hive boxes.
///
/// Ownership note (Stage 8 audit): [SessionStorage] also owns keys in
/// this same `authBox` (`isLoggedIn`, `currentUserUid`,
/// `currentUserName`, `currentUserPhone`). This is a deliberate,
/// pre-existing overlap, not a bug — `appLocale` and SessionStorage's 4
/// keys are disjoint, and a Hive box is just a key-value map, so two
/// independent owners writing to different keys in it is safe. Neither
/// class reads or writes the other's key(s). Left unchanged rather
/// than split into a second box or migrated to a namespaced key,
/// since no correctness issue exists and doing so would risk losing a
/// user's stored locale/session preference for no behavioral gain.
class LocaleCubit extends Cubit<Locale> {
  static const String _boxName = 'authBox';
  static const String _prefsKey = 'appLocale';

  LocaleCubit({InactivityReminderService? inactivityReminderService})
    : _inactivityReminderService =
          inactivityReminderService ?? InactivityReminderService(),
      super(_readInitialLocale());

  final InactivityReminderService _inactivityReminderService;

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

  Future<void> toggle() => setLocale(
    state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'),
  );

  Future<void> setLocale(Locale locale) async {
    emit(locale);
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      await box.put(_prefsKey, locale.languageCode);
    } catch (_) {
      // Non-fatal: the UI already switched language for this session even
      // if persisting the preference failed.
    }
    await _inactivityReminderService.syncLanguage(locale.languageCode);
  }
}
