import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/theme/tokens.dart';
import '../../data/accounts.dart';
import '../../data/instruments_notifier.dart';
import '../../data/sensor_session.dart';
import '../../domain/models/account.dart';
import '../../domain/thresholds/alert.dart';
import '../../domain/thresholds/threshold_config.dart';
import '../event_report/event_report_flow.dart';
import '../event_report/report_copy.dart';
import 'fleet_banner.dart';
import 'impact_takeover_screen.dart';

/// Sits above the app's navigator and turns live alerts into a system
/// notification, plus the full-screen takeover for impacts and falls. A
/// luthier gets a calm banner instead: the knock happened to a renter.
class AlertHost extends ConsumerStatefulWidget {
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
  ConsumerState<AlertHost> createState() => _AlertHostState();
}

class _AlertHostState extends ConsumerState<AlertHost> {
  /// Long enough to read across the room, short enough not to linger.
  static const _bannerFor = Duration(seconds: 9);

  Alert? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) unawaited(ref.read(notificationServiceProvider).init());
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(alertEventsProvider, (_, next) {
        if (next.value case final alert?) _onAlert(ref, alert);
      })
      ..listen(awaySummaryProvider, (previous, next) {
        final summary = next?.alerts;
        if (previous == null && summary != null) {
          final name =
              ref
                  .read(instrumentProvider(summary.instrumentId))
                  ?.instrument
                  .name ??
              '';
          ref
              .read(notificationServiceProvider)
              .showSummary(summary, instrumentName: name);
        }
      });
    final banner = _banner;
    // The Stack is always there so the navigator below never remounts.
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, 0),
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: banner == null ? const SizedBox.shrink() : _fleetBanner(banner),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fleetBanner(Alert alert) {
    final data = ref.read(instrumentProvider(alert.instrumentId));
    final rental = ref.read(rentalsProvider.notifier).forInstrument(alert.instrumentId);
    final isFall = alert.rule == ThresholdRule.freeFall;
    final value = isFall ? '${alert.measured} ms' : '${(alert.measured / 10).toStringAsFixed(1)} g';
    final clock = data == null ? null : formatWhen(data.displayTime(alert.time)).split(' · ').last;
    return FleetBanner(
      key: ValueKey(alert),
      eyebrow: clock == null ? 'Fleet alert' : 'Fleet alert · $clock',
      title: '${data?.instrument.name ?? 'Instrument'} · $value',
      detail: [?rental?.renterName, alert.title].join(' · '),
      severity: alert.severity,
      icon: isFall ? Icons.south_rounded : Icons.flash_on_rounded,
      onOpen: () {
        _hideBanner();
        widget.onOpenInstrument(alert.instrumentId);
      },
      onDismiss: _hideBanner,
    );
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    if (mounted) setState(() => _banner = null);
  }

  void _onAlert(WidgetRef ref, Alert alert) {
    final data = ref.read(instrumentProvider(alert.instrumentId));
    if (data == null) return;
    ref
        .read(notificationServiceProvider)
        .showAlert(alert, instrumentName: data.instrument.name);

    final isEvent =
        alert.rule == ThresholdRule.impact ||
        alert.rule == ThresholdRule.freeFall;
    final navigator = widget.navigatorKey.currentState;
    if (!isEvent || navigator == null) return;

    if (ref.read(accountProvider)?.role == AccountRole.luthier) {
      _bannerTimer?.cancel();
      setState(() => _banner = alert);
      _bannerTimer = Timer(_bannerFor, _hideBanner);
      return;
    }

    final isFall = alert.rule == ThresholdRule.freeFall;
    navigator.push(
      ImpactTakeoverScreen.route(
        ImpactTakeoverScreen(
          alert: alert,
          instrumentName: data.instrument.name,
          displayTime: data.displayTime(alert.time),
          onDismiss: navigator.pop,
          onViewInstrument: () {
            navigator.pop();
            widget.onOpenInstrument(alert.instrumentId);
          },
          onDocument: () {
            navigator
              ..pop()
              ..push(
                EventReportFlow.route(
                  instrumentId: alert.instrumentId,
                  eventTitle: eventTitleFor(fall: isFall, measured: alert.measured, headline: alert.title),
                  eventTime: alert.time,
                  eventSeq: alert.seqs.firstOrNull,
                ),
              );
          },
        ),
      ),
    );
  }
}
