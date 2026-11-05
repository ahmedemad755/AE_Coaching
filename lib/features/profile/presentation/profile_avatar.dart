import 'dart:io';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.semanticLabel,
    this.photoPath,
    this.onTap,
    this.onImageError,
    this.isLoading = false,
    this.size = 84,
    this.showActionBadge = true,
  });

  final String name;
  final String semanticLabel;
  final String? photoPath;
  final VoidCallback? onTap;
  final VoidCallback? onImageError;
  final bool isLoading;
  final double size;
  final bool showActionBadge;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'AE';
    final first = String.fromCharCode(parts.first.runes.first);
    if (parts.length == 1) return first.toUpperCase();
    return '$first${String.fromCharCode(parts.last.runes.first)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semanticLabel,
    child: InkWell(
      onTap: isLoading ? null : onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: photoPath == null
                  ? null
                  : FileImage(File(photoPath!)),
              onBackgroundImageError: photoPath == null || onImageError == null
                  ? null
                  : (_, _) => onImageError!(),
              child: photoPath == null
                  ? Text(
                      _initials,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: size < 56 ? size * 0.34 : null,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            if (isLoading)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (showActionBadge)
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
