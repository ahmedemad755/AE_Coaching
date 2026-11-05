import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_video_links.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExerciseSourcesScreen extends StatelessWidget {
  const ExerciseSourcesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.repdbDataSources)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton(
            onPressed: () async {
              var opened = false;
              try {
                opened = await openExerciseExternalUrl(
                  Uri.parse('https://repdb.co'),
                );
              } catch (_) {
                /* Localized launch feedback below. */
              }
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.exerciseBrowserLaunchFailed)),
                );
              }
            },
            child: const Text('Exercise data by RepDB (repdb.co)'),
          ),
          SelectableText(
            '${l10n.repdbDatasetVersion}: ${ExerciseCatalogRepository.datasetCommit}',
          ),
          const SizedBox(height: 16),
          Text(
            l10n.repdbSourceLicense,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: rootBundle.loadString(ExerciseMediaResolver.licenseAsset),
            builder: (context, snapshot) => snapshot.hasError
                ? Text(l10n.exerciseLibraryLoadError)
                : snapshot.hasData
                ? SelectableText(
                    snapshot.data!,
                    textDirection: TextDirection.ltr,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
