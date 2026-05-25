import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class WorkoutAnalyticsArgs {
  final String exerciseName;
  final String totalVolume;
  final String progressDelta;

  const WorkoutAnalyticsArgs({
    required this.exerciseName,
    required this.totalVolume,
    required this.progressDelta,
  });
}

Future<void> captureAndShareWorkout(ScreenshotController controller) async {
  try {
    final Uint8List? imageBytes = await controller.capture(
      delay: const Duration(milliseconds: 50),
    );

    if (imageBytes == null || imageBytes.isEmpty) {
      debugPrint(
        'Workout progress share failed: screenshot capture returned empty bytes.',
      );
      return;
    }

    final Directory temporaryDirectory = await getTemporaryDirectory();
    final File snapshotFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}ae_coaching_snapshot.png',
    );

    await snapshotFile.writeAsBytes(imageBytes, flush: true);

    await Share.shareXFiles(
      [XFile(snapshotFile.path, mimeType: 'image/png')],
      text: 'بص نظرة على حجم التطور بتاعي النهاردة في الجيم! 🏋️‍♂️📊 #AECoaching',
    );
  } on FileSystemException catch (error, stackTrace) {
    debugPrint(
      'Workout progress share file I/O failed: ${error.message}\n$stackTrace',
    );
  } catch (error, stackTrace) {
    debugPrint('Workout progress share failed: $error\n$stackTrace');
  }
}

Widget buildInstagramShareCard({
  required String exerciseName,
  required String totalVolume,
  required String progressDelta,
}) {
  return Container(
    width: 360,
    height: 520,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E293B),
          Color(0xFF0F172A),
        ],
      ),
      border: Border.all(
        color: const Color(0xFF38BDF8),
        width: 2,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'AE COACHING',
              style: TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const Spacer(),
        const Text(
          "TODAY'S PROGRESS",
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          exerciseName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'TOTAL TRAINING VOLUME',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            totalVolume,
            style: const TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 54,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF4ADE80).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.trending_up,
                color: Color(0xFF4ADE80),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'أتطورت بمعدل $progressDelta% عن التمرين اللي فات! 🔥',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Center(
          child: Text(
            'Tracked smoothly via AE Coaching App 🚀',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    ),
  );
}

class WorkoutAnalyticsScreen extends StatefulWidget {
  final String exerciseName;
  final String totalVolume;
  final String progressDelta;

  const WorkoutAnalyticsScreen({
    super.key,
    required this.exerciseName,
    required this.totalVolume,
    required this.progressDelta,
  });

  static Route<void> route(WorkoutAnalyticsArgs args) {
    return MaterialPageRoute(
      builder: (_) => WorkoutAnalyticsScreen(
        exerciseName: args.exerciseName,
        totalVolume: args.totalVolume,
        progressDelta: args.progressDelta,
      ),
    );
  }

  @override
  State<WorkoutAnalyticsScreen> createState() => _WorkoutAnalyticsScreenState();
}

class _WorkoutAnalyticsScreenState extends State<WorkoutAnalyticsScreen> {
  late final ScreenshotController _screenshotController;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _screenshotController = ScreenshotController();
  }

  Future<void> _shareWorkoutProgress() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    try {
      await captureAndShareWorkout(_screenshotController);
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Screenshot(
                  controller: _screenshotController,
                  child: buildInstagramShareCard(
                    exerciseName: widget.exerciseName,
                    totalVolume: widget.totalVolume,
                    progressDelta: widget.progressDelta,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareWorkoutProgress,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share),
                  label: Text(_isSharing ? 'Sharing...' : 'Share Progress'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    disabledBackgroundColor:
                        const Color(0xFF38BDF8).withValues(alpha: 0.44),
                    foregroundColor: const Color(0xFF0F172A),
                    disabledForegroundColor: Colors.white70,
                    elevation: 10,
                    shadowColor: const Color(0xFF38BDF8).withValues(alpha: 0.32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
