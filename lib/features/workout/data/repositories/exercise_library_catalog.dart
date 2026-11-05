import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';

abstract interface class ExerciseLibraryCatalog {
  Future<List<ExerciseLibraryItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  });
}
