import 'dart:async';

import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/account_deletion/application/local_account_data_wiper.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:hive/hive.dart';

/// In-memory Firebase side of account deletion.
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  String password = 'right-password';
  AccountDeletionFailure? reauthFailure;
  AccountDeletionFailure? deleteFailure;
  bool? stillExists = true;
  final List<String> deleted = [];
  Completer<void>? deleteGate;

  @override
  Future<void> reauthenticate(String password) async {
    final failure = reauthFailure;
    if (failure != null) throw AccountDeletionException(failure);
    if (password != this.password) throw const AccountDeletionException(AccountDeletionFailure.wrongPassword);
  }

  @override
  Future<void> deleteAccount(String uid) async {
    final gate = deleteGate;
    if (gate != null) await gate.future;
    final failure = deleteFailure;
    if (failure != null) throw AccountDeletionException(failure);
    deleted.add(uid);
    stillExists = false;
  }

  @override
  Future<bool?> accountStillExists() async => stillExists;
}

/// Records which accounts were wiped; can fail like a real cleanup.
class RecordingWiper extends LocalAccountDataWiper {
  RecordingWiper(Box authBox)
    : super(
        storage: UserStorageManager(),
        profilePhotos: LocalProfilePhotoStore(authBox),
        authBox: authBox,
        session: SessionStorage(authBox),
        documentsDirectory: () => throw UnimplementedError(),
        accountHooks: const [],
      );

  final List<String> wiped = [];
  bool fail = false;

  @override
  Future<void> wipe(String uid) async {
    if (fail) throw StateError('cleanup failed');
    wiped.add(uid);
  }
}
