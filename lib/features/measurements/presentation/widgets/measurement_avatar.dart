import 'package:flutter/material.dart';

/// Small rounded illustration shown next to a body-part name/field —
/// e.g. the chest/waist/arm images in `lib/assets/`. Falls back to a
/// neutral icon if an asset is ever missing so a bad image never
/// crashes the Measurements UI.
class MeasurementAvatar extends StatelessWidget {
  final String imagePath;
  final double size;

  const MeasurementAvatar({
    super.key,
    required this.imagePath,
    this.size = 28,
  });

  static const Color _blue = Color(0xff2f80ed);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xffeaf2fc),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.fitness_center, color: _blue, size: 16);
          },
        ),
      ),
    );
  }
}
