import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/accounts.dart';
import '../../data/instrument_data.dart';
import '../../data/sensor_session.dart';
import '../../domain/models/account.dart';
import '../../domain/models/condition_status.dart';
import '../../domain/models/event_report.dart';
import '../../domain/thresholds/alert.dart';
import '../../sensor/sensor_connection.dart';

/// One instrument in the luthier's care with its rental.
final class FleetEntry {
  const FleetEntry({required this.data, required this.rental});

  final InstrumentData data;
  final Rental rental;

  String get id => data.id;
  ConditionStatus get status => data.status;
  bool get inWorkshop => rental.inWorkshop;

  /// The newest alert, for "why it needs attention".
  Alert? get latestAlert => data.alerts.isEmpty ? null : data.alerts.last;
}

/// An alert with the instrument and rental it belongs to.
final class FleetAlert {
  const FleetAlert({required this.alert, required this.entry});

  final Alert alert;
  final FleetEntry entry;

  DateTime get displayTime => entry.data.displayTime(alert.time);
}

/// A report with its instrument, when that instrument is in the fleet.
final class FleetReport {
  const FleetReport({required this.report, required this.entry});

  final EventReport report;
  final FleetEntry? entry;

  bool get needsReview => report.status == ReportStatus.submitted;

  /// Signed event time, shifted like every seeded time.
  DateTime get eventTime =>
      entry?.data.displayTime(report.eventTime) ?? report.eventTime.toLocal();

  /// When it was sent.
  DateTime get sentTime => display(report.createdAt);

  /// An unsigned report time (sent, photo taken) for display. Reports seeded
  /// on the seed's timeline (before its end) get the same shift as the
  /// records; reports made in this session carry real time already.
  DateTime display(DateTime t) {
    final data = entry?.data;
    if (data == null) return t.toLocal();
    final seedEnd = DateTime.now().toUtc().subtract(data.displayOffset);
    return t.isBefore(seedEnd) ? data.displayTime(t) : t.toLocal();
  }
}

/// The signed-in luthier's workshop.
final workshopProvider = Provider<Luthier?>(
  (ref) => DemoDirectory.luthierById(ref.watch(accountProvider)?.luthierId),
);

/// The fleet: worst status first, then rented out before the workshop, then
/// in seed order.
final fleetProvider = Provider<List<FleetEntry>>((ref) {
  final rentals = ref.watch(rentalsProvider);
  final entries = [
    for (final data in ref.watch(visibleInstrumentsProvider))
      if (rentals.where((r) => r.instrumentId == data.id).firstOrNull case final rental?)
        FleetEntry(data: data, rental: rental),
  ];
  final order = {for (final (i, e) in entries.indexed) e.id: i};
  return entries
    ..sort((a, b) {
      final bySeverity = b.status.index.compareTo(a.status.index);
      if (bySeverity != 0) return bySeverity;
      final byPlace = (a.inWorkshop ? 1 : 0).compareTo(b.inWorkshop ? 1 : 0);
      return byPlace != 0 ? byPlace : order[a.id]!.compareTo(order[b.id]!);
    });
});

/// Every alert across the fleet, newest first.
final fleetAlertsProvider = Provider<List<FleetAlert>>((ref) {
  final alerts = [
    for (final entry in ref.watch(fleetProvider))
      for (final alert in entry.data.alerts) FleetAlert(alert: alert, entry: entry),
  ]..sort((a, b) => b.alert.time.add(b.entry.data.displayOffset)
      .compareTo(a.alert.time.add(a.entry.data.displayOffset)));
  return alerts;
});

/// Reports sent to this luthier: unreviewed first, then newest first.
final fleetReportsProvider = Provider<List<FleetReport>>((ref) {
  final account = ref.watch(accountProvider);
  final fleet = ref.watch(fleetProvider);
  if (account?.role != AccountRole.luthier) return const [];
  final reports = [
    for (final report in ref.watch(eventReportsProvider))
      if (report.luthierId == account!.luthierId)
        FleetReport(
          report: report,
          entry: fleet.where((e) => e.id == report.instrumentId).firstOrNull,
        ),
  ];
  int rank(FleetReport r) => switch (r.report.status) {
        ReportStatus.submitted => 0,
        ReportStatus.inspectionScheduled => 1,
        ReportStatus.reviewed => 2,
        ReportStatus.resolved => 3,
      };
  reports.sort((a, b) {
    final byStatus = rank(a).compareTo(rank(b));
    return byStatus != 0 ? byStatus : b.sentTime.compareTo(a.sentTime);
  });
  return reports;
});

/// Something on the overview's "Needs your attention" list.
sealed class AttentionItem {
  const AttentionItem();

  ConditionStatus get severity;
  DateTime get time;
}

final class InstrumentAttention extends AttentionItem {
  const InstrumentAttention(this.entry);

  final FleetEntry entry;

  @override
  ConditionStatus get severity => entry.status;

  @override
  DateTime get time => switch (entry.latestAlert) {
        final a? => entry.data.displayTime(a.time),
        null => DateTime.now(),
      };
}

final class ReportAttention extends AttentionItem {
  const ReportAttention(this.report);

  final FleetReport report;

  /// A renter took the trouble to document it: treat it as needing attention.
  @override
  ConditionStatus get severity => ConditionStatus.attention;

  @override
  DateTime get time => report.sentTime;
}

/// Instruments not calm and reports not yet reviewed, by severity, then
/// instruments before reports, then newest first.
final attentionProvider = Provider<List<AttentionItem>>((ref) {
  final items = <AttentionItem>[
    for (final e in ref.watch(fleetProvider))
      if (e.status != ConditionStatus.calm) InstrumentAttention(e),
    for (final r in ref.watch(fleetReportsProvider))
      if (r.needsReview) ReportAttention(r),
  ];
  items.sort((a, b) {
    final bySeverity = b.severity.index.compareTo(a.severity.index);
    if (bySeverity != 0) return bySeverity;
    final byKind = (a is ReportAttention ? 1 : 0).compareTo(b is ReportAttention ? 1 : 0);
    return byKind != 0 ? byKind : b.time.compareTo(a.time);
  });
  return items;
});

/// The instrument whose sensor is streaming right now, if any.
final liveFleetIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  final live = session?.status == ConnectionStatus.connected ||
      session?.status == ConnectionStatus.syncing;
  return live ? session!.instrumentId : null;
});
