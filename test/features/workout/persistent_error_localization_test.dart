import 'package:ae_coaching/core/feedback/feedback_card.dart';
import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Fakes emit exactly the error state the real Cubits emit; no Cubit logic
// is changed or exercised here, only how the screens present the error.

class _FailingAnalytics extends Cubit<ProgramAnalyticsState>
    implements ProgramAnalyticsCubit {
  _FailingAnalytics(this.message) : super(const ProgramAnalyticsInitial());
  final String message;
  @override
  Future<void> loadAnalytics(String programId) async =>
      emit(ProgramAnalyticsError(message));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IdleConsistency extends Cubit<ProgramConsistencyState>
    implements ProgramConsistencyCubit {
  _IdleConsistency() : super(const ProgramConsistencyInitial());
  @override
  Future<void> loadConsistency(String programId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingHistory extends Cubit<WorkoutHistoryState>
    implements WorkoutHistoryCubit {
  _FailingHistory(this.message) : super(const WorkoutHistoryInitial());
  final String message;
  @override
  Future<void> loadHistory(String workoutTemplateId) async =>
      emit(WorkoutHistoryError(message));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _program = WorkoutProgram(
  id: 'p1',
  name: 'Push Pull Legs',
  createdAt: DateTime(2026),
);
final _template = WorkoutTemplate(
  id: 't1',
  programId: 'p1',
  name: 'Push Day',
  createdAt: DateTime(2026),
);

Widget _app(Locale locale, Widget screen) => MaterialApp(
  builder: AppFeedbackHost.builder,
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  home: screen,
);

void main() {
  const technical =
      'Only an inProgress session can be completed '
      '(current status: completed).';
  const unknown = 'Invalid/restricted RepDB image path.';

  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('${locale.languageCode}:', () {
      late AppLocalizations l10n;
      setUpAll(() async => l10n = await AppLocalizations.delegate.load(locale));

      final cases = {
        'User not authenticated': (AppLocalizations l) =>
            l.feedbackSignInRequired,
        technical: (AppLocalizations l) => l.feedbackWorkoutNotActive,
        unknown: (AppLocalizations l) => l.feedbackGenericError,
      };

      for (final entry in cases.entries) {
        testWidgets(
          'Program Analytics shows "${entry.key}" localized, inline',
          (tester) async {
            final analytics = _FailingAnalytics(entry.key);
            final consistency = _IdleConsistency();
            addTearDown(analytics.close);
            addTearDown(consistency.close);
            await tester.pumpWidget(
              _app(
                locale,
                MultiBlocProvider(
                  providers: [
                    BlocProvider<ProgramAnalyticsCubit>.value(value: analytics),
                    BlocProvider<ProgramConsistencyCubit>.value(
                      value: consistency,
                    ),
                  ],
                  child: ProgramAnalyticsScreen(program: _program),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();

            expect(find.text(entry.value(l10n)), findsOneWidget);
            expect(find.text(entry.key), findsNothing, reason: 'raw text');
            expect(find.byType(FeedbackCard), findsNothing, reason: 'inline');
          },
        );

        testWidgets('Workout History shows "${entry.key}" localized, inline', (
          tester,
        ) async {
          final history = _FailingHistory(entry.key);
          addTearDown(history.close);
          await tester.pumpWidget(
            _app(
              locale,
              BlocProvider<WorkoutHistoryCubit>.value(
                value: history,
                child: WorkoutTemplateHistoryScreen(template: _template),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text(entry.value(l10n)), findsOneWidget);
          expect(find.text(entry.key), findsNothing, reason: 'raw text');
          expect(find.byType(FeedbackCard), findsNothing, reason: 'inline');
        });
      }
    });
  }
}
