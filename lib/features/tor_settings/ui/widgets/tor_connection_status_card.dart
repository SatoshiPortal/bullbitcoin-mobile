import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
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
            Text('Connection Status', style: context.font.titleMedium),
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
                        _getStatusTitle(status),
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        _getStatusDescription(status),
                        style: context.font.bodySmall?.copyWith(
                          color: context.colour.onSurface.withValues(
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

  String _getStatusTitle(TorStatus status) {
    switch (status) {
      case TorStatus.online:
        return 'Connected';
      case TorStatus.connecting:
        return 'Connecting...';
      case TorStatus.offline:
        return 'Disconnected';
      case TorStatus.unknown:
        return 'Status Unknown';
    }
  }

  String _getStatusDescription(TorStatus status) {
    switch (status) {
      case TorStatus.online:
        return 'Tor proxy is running and ready';
      case TorStatus.connecting:
        return 'Establishing Tor connection';
      case TorStatus.offline:
        return 'Tor proxy is not running';
      case TorStatus.unknown:
        return 'Unable to determine Tor status. Ensure Orbot is installed and running.';
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
        return Colors.green;
      case TorStatus.connecting:
        return Colors.orange;
      case TorStatus.offline:
        return Colors.red;
      case TorStatus.unknown:
        return context.colour.onSurface.withValues(alpha: 0.5);
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
