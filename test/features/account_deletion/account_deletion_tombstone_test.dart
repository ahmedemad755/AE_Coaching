import 'package:ae_coaching/features/account_deletion/data/firebase_account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules let a synced (schema 2) document be deleted only once it is a
/// tombstone. firestore-tests/rules.test.mjs checks the same payload against
/// the rules on the emulator.
void main() {
  final now = DateTime.utc(2026, 11, 17, 10);
  Map<String, dynamic>? tombstone(Map<String, dynamic> data) =>
      FirebaseAccountDeletionRepository.tombstoneBeforeDelete(
        data,
        writeId: 'account-deletion-1',
        now: now,
      );

  test('a live schema 2 document gets the next revision as a tombstone', () {
    final hash = 'a' * 64;
    expect(
      tombstone({
        'id': 'day_1',
        'name': 'Push',
        'activities': const [],
        'schemaVersion': 2,
        'revision': 3,
        'writeId': 'phone-7',
        'contentHash': hash,
        'deleted': false,
      }),
      {
        'schemaVersion': 2,
        'baseRevision': 3,
        'revision': 4,
        'writeId': 'account-deletion-1',
        'contentHash': hash,
        'deleted': true,
        'deletedAt': '2026-11-17T10:00:00.000Z',
      },
      // Only revision fields: written with merge, the content is kept and
      // the rules' shape checks still pass.
    );
  });

  test(
    'old (schema 1) documents and existing tombstones are deleted as they are',
    () {
      expect(tombstone({'id': 'old', 'name': 'Legs'}), isNull);
      expect(tombstone({'schemaVersion': 1, 'id': 'old'}), isNull);
      expect(
        tombstone({
          'schemaVersion': 2,
          'revision': 5,
          'contentHash': 'b' * 64,
          'deleted': true,
        }),
        isNull,
      );
    },
  );

  test('the deletion list covers the synced collections', () {
    expect(
      FirebaseAccountDeletionRepository.userCollections,
      containsAll(FirebaseAccountDeletionRepository.revisionedCollections),
    );
    expect(
      FirebaseAccountDeletionRepository.userCollections,
      contains('custom_exercises'),
    );
  });
}
