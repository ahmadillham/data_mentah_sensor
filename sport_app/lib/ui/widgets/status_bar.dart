import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/ble_provider.dart';

/// Compact status bar with dot indicators for BLE and GPS status.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream for reactive updates, but also check the service
    // directly for initial state (broadcast stream misses pre-subscription events)
    final streamConnected = ref.watch(connectionStateProvider).valueOrNull;
    final isConnected = streamConnected ?? ref.watch(bleServiceProvider).isConnected;

    final gpsData = ref.watch(gpsDataProvider).valueOrNull;
    final hasFix = gpsData?.fixValid ?? false;
    final sats = gpsData?.satellites ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // BLE status
          _DotIndicator(
            isActive: isConnected,
            activeColor: AppTheme.success,
            inactiveColor: AppTheme.danger,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'BLE' : 'BLE Off',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isConnected ? AppTheme.textSecondary : AppTheme.danger,
                  fontSize: 10,
                ),
          ),
          const Spacer(),
          // GPS status
          _DotIndicator(
            isActive: hasFix,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            hasFix ? '$sats Sats' : 'No Fix',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hasFix ? AppTheme.textSecondary : AppTheme.textMuted,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  const _DotIndicator({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
