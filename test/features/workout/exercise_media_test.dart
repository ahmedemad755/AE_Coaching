import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_illustrations.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_library_card.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_video_links.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const bench = ExerciseLibraryItem(
  id: 'ex_barbell_bench_press',
  nameEn: 'Barbell Bench Press',
  nameAr: 'بنش بار مستوي',
  muscleGroup: 'chest',
  equipment: 'barbell',
  source: ExerciseLibraryItemSource.builtIn,
);
const unmapped = ExerciseLibraryItem(
  id: 'unmapped',
  nameEn: 'Unmapped exercise',
  source: ExerciseLibraryItemSource.builtIn,
);

class _Browser extends UrlLauncherPlatform {
  String? url;
  PreferredLaunchMode? mode;
  bool result = true;
  bool fail = false;
  @override
  get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    mode = options.mode;
    if (fail) throw StateError('No browser');
    return result;
  }
}

Widget app(Widget child, {String language = 'en'}) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.dark,
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(12), child: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reviewed media IDs belong to unchanged catalog and assets match provenance hashes',
    () {
      final catalog =
          jsonDecode(
                File(
                  'lib/assets/data/exercises_catalog.json',
                ).readAsStringSync(),
              )
              as Map;
      final ids = (catalog['exercises'] as List).map((e) => e['id']).toSet();
      expect(ids, hasLength(180));
      final imageReviews =
          jsonDecode(
                File(
                  'tool/exercise_media_image_reviews.json',
                ).readAsStringSync(),
              )
              as List;
      expect(imageReviews, hasLength(180));
      expect(
        ExerciseIllustrations.verifiedByExerciseId.keys.toSet(),
        imageReviews
            .where((row) => row['status'] == 'verified')
            .map((row) => row['exerciseId'])
            .toSet(),
      );
      expect(ExerciseIllustrations.verifiedByExerciseId.length, 144);
      final manifest =
          jsonDecode(
                File(
                  'lib/assets/exercise_illustrations/manifest.json',
                ).readAsStringSync(),
              )
              as List;
      expect(
        manifest.map((item) => item['exerciseId']).toSet(),
        ExerciseIllustrations.verifiedByExerciseId.keys.toSet(),
      );
      for (final item in manifest) {
        expect(ids, contains(item['exerciseId']));
        final art =
            ExerciseIllustrations.verifiedByExerciseId[item['exerciseId']]!;
        expect(art.sourceUrl, item['sourceUrl']);
        expect(art.license, 'CC BY-SA 4.0');
        expect(art.changes, isNotEmpty);
        expect(
          sha256.convert(File(art.assetPath).readAsBytesSync()).toString(),
          item['assetSha256'],
        );
        expect(
          (item['dimensions'] as List).every((dimension) => dimension <= 512),
          isTrue,
        );
      }
      expect(
        File(ExerciseIllustrations.licenseAsset).readAsStringSync(),
        contains('Attribution-ShareAlike 4.0'),
      );
      expect(
        File('lib/assets/exercise_illustrations/NOTICE.md').readAsStringSync(),
        contains('without warranties'),
      );
      expect(
        ExerciseIllustrations.forExercise(
          const ExerciseLibraryItem(
            id: 'ex_spider_curl',
            nameEn: 'Spider Curl',
            source: ExerciseLibraryItemSource.builtIn,
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'complete audit represents every catalog ID and documents every gap',
    () {
      final catalog =
          jsonDecode(
                File(
                  'lib/assets/data/exercises_catalog.json',
                ).readAsStringSync(),
              )
              as Map;
      final audit =
          jsonDecode(File('docs/exercise-media-review.json').readAsStringSync())
              as Map;
      final rows = audit['exercises'] as List;
      final byId = {for (final row in rows) row['exercise_id']: row};
      expect(rows, hasLength(180));
      expect(byId, hasLength(180));
      for (final exercise in catalog['exercises'] as List) {
        final row = byId[exercise['id']]!;
        expect(row['audit_status'], 'reviewed');
        expect(row['name_en'], exercise['name_en']);
        expect(row['name_ar'], exercise['name_ar']);
        expect(row['equipment'], exercise['equipment']);
        expect(row['muscle_group'], exercise['muscle_group']);
        expect(row['movement_pattern'], isNotEmpty);
        expect(row['variation_requirements'], isNotEmpty);
        final art = ExerciseIllustrations.verifiedByExerciseId[exercise['id']];
        expect(row['image_status'] == 'verified', art != null);
        expect(row['image_asset'], art?.assetPath ?? '');
        if (art == null) expect(row['image_missing_reason'], isNotEmpty);
        final video = ExerciseVideoLinks.verifiedByExerciseId[exercise['id']];
        expect(row['video_status'] == 'verified page', video != null);
        expect(row['musclewiki_page'], video ?? '');
        if (video == null) expect(row['video_missing_reason'], isNotEmpty);
      }
      expect(
        sha256
            .convert(
              File('lib/assets/data/exercises_catalog.json').readAsBytesSync(),
            )
            .toString(),
        audit['catalogSha256'],
      );
      expect(
        File('docs/exercise-media-coverage.csv').readAsLinesSync(),
        hasLength(181),
      );
      expect(
        ExerciseIllustrations
            .verifiedByExerciseId['ex_bulgarian_split_squat']!
            .sourceUrl,
        contains('bulgarian-split-squat/frame-1.png'),
      );
      expect(
        ExerciseIllustrations
            .verifiedByExerciseId['ex_underhand_barbell_row']!
            .sourceUrl,
        endsWith('src/images-web/reverse-grips-bent-over-barbell-rows-2.png'),
      );
      expect(
        ExerciseIllustrations
            .verifiedByExerciseId['ex_chest_supported_machine_row']!
            .sourceUrl,
        endsWith('assets/chest-supported-row/frame-2.png'),
      );
      // These plausible candidates were inspected and rejected for equipment,
      // arm-count, or movement differences. Never silently inherit related art.
      for (final id in [
        'ex_spider_curl',
        'ex_reverse_lunge',
        'ex_captain_s_chair_leg_raise',
        'ex_donkey_calf_raise',
      ]) {
        expect(ExerciseIllustrations.verifiedByExerciseId[id], isNull);
      }
    },
  );

  test(
    'every distinct bundled illustration decodes within its size bound',
    () async {
      final paths = ExerciseIllustrations.verifiedByExerciseId.values
          .map((art) => art.assetPath)
          .toSet();
      expect(paths, hasLength(143));
      for (final path in paths) {
        final codec = await ui.instantiateImageCodec(
          File(path).readAsBytesSync(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, inInclusiveRange(1, 512), reason: path);
        expect(frame.image.height, inInclusiveRange(1, 512), reason: path);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test(
    'video links use exact reviewed IDs and never cross equipment or grip variants',
    () {
      expect(ExerciseVideoLinks.verifiedByExerciseId, hasLength(106));
      final evidence =
          jsonDecode(
                File(
                  'docs/exercise-media-page-evidence.json',
                ).readAsStringSync(),
              )
              as List;
      final reviewedPages = {
        for (final row in evidence) row['exerciseId']: row,
      };
      expect(
        reviewedPages.keys.toSet(),
        ExerciseVideoLinks.verifiedByExerciseId.keys.toSet(),
      );
      final catalog =
          jsonDecode(
                File(
                  'lib/assets/data/exercises_catalog.json',
                ).readAsStringSync(),
              )
              as Map;
      final ids = (catalog['exercises'] as List).map((e) => e['id']).toSet();
      for (final entry in ExerciseVideoLinks.verifiedByExerciseId.entries) {
        expect(ids, contains(entry.key));
        final uri = Uri.parse(entry.value);
        expect(uri.scheme, 'https');
        expect(uri.host, 'musclewiki.com');
        expect(
          uri.path,
          matches(r'^/(?:[a-z]{2}-[a-z]{2}/)?exercise/[a-z0-9-]+$'),
        );
        expect(uri.query, isEmpty);
        final review = reviewedPages[entry.key]!;
        expect(review['url'], entry.value);
        expect(review['matchReview'], isNotEmpty);
        expect(review['captureSha256'], matches(r'^[a-f0-9]{64}$'));
        expect(review['playbackVerified'], isFalse);
      }
      expect(
        ExerciseVideoLinks.forExercise(bench)?.toString(),
        'https://musclewiki.com/exercise/barbell-bench-press',
      );
      for (final id in [
        'ex_single_arm_lat_pulldown',
        'ex_reverse_grip_lat_pulldown',
        'ex_neutral_grip_lat_pulldown',
        'ex_single_leg_extension',
      ]) {
        expect(
          ExerciseVideoLinks.forExercise(
            ExerciseLibraryItem(
              id: id,
              nameEn: 'Unverified variation',
              source: ExerciseLibraryItemSource.builtIn,
            ),
          ),
          isNull,
        );
      }
      expect(
        ExerciseVideoLinks.forExercise(
          const ExerciseLibraryItem(
            id: 'ex_barbell_bench_press',
            nameEn: 'Custom',
            source: ExerciseLibraryItemSource.custom,
          ),
        ),
        isNull,
      );
      expect(ExerciseVideoLinks.forExercise(unmapped), isNull);
    },
  );

  test(
    'native browser adapter explicitly uses external application mode and handles failures',
    () async {
      final previous = UrlLauncherPlatform.instance;
      final browser = _Browser();
      UrlLauncherPlatform.instance = browser;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      final uri = ExerciseVideoLinks.forExercise(bench)!;
      expect(await openExerciseExternalUrl(uri), isTrue);
      expect(browser.url, uri.toString());
      expect(browser.mode, PreferredLaunchMode.externalApplication);
      browser.result = false;
      expect(await openExerciseExternalUrl(uri), isFalse);
      browser.fail = true;
      expect(await openExerciseExternalUrl(uri), isFalse);
      expect(
        await openExerciseExternalUrl(Uri.parse('file:///tmp/not-a-web-page')),
        isFalse,
      );
    },
  );

  testWidgets(
    'thumbnail and play open the reviewed page without changing selection',
    (tester) async {
      final opened = <Uri>[];
      var selectionChanges = 0;
      await tester.pumpWidget(
        app(
          ExerciseLibraryCard(
            exercise: bench,
            selected: false,
            onChanged: (_) => selectionChanges++,
            openExternal: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.byType(ExerciseArtwork));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('exercise-video-ex_barbell_bench_press')),
      );
      await tester.pumpAndSettle();
      expect(opened, [
        ExerciseVideoLinks.forExercise(bench),
        ExerciseVideoLinks.forExercise(bench),
      ]);
      expect(selectionChanges, 0);
      await tester.tap(find.text(bench.nameEn));
      expect(selectionChanges, 1);
      expect(opened, hasLength(2));
    },
  );

  testWidgets('unverified exercises have no play action', (tester) async {
    await tester.pumpWidget(
      app(
        ExerciseLibraryCard(
          exercise: unmapped,
          selected: false,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  for (final language in ['ar', 'en']) {
    testWidgets(
      'reviewed artwork, credits and video fit a small $language card',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            ExerciseLibraryCard(
              exercise: bench,
              selected: true,
              onChanged: null,
              illustration: ExerciseIllustrations.forExercise(bench),
              openExternal: (_) async => true,
            ),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        final imageX = tester.getCenter(find.byType(ExerciseArtwork)).dx;
        final selectionX = tester.getCenter(find.byType(Checkbox)).dx;
        expect(imageX < selectionX, language == 'en');
        expect(
          find.byKey(
            const ValueKey('exercise-artwork-credits-ex_barbell_bench_press'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('exercise-video-ex_barbell_bench_press')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['ar', 'en']) {
    testWidgets(
      'browser failure is localized and selection stays unchanged in $language',
      (tester) async {
        var selected = false;
        await tester.pumpWidget(
          app(
            ExerciseLibraryCard(
              exercise: bench,
              selected: selected,
              onChanged: (value) => selected = value,
              openExternal: (_) async =>
                  throw StateError('Browser unavailable'),
            ),
            language: language,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('exercise-video-ex_barbell_bench_press')),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ExerciseLibraryCard)),
        )!;
        expect(find.text(l10n.exerciseBrowserLaunchFailed), findsOneWidget);
        expect(selected, isFalse);
      },
    );
  }

  testWidgets('artwork credits and full license remain accessible offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ExerciseLibraryCard(
          exercise: bench,
          selected: false,
          onChanged: (_) {},
          illustration: ExerciseIllustrations.forExercise(bench),
        ),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('exercise-artwork-credits-ex_barbell_bench_press'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Everkinetic / Greg Priday'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Read illustration license (offline)'),
    );
    await tester.tap(find.text('Read illustration license (offline)'));
    await tester.pumpAndSettle();
    expect(find.text('CC BY-SA 4.0'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
