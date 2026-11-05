import 'dart:async';

import 'package:ae_coaching/features/profile/data/user_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  String? savedName;
  bool failDisplayName = false;
  @override
  Future<void> updateDisplayName(String? value) async {
    if (failDisplayName) throw StateError('Auth unavailable');
    savedName = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User? currentUser = _User('user-a');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Stateful test double; never used as a production Firestore reference.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Document implements DocumentReference<Map<String, dynamic>> {
  Map<Object, Object?>? fields;
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (fail) throw StateError('Profile update unavailable');
    fields = data;
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Stateful test double; no Firebase service or document is accessed.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Collection implements CollectionReference<Map<String, dynamic>> {
  final document = _Document();
  String? requestedUid;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    requestedUid = path;
    return document;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  final profiles = _Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return profiles;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth auth;
  late _Firestore firestore;
  late UserProfileRepository repository;
  setUp(() {
    auth = _Auth();
    firestore = _Firestore();
    repository = UserProfileRepository(auth: auth, firestore: firestore);
  });

  test(
    'saves only the trimmed existing name field for the signed-in user',
    () async {
      await repository.updateName(uid: 'user-a', name: '  Ahmed Emad  ');
      expect(firestore.profiles.requestedUid, 'user-a');
      expect(firestore.profiles.document.fields, {'name': 'Ahmed Emad'});
      expect((auth.currentUser as _User).savedName, 'Ahmed Emad');
    },
  );

  test(
    'invalid names and other accounts never reach profile storage',
    () async {
      for (final name in ['', '   ', List.filled(81, 'a').join()]) {
        await expectLater(
          repository.updateName(uid: 'user-a', name: name),
          throwsArgumentError,
        );
      }
      await expectLater(
        repository.updateName(uid: 'user-b', name: 'Other'),
        throwsStateError,
      );
      expect(firestore.profiles.document.fields, isNull);
    },
  );

  test(
    'Firestore failure is surfaced without updating the Auth fallback',
    () async {
      firestore.profiles.document.fail = true;
      await expectLater(
        repository.updateName(uid: 'user-a', name: 'Ahmed'),
        throwsStateError,
      );
      expect((auth.currentUser as _User).savedName, isNull);
    },
  );

  test('Auth fallback failure preserves a successful profile save', () async {
    (auth.currentUser as _User).failDisplayName = true;
    await repository.updateName(uid: 'user-a', name: 'Ahmed');
    expect(firestore.profiles.document.fields, {'name': 'Ahmed'});
  });

  test(
    'switching accounts during a save never changes the next user name',
    () async {
      final pending = Completer<void>();
      firestore.profiles.document.pending = pending;
      final saving = repository.updateName(uid: 'user-a', name: 'Ahmed');
      final nextUser = _User('user-b');
      auth.currentUser = nextUser;
      pending.complete();
      await saving;
      expect(firestore.profiles.requestedUid, 'user-a');
      expect(nextUser.savedName, isNull);
    },
  );
}
