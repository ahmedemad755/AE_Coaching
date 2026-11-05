import 'package:ae_coaching/features/workout/data/models/standard_workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StandardWorkoutTemplatesState {
  final bool loading;
  final bool failed;
  final List<StandardWorkoutSplit> splits;
  const StandardWorkoutTemplatesState({
    this.loading = false,
    this.failed = false,
    this.splits = const [],
  });
}

class StandardWorkoutTemplatesCubit
    extends Cubit<StandardWorkoutTemplatesState> {
  final StandardWorkoutTemplateRepository repository;
  StandardWorkoutTemplatesCubit(this.repository)
    : super(const StandardWorkoutTemplatesState());
  Future<void> load() async {
    emit(const StandardWorkoutTemplatesState(loading: true));
    try {
      final splits = await repository.loadTemplates();
      if (!isClosed) emit(StandardWorkoutTemplatesState(splits: splits));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        // Only asset/parser details are useful here. Unexpected exceptions may
        // contain arbitrary text, so log their type rather than their payload.
        final reason = error is FormatException
            ? error.message
            : error.runtimeType;
        debugPrint(
          '[WorkoutTemplates] Load failed '
          '(asset=${StandardWorkoutTemplateRepository.assetPath}, '
          'reason=$reason)',
        );
        debugPrintStack(
          label: '[WorkoutTemplates] Loading stack trace',
          stackTrace: stackTrace,
        );
      }
      if (!isClosed) emit(const StandardWorkoutTemplatesState(failed: true));
    }
  }
}
