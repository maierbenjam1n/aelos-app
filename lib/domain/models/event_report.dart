import 'dart:typed_data';

/// The guided photo sequence for documenting an event, in order.
enum PhotoAngle {
  front('Front', 'The whole top plate, straight on, with the strings and bridge in view.'),
  back('Back', 'Turn the instrument over and photograph the whole back.'),
  bassSide('Left side', 'The bass-side rib, from the end button to the neck.'),
  trebleSide('Right side', 'The treble-side rib, from the end button to the neck.'),
  scroll('Scroll and pegbox', 'The scroll, pegbox and neck from the side.'),
  detail('Close-up', 'Any mark, crack or open seam you noticed. Skip if there is none.', optional: true);

  const PhotoAngle(this.label, this.guidance, {this.optional = false});

  final String label;
  final String guidance;
  final bool optional;
}

/// One guided photo. [bytes] for photos taken in the app; [assetPath] for
/// the demo's pre-filled reports.
final class ReportPhoto {
  const ReportPhoto({required this.angle, required this.takenAt, this.bytes, this.assetPath});

  final PhotoAngle angle;
  final DateTime takenAt;
  final Uint8List? bytes;
  final String? assetPath;
}

enum ReportStatus {
  submitted('Sent'),
  reviewed('Reviewed'),
  inspectionScheduled('Inspection scheduled'),
  resolved('Resolved');

  const ReportStatus(this.label);

  final String label;
}

/// An owner's or renter's account of an event, with guided photos.
///
/// Owner-supplied, not signed: it refers to the signed record by [eventSeq],
/// but the explanation and photos are not part of the hash chain.
final class EventReport {
  const EventReport({
    required this.id,
    required this.instrumentId,
    required this.eventTitle,
    required this.eventTime,
    required this.explanation,
    required this.photos,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.eventSeq,
    this.causes = const [],
    this.luthierId,
    this.status = ReportStatus.submitted,
    this.luthierNote,
  });

  final String id;
  final String instrumentId;

  /// Sequence number of the signed record being documented, if any.
  final int? eventSeq;

  /// E.g. "Strong impact recorded · 7.2 g".
  final String eventTitle;

  /// Signed time of the event (format it with the instrument's displayTime).
  final DateTime eventTime;
  final String explanation;

  /// Quick answers chosen in the first step, e.g. "Case was dropped".
  final List<String> causes;
  final List<ReportPhoto> photos;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  /// The luthier it was sent to; null for an owner's own record.
  final String? luthierId;
  final ReportStatus status;
  final String? luthierNote;

  EventReport copyWith({ReportStatus? status, String? luthierNote}) => EventReport(
        id: id,
        instrumentId: instrumentId,
        eventSeq: eventSeq,
        eventTitle: eventTitle,
        eventTime: eventTime,
        explanation: explanation,
        causes: causes,
        photos: photos,
        authorId: authorId,
        authorName: authorName,
        createdAt: createdAt,
        luthierId: luthierId,
        status: status ?? this.status,
        luthierNote: luthierNote ?? this.luthierNote,
      );
}
