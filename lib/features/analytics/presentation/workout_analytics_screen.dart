import 'dart:io';
import 'dart:typed_data';

import 'package:ae_coaching/l10n/app_localizations.dart';
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
  required AppLocalizations l10n,
  required String exerciseName,
  required String totalVolume,
  required String progressDelta,
}) {
  // 🔥 كشف ما إذا كان المستوى متراجع (يحتوي على سالب أو قيمته سالبة)
  final double? deltaValue = double.tryParse(progressDelta.replaceAll('%', '').trim());
  final bool isNegative = progressDelta.contains('-') || (deltaValue != null && deltaValue < 0);
  
  // شيل علامة السالب من النص لو موجودة عشان شكل التصميم، لأننا هنعوض عنها بكلمة "تراجع" أو بشكل الـ UI الاحمر
  final String cleanDelta = progressDelta.replaceAll('-', '').trim();

  // 🎨 تحديد الألوان بناءً على الحالة (أخضر للتقدم / أحمر للتراجع)
  final Color statusColor = isNegative ? const Color(0xFFEF4444) : const Color(0xFF4ADE80);
  final String statusText = isNegative 
      ? 'المستوى مريح بمعدل $cleanDelta% عن التمرين اللي فات! شد حيلك وعوض 🦾' 
      : 'أتطورت بمعدل $cleanDelta% عن التمرين اللي فات! 🔥';

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
        Text(
          l10n.todaysProgressLabel,
          style: const TextStyle(
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
        Text(
          l10n.totalTrainingVolumeLabel,
          style: const TextStyle(
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
            style: TextStyle(
              color: statusColor, // 🟢🔴 بيتغير ديناميكياً حسب الحالة
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
            color: statusColor.withValues(alpha: 0.14), // خلفية خفيفة من نفس اللون الحرج
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isNegative ? Icons.trending_down : Icons.trending_up, // سهم نازل لو سالب وسهم طالع لو موجب
                color: statusColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
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
            l10n.trackedViaFooter,
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
    final l10n = AppLocalizations.of(context)!;
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
                    l10n: l10n,
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
                  label: Text(_isSharing ? l10n.sharingButton : l10n.shareProgressButton),
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