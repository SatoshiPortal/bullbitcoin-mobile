import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TorConnectionStatusCard extends StatelessWidget {
  final TorStatus status;
  const TorConnectionStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.loc.torSettingsConnectionStatus, style: context.font.titleMedium),
            const Gap(16),
            Row(
              children: [
                _StatusIndicator(status: status),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(context, status),
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        _getStatusDescription(context, status),
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusTitle(BuildContext context, TorStatus status) {
    switch (status) {
      case TorStatus.online:
        return context.loc.torSettingsStatusConnected;
      case TorStatus.connecting:
        return context.loc.torSettingsStatusConnecting;
      case TorStatus.offline:
        return context.loc.torSettingsStatusDisconnected;
      case TorStatus.unknown:
        return context.loc.torSettingsStatusUnknown;
    }
  }

  String _getStatusDescription(BuildContext context, TorStatus status) {
    switch (status) {
      case TorStatus.online:
        return context.loc.torSettingsDescConnected;
      case TorStatus.connecting:
        return context.loc.torSettingsDescConnecting;
      case TorStatus.offline:
        return context.loc.torSettingsDescDisconnected;
      case TorStatus.unknown:
        return context.loc.torSettingsDescUnknown;
    }
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final TorStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context, status);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
      ),
      child: Center(
        child:
            status == TorStatus.connecting
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
                : Icon(_getStatusIcon(status), color: color, size: 24),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, TorStatus status) {
    switch (status) {
      case TorStatus.online:
        return context.appColors.success;
      case TorStatus.connecting:
        return context.appColors.warning;
      case TorStatus.offline:
        return context.appColors.error;
      case TorStatus.unknown:
        return context.appColors.onSurface.withValues(alpha: 0.5);
    }
  }

  IconData _getStatusIcon(TorStatus status) {
    switch (status) {
      case TorStatus.online:
        return Icons.check_circle;
      case TorStatus.connecting:
        return Icons.hourglass_empty;
      case TorStatus.offline:
        return Icons.cancel;
      case TorStatus.unknown:
        return Icons.help_outline;
    }
  }
}
