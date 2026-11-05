import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_illustrations.dart';

class ExerciseMedia {
  const ExerciseMedia({this.start, this.peak, this.main, this.legacy});
  final String? start, peak, main;
  final ExerciseIllustration? legacy;
  String? get thumbnailPath => peak ?? main ?? start ?? legacy?.assetPath;

  ExerciseIllustration? illustration(String? path) => path == null
      ? null
      : ExerciseIllustration(
          assetPath: path,
          author: 'RepDB',
          sourceUrl: 'https://repdb.co',
          license: 'RepDB Free Tier License v1.0',
        );

  ExerciseIllustration? get thumbnail => legacy ?? illustration(thumbnailPath);
}

/// Canonical IDs and official relative paths own media resolution. No matching
/// by translated name, no network images, and no premium asset fallback.
abstract final class ExerciseMediaResolver {
  static const assetRoot = 'lib/assets/repdb/';
  static const licenseAsset = '${assetRoot}LICENSE-DATA.md';

  static ExerciseMedia resolve(ExerciseLibraryItem exercise) {
    if (exercise.source == ExerciseLibraryItemSource.custom) {
      return const ExerciseMedia();
    }
    final item = exercise.catalogExercise;
    if (item?.isRepDb != true) {
      return ExerciseMedia(legacy: ExerciseIllustrations.forExercise(exercise));
    }
    String? asset(String? path) => path == null ? null : '$assetRoot$path';
    return ExerciseMedia(
      start: asset(item!.startImage),
      peak: asset(item.peakImage),
      main: asset(item.mainImage),
    );
  }
}
