import 'dart:io';

import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _file(String path) async => File(path).readAsStringSync();

void main() {
  test(
    'the background parse gives exactly the same catalog as the inline one',
    () async {
      final inline = await ExerciseCatalogRepository(
        loadAsset: _file,
      ).loadCatalog();
      final background = await ExerciseCatalogRepository(
        loadAsset: _file,
        parseInBackground: true,
      ).loadCatalog();

      expect(background, hasLength(inline.length));
      expect(
        background.map((e) => e.id).toList(),
        inline.map((e) => e.id).toList(),
      );
      for (var i = 0; i < inline.length; i++) {
        expect(background[i].nameAr, inline[i].nameAr, reason: inline[i].id);
        expect(
          background[i].peakImage,
          inline[i].peakImage,
          reason: inline[i].id,
        );
        expect(
          background[i].instructionsAr,
          inline[i].instructionsAr,
          reason: inline[i].id,
        );
      }
      expect(() => background.add(background.first), throwsUnsupportedError);
    },
  );

  test('a broken catalog still fails loudly in the background', () async {
    final repository = ExerciseCatalogRepository(
      loadAsset: (path) async => path == ExerciseCatalogRepository.assetPath
          ? '{"schema_version": 99}'
          : _file(path),
      parseInBackground: true,
    );
    await expectLater(repository.loadCatalog(), throwsFormatException);
  });
}
