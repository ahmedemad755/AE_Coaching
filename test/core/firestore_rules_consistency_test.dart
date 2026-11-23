import 'dart:io';

import 'package:ae_coaching/features/account_deletion/data/firebase_account_deletion_repository.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';
import 'package:flutter_test/flutter_test.dart';

/// firestore.rules is deployed by hand, separately from the app. These
/// checks keep the app and the rules from drifting apart.
void main() {
  final rules = File('firestore.rules').readAsStringSync();

  /// The body of `match /users/{userId}/<name>/{...} { ... }`.
  String block(String name) {
    final start = rules.indexOf(RegExp('match /$name/\\{'));
    expect(start, isNonNegative, reason: 'no rules for $name');
    final end = rules.indexOf(RegExp(r'^      \}', multiLine: true), start);
    return rules.substring(start, end);
  }

  test('account deletion empties every collection the rules allow under '
      'users/{uid}', () {
    final ruled = {
      for (final match in RegExp(
        r'^      match /(\w+)/\{',
        multiLine: true,
      ).allMatches(rules))
        match.group(1)!,
    };
    expect(ruled, isNotEmpty);
    // Not listed on purpose:
    //  - settings: a single document (notifications), deleted by id;
    //  - notificationState: server-owned, the client can't touch it.
    expect(
      FirebaseAccountDeletionRepository.userCollections.toSet(),
      ruled.difference({'settings', 'notificationState'}),
      reason:
          'A collection added to firestore.rules must also be deleted by '
          'FirebaseAccountDeletionRepository (or be excluded here on purpose).',
    );
  });

  test('synced (schema 2) collections are deleted tombstone-first, as their '
      'rules require', () {
    for (final name
        in FirebaseAccountDeletionRepository.revisionedCollections) {
      expect(FirebaseAccountDeletionRepository.userCollections, contains(name));
      final rule = block(name);
      expect(rule, contains('allow delete'), reason: name);
      expect(rule, contains('isStoredTombstone()'), reason: name);
    }
  });

  test(
    'the activity limit in the rules is WorkoutLimits.maxActivitiesPerDay',
    () {
      final limits = RegExp(
        r'activities\.size\(\) <= (\d+)',
      ).allMatches(rules).map((m) => int.parse(m.group(1)!));
      expect(limits, isNotEmpty);
      expect(limits.toSet(), {WorkoutLimits.maxActivitiesPerDay});
    },
  );
}
