import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/condition_status.dart';
import '../../domain/thresholds/alert.dart';
import '../../domain/thresholds/replay_summary.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(FlutterLocalNotificationsPlugin()),
);

/// System notifications for alerts. IDs come from instrument + rule, so a
/// repeat replaces the earlier notification instead of stacking.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _actNow = AndroidNotificationDetails(
    'aelos_act_now',
    'Act now',
    channelDescription: 'Impacts, falls and critical climate',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
  );
  static const _attention = AndroidNotificationDetails(
    'aelos_attention',
    'Needs attention',
    channelDescription: 'Climate outside the range for your instrument',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } on Object catch (e) {
      // No plugin in widget tests and on unsupported platforms; alerts still
      // show in the app.
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> showAlert(Alert alert, {required String instrumentName}) => _show(
        id: alert.notificationId,
        title: '${alert.title} · $instrumentName',
        body: '${alert.why} ${alert.whatToDo}',
        actNow: alert.severity == ConditionStatus.actNow,
      );

  Future<void> showSummary(ReplaySummary summary, {required String instrumentName}) => _show(
        id: summary.notificationId,
        title: instrumentName,
        body: summary.headline,
        actNow: summary.severity == ConditionStatus.actNow,
      );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required bool actNow,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: actNow ? _actNow : _attention),
      );
    } on PlatformException catch (e) {
      debugPrint('Notification failed: $e');
    }
  }
}
