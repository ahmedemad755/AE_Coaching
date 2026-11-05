import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_taxonomy_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ExerciseCatalogRepository catalog;
  late List<Map<String, dynamic>> official;
  setUp(() {
    catalog = ExerciseCatalogRepository(
      loadAsset: (path) => File(path).readAsString(),
    );
    official =
        ((jsonDecode(
                      File(
                        ExerciseCatalogRepository.assetPath,
                      ).readAsStringSync(),
                    )
                    as Map)['exercises']
                as List)
            .cast<Map<String, dynamic>>();
  });
  test(
    'all official records retain IDs, English instructions and supplied anatomy',
    () async {
      final items = await catalog.loadCatalog();
      expect(items, hasLength(701));
      expect(items.map((e) => e.id).toSet(), hasLength(701));
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final source = official[i];
        expect(item.id, 'repdb:${source['id']}');
        expect(item.sourceId, source['id']);
        expect(item.nameEn, source['name_en']);
        expect(item.instructionsEn, source['instructions_en']);
        expect(item.primaryMuscles, source['primary_muscles'] ?? []);
        expect(item.secondaryMuscles, source['secondary_muscles'] ?? []);
        expect(item.equipment, source['equipment'] ?? '');
        expect(item.datasetVersion, ExerciseCatalogRepository.datasetCommit);
        expect(item.nameAr, matches(RegExp(r'[\u0600-\u06ff]')));
        expect(item.movementPattern, isNull); // Not supplied upstream.
      }
      final relaxation = items.singleWhere((e) => e.sourceId == 'savasana');
      expect(relaxation.primaryMuscles, isEmpty);
    },
  );
  test(
    'all free image bytes match the pinned source, with correct pose coverage',
    () async {
      final info =
          jsonDecode(File('lib/assets/repdb/SOURCE.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(info['commit'], ExerciseCatalogRepository.datasetCommit);
      final images = info['images'] as Map<String, dynamic>;
      expect(images, hasLength(1217));
      for (final entry in images.entries) {
        expect(entry.key, startsWith('images/flat/'));
        expect(entry.key, isNot(contains('premium')));
        expect(
          sha256
              .convert(File('lib/assets/repdb/${entry.key}').readAsBytesSync())
              .toString(),
          entry.value,
        );
      }
      var two = 0, one = 0;
      for (final exercise in await catalog.loadCatalog()) {
        final media = ExerciseMediaResolver.resolve(
          ExerciseLibraryItem.fromBuiltIn(exercise),
        );
        expect(media.thumbnailPath, isNotNull);
        expect(File(media.thumbnailPath!).existsSync(), isTrue);
        if (media.start != null && media.peak != null) {
          two++;
        } else {
          one++;
        }
      }
      expect(two, 516);
      expect(one, 185);
    },
  );
  test(
    'all source taxonomy values have Arabic labels without inferred metadata',
    () async {
      for (final item in await catalog.loadCatalog()) {
        for (final value in [
          item.muscleGroup,
          ...item.primaryMuscles,
          ...item.secondaryMuscles,
        ]) {
          expect(
            ExerciseTaxonomyLabels.muscle(value, 'ar'),
            matches(RegExp(r'[\u0600-\u06ff]')),
            reason: value,
          );
        }
        if (item.equipment.isNotEmpty) {
          expect(
            ExerciseTaxonomyLabels.equipment(item.equipment, 'ar'),
            matches(RegExp(r'[\u0600-\u06ff]')),
            reason: item.equipment,
          );
        }
        expect(
          ExerciseTaxonomyLabels.category(item.category!, 'ar'),
          matches(RegExp(r'[\u0600-\u06ff]')),
        );
      }
    },
  );
  test(
    'Arabic review coverage is explicit and unreviewed drafts cannot be displayed',
    () async {
      final overlay =
          jsonDecode(
                File(
                  ExerciseCatalogRepository.arabicAssetPath,
                ).readAsStringSync(),
              )
              as Map;
      final translated = overlay['exercises'] as Map;
      expect(translated, hasLength(701));
      expect(
        translated.values.every(
          (e) => e['name_review_status'] == 'context_reviewed',
        ),
        isTrue,
      );
      final items = await catalog.loadCatalog();
      final reviewed = items.where((e) => !e.arabicNeedsReview).toList();
      expect(reviewed.length, greaterThanOrEqualTo(35));
      for (final item in reviewed) {
        expect(item.instructionsAr, hasLength(item.instructionsEn.length));
      }
      final draft = ExerciseCatalogItem.fromRepDb(
        official.first,
        datasetVersion: 'test',
        arabic: {
          'name_ar': 'اسم',
          'instructions_ar': ['نص غير مراجع'],
          'tips_ar': ['نص غير مراجع'],
          'review_status': 'machine_draft_NOT_REVIEWED',
        },
      );
      expect(draft.instructionsAr, isEmpty);
      expect(draft.tipsAr, isEmpty);
      expect(draft.arabicNeedsReview, isTrue);
    },
  );
  test(
    'stale Arabic overlays fail clearly instead of cross-wiring canonical IDs',
    () async {
      final invalid = ExerciseCatalogRepository(
        loadAsset: (path) async {
          final text = File(path).readAsStringSync();
          if (path != ExerciseCatalogRepository.arabicAssetPath) return text;
          final overlay = jsonDecode(text) as Map<String, dynamic>;
          overlay['dataset_commit'] = 'different-version';
          return jsonEncode(overlay);
        },
      );
      await expectLater(invalid.loadCatalog(), throwsFormatException);
    },
  );
  test('missing media stays missing and restricted paths are rejected', () {
    const custom = ExerciseLibraryItem(
      id: 'custom_a',
      nameEn: 'Mine',
      source: ExerciseLibraryItemSource.custom,
    );
    expect(ExerciseMediaResolver.resolve(custom).thumbnail, isNull);
    final source = Map<String, dynamic>.from(official.first);
    source['images'] = {
      'flat': {'main': 'premium-samples/image.webp'},
    };
    expect(
      () => ExerciseCatalogItem.fromRepDb(source, datasetVersion: 'test'),
      throwsFormatException,
    );
    source['images'] = {};
    final item = ExerciseCatalogItem.fromRepDb(source, datasetVersion: 'test');
    expect(
      ExerciseMediaResolver.resolve(
        ExerciseLibraryItem.fromBuiltIn(item),
      ).thumbnail,
      isNull,
    );
  });
  test('English partial and normalized Arabic search are offline', () async {
    final english = await catalog.search(query: 'BENCH press');
    expect(english.any((e) => e.id == 'repdb:bench-press'), isTrue);
    final arabic = await catalog.search(query: '  أَمَامِي  ');
    expect(arabic.any((e) => e.id == 'repdb:dumbbell-front-raise'), isTrue);
    final muscle = await catalog.search(muscleGroups: {'pectoralis_major'});
    expect(muscle, isNotEmpty);
    expect(
      muscle.every((e) => e.primaryMuscles.contains('pectoralis_major')),
      isTrue,
    );
    final equipment = await catalog.search(equipment: {'dumbbell'});
    expect(equipment, hasLength(88));
    expect(equipment.every((e) => e.equipment == 'dumbbell'), isTrue);
  });
  test(
    'exact aliases resolve; different grip and angle variants remain legacy',
    () async {
      expect(
        (await catalog.resolveReference('ex_barbell_bench_press'))!.id,
        'repdb:bench-press',
      );
      for (final id in [
        'ex_rope_triceps_pushdown',
        'ex_leg_press_45',
        'ex_neutral_grip_lat_pulldown',
      ]) {
        final item = await catalog.resolveReference(id);
        expect(item!.id, id);
        expect(item.isRepDb, isFalse);
      }
      expect(await catalog.resolveReference('unknown-id'), isNull);
      expect((await catalog.loadLegacyMapping()), hasLength(35));
      expect(
        (await catalog.loadCatalog()).any((e) => e.id.startsWith('ex_')),
        isFalse,
      );
    },
  );
}
