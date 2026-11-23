import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';

/// Versioned, local-only write-ahead migration. Never writes sessions, sets,
/// program records, cloud documents or unmatched exercise references.
class LegacyExerciseMigration {
  LegacyExerciseMigration({
    required this.templates,
    required this.sessions,
    required this.catalog,
    required this.currentUserId,
    Future<Directory> Function()? journalDirectory,
  }) : journalDirectory = journalDirectory ?? _defaultDirectory;

  final WorkoutTemplateRepository templates;
  final WorkoutSessionRepository sessions;
  final ExerciseCatalogRepository catalog;
  final String? Function() currentUserId;
  final Future<Directory> Function() journalDirectory;

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/catalog-migrations');
  }

  void _owner(String uid) {
    if (uid.isEmpty || currentUserId() != uid) {
      throw StateError('Account changed during catalog migration.');
    }
  }

  static Map<String, dynamic> _snapshot(WorkoutTemplate day) => {
    ...day.toJson(),
    'exerciseAssignments': day.exerciseAssignments
        .map((a) => a.toJson())
        .toList(),
  };
  static String _fingerprint(Map<String, dynamic> value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  Future<File> _file(String uid) async {
    final root = await journalDirectory();
    _owner(uid);
    final directory = Directory('${root.path}/${Uri.encodeComponent(uid)}');
    await directory.create(recursive: true);
    _owner(uid);
    return File('${directory.path}/repdb-v1.json');
  }

  Future<Map<String, dynamic>> _read(File file, String uid) async {
    if (!await file.exists()) {
      return {
        'version': 1,
        'datasetCommit': ExerciseCatalogRepository.datasetCommit,
        'owner': uid,
        'entries': <String, dynamic>{},
      };
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['owner'] != uid ||
        data['datasetCommit'] != ExerciseCatalogRepository.datasetCommit) {
      throw const FormatException(
        'Catalog migration journal does not match this account/version.',
      );
    }
    return data;
  }

  Future<void> _write(File file, Map<String, dynamic> data, String uid) async {
    _owner(uid);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    _owner(uid);
    await temporary.rename(file.path);
    _owner(uid);
  }

  Future<int> migrate() async {
    final uid = currentUserId() ?? '';
    _owner(uid);
    return templates.coordinateExerciseEdit(() async {
      _owner(uid);
      final box = await templates.getUserBox();
      _owner(uid);
      final sessionBox = await sessions.getUserBox();
      _owner(uid);
      if (box.name != 'workout_templates_$uid'.toLowerCase() ||
          sessionBox.name != 'workout_sessions_$uid'.toLowerCase()) {
        throw StateError('Refusing cross-account catalog migration.');
      }
      final aliases = await catalog.loadLegacyMapping();
      final canonical = (await catalog.loadCatalog()).map((e) => e.id).toSet();
      if (aliases.values.any((id) => !canonical.contains(id))) {
        throw const FormatException('Mapping target missing from RepDB.');
      }
      _owner(uid);
      final file = await _file(uid);
      final journal = await _read(file, uid);
      if (journal['disabled'] == true) return 0;
      final entries = journal['entries'] as Map<String, dynamic>;
      var changed = 0;
      for (final day in box.values.toList()) {
        _owner(uid);
        if (day.isArchived ||
            sessions.getActiveSession(sessionBox)?.workoutTemplateId ==
                day.id) {
          continue;
        }
        final assignments = [
          for (final a in day.exerciseAssignments)
            a.referenceType == 'builtIn' && aliases.containsKey(a.exerciseId)
                ? a.copyWith(exerciseId: aliases[a.exerciseId])
                : a,
        ];
        if ([
          for (var i = 0; i < assignments.length; i++)
            assignments[i].exerciseId != day.exerciseAssignments[i].exerciseId,
        ].every((v) => !v)) {
          continue;
        }
        // If two legacy aliases would collide, preserve the entire day for
        // explicit review rather than silently dropping/merging a variation.
        if (assignments.map((a) => a.exerciseId).toSet().length !=
            assignments.length) {
          continue;
        }
        final before = _snapshot(day);
        final afterDay = day.copyWith(exerciseAssignments: assignments);
        final after = _snapshot(afterDay);
        final revision = '${day.id}:${_fingerprint(before)}';
        entries[revision] ??= {
          'templateId': day.id,
          'before': before,
          'after': after,
          'phase': 'prepared',
        };
        await _write(
          file,
          journal,
          uid,
        ); // Durable recovery before the Hive write.
        _owner(uid);
        if (sessions.getActiveSession(sessionBox)?.workoutTemplateId ==
            day.id) {
          continue;
        }
        // A synchronous identity check protects any external edit between awaits.
        final current = box.get(day.id);
        if (current == null ||
            _fingerprint(_snapshot(current)) != _fingerprint(before)) {
          continue;
        }
        await box.put(day.id, afterDay);
        _owner(uid);
        (entries[revision] as Map<String, dynamic>)['phase'] = 'applied';
        await _write(file, journal, uid);
        changed++;
      }
      // Recover an interruption after Hive committed but before phase marking.
      for (final entry in entries.values.cast<Map<String, dynamic>>()) {
        final current = box.get(entry['templateId']);
        if (entry['phase'] == 'prepared' &&
            current != null &&
            _fingerprint(_snapshot(current)) ==
                _fingerprint(
                  Map<String, dynamic>.from(entry['after'] as Map),
                )) {
          entry['phase'] = 'applied';
        }
      }
      await _write(file, journal, uid);
      return changed;
    });
  }

  /// Explicit maintenance operation; never called automatically or by logout.
  /// Changed days and active days are skipped. No user edits are overwritten.
  Future<int> rollback() async {
    final uid = currentUserId() ?? '';
    _owner(uid);
    return templates.coordinateExerciseEdit(() async {
      final box = await templates.getUserBox();
      final sessionBox = await sessions.getUserBox();
      _owner(uid);
      final file = await _file(uid);
      final journal = await _read(file, uid);
      journal['disabled'] = true;
      await _write(file, journal, uid);
      final entries = journal['entries'] as Map<String, dynamic>;
      var restored = 0;
      for (final entry
          in entries.values.toList().reversed.cast<Map<String, dynamic>>()) {
        _owner(uid);
        final id = entry['templateId'] as String;
        final current = box.get(id);
        if (current == null ||
            sessions.getActiveSession(sessionBox)?.workoutTemplateId == id) {
          continue;
        }
        if (_fingerprint(_snapshot(current)) !=
            _fingerprint(Map<String, dynamic>.from(entry['after'] as Map))) {
          continue;
        }
        await box.put(
          id,
          WorkoutTemplate.fromJson(
            Map<String, dynamic>.from(entry['before'] as Map),
          ),
        );
        _owner(uid);
        entry['phase'] = 'rolledBack';
        await _write(file, journal, uid);
        restored++;
      }
      return restored;
    });
  }
}
