import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PermissionState { notRequested, granted, denied }

/// The two runtime permissions onboarding asks for, behind an interface so
/// screens and tests never touch the platform directly.
abstract interface class PermissionGateway {
  Future<PermissionState> bluetoothState();
  Future<PermissionState> notificationsState();

  /// Shows the system prompt if needed; true when the permission is granted.
  Future<bool> requestBluetooth();
  Future<bool> requestNotifications();
}

/// In-memory gateway for tests, the style guide and the mock demo. Requests
/// resolve after [delay] (standing in for the system dialog) with [grant].
class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway({
    this.bluetooth = PermissionState.notRequested,
    this.notifications = PermissionState.notRequested,
    this.grant = true,
    this.delay = const Duration(milliseconds: 450),
  });

  PermissionState bluetooth;
  PermissionState notifications;
  final bool grant;
  final Duration delay;

  @override
  Future<PermissionState> bluetoothState() async => bluetooth;

  @override
  Future<PermissionState> notificationsState() async => notifications;

  @override
  Future<bool> requestBluetooth() async {
    await Future<void>.delayed(delay);
    bluetooth = grant ? PermissionState.granted : PermissionState.denied;
    return grant;
  }

  @override
  Future<bool> requestNotifications() async {
    await Future<void>.delayed(delay);
    notifications = grant ? PermissionState.granted : PermissionState.denied;
    return grant;
  }
}

/// Override with the platform gateway once it exists (see README).
final permissionGatewayProvider = Provider<PermissionGateway>(
  (ref) => FakePermissionGateway(),
);
