import 'package:flutter/material.dart';

import '../../domain/models/event_report.dart';

/// Quick answers offered on the first step, in the order shown.
const reportCauses = [
  'Case was dropped',
  'Knocked against something',
  'During transport',
  'While playing',
  'I don’t know',
];

extension PhotoAngleCopy on PhotoAngle {
  /// Screen title for the angle's step.
  String get title => switch (this) {
        PhotoAngle.front => 'The front',
        PhotoAngle.back => 'The back',
        PhotoAngle.bassSide => 'The left side',
        PhotoAngle.trebleSide => 'The right side',
        PhotoAngle.scroll => 'Scroll and pegbox',
        PhotoAngle.detail => 'A close-up',
      };

  /// A practical hint under the guidance.
  String get tip => switch (this) {
        PhotoAngle.front => 'Lay it on a soft cloth in daylight and hold the phone level above the bridge.',
        PhotoAngle.back => 'Turn it over gently onto the cloth; keep the bridge side off the table edge.',
        PhotoAngle.bassSide => 'Stand it on its end button, or lay it on its back and crouch to rib height.',
        PhotoAngle.trebleSide => 'The same again from the other side, so every seam is on record.',
        PhotoAngle.scroll => 'Come close: the cheeks, the pegs and where the neck meets the pegbox.',
        PhotoAngle.detail => 'Fill the frame with the spot. A coin beside it helps show the size.',
      };

  /// Short label for grids and the viewfinder.
  String get short => switch (this) {
        PhotoAngle.front => 'Front',
        PhotoAngle.back => 'Back',
        PhotoAngle.bassSide => 'Left side',
        PhotoAngle.trebleSide => 'Right side',
        PhotoAngle.scroll => 'Scroll',
        PhotoAngle.detail => 'Close-up',
      };
}

extension ReportStatusLook on ReportStatus {
  IconData get icon => switch (this) {
        ReportStatus.submitted => Icons.north_east_rounded,
        ReportStatus.reviewed => Icons.visibility_outlined,
        ReportStatus.inspectionScheduled => Icons.event_outlined,
        ReportStatus.resolved => Icons.check_circle_outline_rounded,
      };
}

/// "Strong impact recorded · 7.2 g" for an impact (tenths of g) or a drop (ms).
String eventTitleFor({required bool fall, required int measured, String? headline}) {
  final value = fall ? '$measured ms' : '${(measured / 10).toStringAsFixed(1)} g';
  return '${headline ?? (fall ? 'Drop recorded' : 'Impact recorded')} · $value';
}

/// Splits "Strong impact recorded · 7.2 g" into headline, number and unit.
({String headline, String? number, String? unit}) splitEventTitle(String title) {
  final i = title.lastIndexOf(' · ');
  if (i < 0) return (headline: title, number: null, unit: null);
  final value = title.substring(i + 3).trim();
  final space = value.lastIndexOf(' ');
  return (
    headline: title.substring(0, i),
    number: space < 0 ? value : value.substring(0, space),
    unit: space < 0 ? null : value.substring(space + 1),
  );
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today · 14:32", "Yesterday · 09:10" or "18 Oct · 16:31", for a time
/// already shifted to display time.
String formatWhen(DateTime display, {DateTime? now}) {
  final local = display.toLocal();
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(local);
  final clock = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  final days = today.difference(day).inDays;
  final date = switch (days) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => '${local.day} ${_months[local.month - 1]}${local.year == today.year ? '' : ' ${local.year}'}',
  };
  return '$date · $clock';
}

/// Two initials for a monogram, e.g. "AB" for "Atelier Brunner".
String initialsOf(String name) {
  final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
