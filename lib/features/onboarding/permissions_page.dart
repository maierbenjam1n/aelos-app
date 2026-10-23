import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/rise_in.dart';
import '../../domain/models/condition_status.dart';
import 'permission_gateway.dart';

/// The last onboarding page: why Bluetooth and notifications, with a row each.
/// Never blocks: the shared Continue button works whatever the answers.
class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  late final PermissionGateway _gateway = ref.read(permissionGatewayProvider);
  PermissionState _bluetooth = PermissionState.notRequested;
  PermissionState _notifications = PermissionState.notRequested;
  bool _askingBluetooth = false;
  bool _askingNotifications = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bluetooth = await _gateway.bluetoothState();
    final notifications = await _gateway.notificationsState();
    if (!mounted) return;
    setState(() {
      _bluetooth = bluetooth;
      _notifications = notifications;
    });
  }

  Future<void> _requestBluetooth() async {
    setState(() => _askingBluetooth = true);
    final ok = await _gateway.requestBluetooth();
    if (!mounted) return;
    setState(() {
      _askingBluetooth = false;
      _bluetooth = ok ? PermissionState.granted : PermissionState.denied;
    });
  }

  Future<void> _requestNotifications() async {
    setState(() => _askingNotifications = true);
    final ok = await _gateway.requestNotifications();
    if (!mounted) return;
    setState(() {
      _askingNotifications = false;
      _notifications = ok ? PermissionState.granted : PermissionState.denied;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final allGranted =
        _bluetooth == PermissionState.granted &&
        _notifications == PermissionState.granted;

    final children = <Widget>[
      Stack(
        children: [
          Positioned(
            right: Space.s,
            top: 0,
            child: FHole(
              height: 136,
              color: colors.accent.withValues(alpha: 0.28),
            ),
          ),
          // At least as tall as the watermark; grows with large text.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 136,
              minWidth: double.infinity,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Eyebrow('Before we begin', color: colors.accentInk),
                const SizedBox(height: Space.m),
                Text('Two small\npermissions', style: text.displayMedium),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.l),
      Text(
        'No account, nothing else. Aelos only needs to reach the sensor in the '
        'case, and to reach you.',
        style: text.bodyLarge!.copyWith(color: colors.textMuted),
      ),
      const SizedBox(height: Space.xxl),
      const Hairline(),
      _PermissionRow(
        key: const ValueKey('permission-bluetooth'),
        icon: Icons.bluetooth_rounded,
        title: 'Bluetooth',
        reason: 'To find the sensor in the case and read its measurements.',
        state: _bluetooth,
        asking: _askingBluetooth,
        onAllow: _requestBluetooth,
      ),
      const Hairline(),
      _PermissionRow(
        key: const ValueKey('permission-notifications'),
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        reason: 'So a knock or a fall reaches you, even with the app closed.',
        state: _notifications,
        asking: _askingNotifications,
        onAllow: _requestNotifications,
      ),
      const Hairline(),
      const SizedBox(height: Space.l),
      AnimatedOpacity(
        opacity: allGranted ? 0 : 1,
        duration: Motion.medium,
        child: Text(
          'You can change these later in your phone’s settings.',
          style: AelosText.of(context).note.copyWith(fontSize: 16),
        ),
      ),
    ];

    final animate = widget.active && !MediaQuery.disableAnimationsOf(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.l,
              Space.page,
              Space.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                for (final (i, child) in children.indexed)
                  animate
                      ? child.riseIn(i ~/ 2)
                      : Opacity(opacity: widget.active ? 1 : 0, child: child),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.reason,
    required this.state,
    required this.asking,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String reason;
  final PermissionState state;
  final bool asking;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final granted = state == PermissionState.granted;
    final (stateLabel, stateColor) = switch (state) {
      PermissionState.granted => ('Allowed', colors.calmInk),
      PermissionState.denied => ('Not allowed', colors.attentionInk),
      PermissionState.notRequested => ('To request', colors.textFaint),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.l + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 19, color: colors.accent),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: Eyebrow(
                    stateLabel,
                    key: ValueKey(state),
                    color: stateColor,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(title, style: text.titleMedium),
                const SizedBox(height: Space.xs - 2),
                Text(reason, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          SizedBox(
            width: 92,
            height: 40,
            child: AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.exit,
              child: granted
                  ? Align(
                      key: const ValueKey('granted'),
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.statusTint(ConditionStatus.calm),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: colors.calm,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      key: const ValueKey('allow'),
                      onPressed: asking ? null : onAllow,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(92, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.m,
                        ),
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: colors.accent.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                        foregroundColor: colors.accentInk,
                      ),
                      child: asking
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.4,
                                color: colors.accent,
                              ),
                            )
                          : Text(
                              state == PermissionState.denied
                                  ? 'Retry'
                                  : 'Allow',
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
