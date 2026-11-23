import 'dart:async';

import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final ThemePreferenceStore _store;
  final Stream<String?> _userChanges;
  late final StreamSubscription<String?> _userSubscription;
  String? _uid;

  ThemeCubit({
    required ThemePreferenceStore store,
    required Stream<String?> userChanges,
    required String? initialUid,
  }) : _store = store,
       _userChanges = userChanges,
       _uid = initialUid,
       super(store.read(initialUid ?? '')) {
    _userSubscription = _userChanges.listen(_handleUserChange);
  }

  String? get currentUid => _uid;

  void _handleUserChange(String? uid) {
    if (_uid == uid || isClosed) return;
    _uid = uid;
    emit(_store.read(uid ?? ''));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final uid = _uid;
    final previous = state;
    emit(mode);
    if (uid == null || uid.isEmpty) return;
    try {
      await _store.write(uid, mode);
    } catch (_) {
      if (!isClosed && _uid == uid) emit(previous);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    await super.close();
  }
}
