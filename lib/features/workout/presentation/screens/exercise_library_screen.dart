import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_picker_dialog.dart';
import 'package:flutter/material.dart';

/// Full-screen browsing within the existing workout selection flows. The
/// caller owns persistence and receives the same typed selection result.
class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({
    super.key,
    required this.catalog,
    required this.customExercises,
    required this.languageCode,
    this.excludedIds = const {},
    this.excludedNames = const {},
    this.singleSelectionOnly = false,
    this.onAddSelected,
    this.saveErrorMessage,
  });
  final ExerciseLibraryCatalog catalog;
  final CustomExerciseRepository customExercises;
  final String languageCode;
  final Set<String> excludedIds, excludedNames;
  final bool singleSelectionOnly;
  final Future<void> Function(List<ExerciseLibraryItem>)? onAddSelected;
  final String Function(Object)? saveErrorMessage;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ExercisePickerDialog(
      catalog: catalog,
      customExercises: customExercises,
      languageCode: languageCode,
      excludedIds: excludedIds,
      excludedNames: excludedNames,
      singleSelectionOnly: singleSelectionOnly,
      onAddSelected: onAddSelected,
      saveErrorMessage: saveErrorMessage,
      fullScreen: true,
    ),
  );
}
