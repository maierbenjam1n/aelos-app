import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/event_report.dart';

/// A report photo from memory (taken in the app) or from the bundle (the
/// demo's pre-filled reports). Falls back to a quiet surface.
class ReportPhotoImage extends StatelessWidget {
  const ReportPhotoImage(this.photo, {super.key, this.fit = BoxFit.cover, this.cacheWidth});

  final ReportPhoto photo;
  final BoxFit fit;

  /// Decode width in physical pixels, for thumbnails.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: AelosColors.of(context).surface);
    Widget frame(BuildContext context, Widget child, int? frame, bool sync) => sync
        ? child
        : AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: Motion.medium,
            curve: Motion.enter,
            child: child,
          );
    if (photo.bytes case final bytes?) {
      return Image.memory(
        bytes,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        frameBuilder: frame,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (photo.assetPath case final path?) {
      return Image.asset(
        path,
        fit: fit,
        cacheWidth: cacheWidth,
        frameBuilder: frame,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}
