import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:tor/tor.dart';

class TorConnectionStatusCard extends StatelessWidget {
  final TorConnectionState connection;
  final String? routeLabel;

  const TorConnectionStatusCard({
    super.key,
    required this.connection,
    this.routeLabel,
  });

  /// Whether the blockage looks like the network filtering Tor traffic.
  ///
  /// Advisory: the underlying diagnostic is best-effort upstream, so this
  /// offers an explanation, it does not assert that the user is censored.
  bool get _looksCensored => switch (connection) {
    TorConnecting(:final diagnostic) => diagnostic?.suggestsCensorship ?? false,
    _ => false,
  };

  _VisualStatus get _status => switch (connection) {
    TorReady() => _VisualStatus.online,
    TorConnecting() => _VisualStatus.connecting,
    TorUnavailable() => _VisualStatus.offline,
    TorUninitialized() || TorStopped() => _VisualStatus.unknown,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              context.loc.torSettingsConnectionStatus,
              style: context.font.titleMedium,
            ),
            const Gap(16),
            Row(
              children: [
                _StatusIndicator(status: _status),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        _getStatusTitle(context),
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: .w600,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        _getStatusDescription(context),
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      if (routeLabel != null) ...[
                        const Gap(4),
                        Text(routeLabel!, style: context.font.bodySmall),
                      ],
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

  String _getStatusTitle(BuildContext context) {
    if (_looksCensored) return context.loc.torSettingsStatusCensored;
    final progress = switch (connection) {
      TorConnecting(:final progress) => progress,
      _ => null,
    };
    if (progress != null && progress > 0) {
      return context.loc.torSettingsBootstrapProgress((progress * 100).round());
    }
    switch (_status) {
      case _VisualStatus.online:
        return context.loc.torSettingsStatusConnected;
      case _VisualStatus.connecting:
        return context.loc.torSettingsStatusConnecting;
      case _VisualStatus.offline:
        return context.loc.torSettingsStatusDisconnected;
      case _VisualStatus.unknown:
        return context.loc.torSettingsStatusUnknown;
    }
  }

  String _getStatusDescription(BuildContext context) {
    if (_looksCensored) return context.loc.torSettingsDescCensored;
    switch (_status) {
      case _VisualStatus.online:
        return context.loc.torSettingsDescConnected;
      case _VisualStatus.connecting:
        return context.loc.torSettingsDescConnecting;
      case _VisualStatus.offline:
        return context.loc.torSettingsDescDisconnected;
      case _VisualStatus.unknown:
        return context.loc.torSettingsDescUnknown;
    }
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final _VisualStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context, status);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: .circle,
        color: color.withValues(alpha: 0.1),
      ),
      child: Center(
        child: status == _VisualStatus.connecting
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

  Color _getStatusColor(BuildContext context, _VisualStatus status) {
    switch (status) {
      case _VisualStatus.online:
        return context.appColors.success;
      case _VisualStatus.connecting:
        return context.appColors.warning;
      case _VisualStatus.offline:
        return context.appColors.error;
      case _VisualStatus.unknown:
        return context.appColors.onSurface.withValues(alpha: 0.5);
    }
  }

  IconData _getStatusIcon(_VisualStatus status) {
    switch (status) {
      case _VisualStatus.online:
        return Icons.check_circle;
      case _VisualStatus.connecting:
        return Icons.hourglass_empty;
      case _VisualStatus.offline:
        return Icons.cancel;
      case _VisualStatus.unknown:
        return Icons.help_outline;
    }
  }
}

enum _VisualStatus { online, connecting, offline, unknown }
