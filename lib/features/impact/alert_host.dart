import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/instruments_notifier.dart';
import '../../data/sensor_session.dart';
import '../../domain/thresholds/alert.dart';
import '../../domain/thresholds/threshold_config.dart';
import 'impact_takeover_screen.dart';

/// Sits above the app's navigator and turns live alerts into a system
/// notification, plus the full-screen takeover for impacts and falls.
class AlertHost extends ConsumerWidget {
  const AlertHost({
    super.key,
    required this.navigatorKey,
    required this.onOpenInstrument,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(String instrumentId) onOpenInstrument;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..listen(alertEventsProvider, (_, next) {
        if (next.value case final alert?) _onAlert(ref, alert);
      })
      ..listen(awaySummaryProvider, (previous, next) {
        final summary = next?.alerts;
        if (previous == null && summary != null) {
          final name = ref.read(instrumentProvider(summary.instrumentId))?.instrument.name ?? '';
          ref.read(notificationServiceProvider).showSummary(summary, instrumentName: name);
        }
      });
    return child;
  }

  void _onAlert(WidgetRef ref, Alert alert) {
    final data = ref.read(instrumentProvider(alert.instrumentId));
    if (data == null) return;
    ref.read(notificationServiceProvider).showAlert(alert, instrumentName: data.instrument.name);

    final isEvent = alert.rule == ThresholdRule.impact || alert.rule == ThresholdRule.freeFall;
    final navigator = navigatorKey.currentState;
    if (!isEvent || navigator == null) return;
    navigator.push(
      ImpactTakeoverScreen.route(
        ImpactTakeoverScreen(
          alert: alert,
          instrumentName: data.instrument.name,
          displayTime: data.displayTime(alert.time),
          onDismiss: navigator.pop,
          onViewInstrument: () {
            navigator.pop();
            onOpenInstrument(alert.instrumentId);
          },
        ),
      ),
    );
  }
}
