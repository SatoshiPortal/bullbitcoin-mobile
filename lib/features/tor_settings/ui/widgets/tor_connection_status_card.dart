import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:bull_tor/tor.dart';

class TorConnectionStatusCard extends StatelessWidget {
  final TorConnectionState connection;
  final String? routeLabel;
  final bool external;
  final VoidCallback? onRetry;

  /// Offered when embedded Tor cannot bootstrap; null hides the action, e.g.
  /// when Snowflake is already the transport.
  final VoidCallback? onUseSnowflake;

  const TorConnectionStatusCard({
    super.key,
    required this.connection,
    this.routeLabel,
    this.external = false,
    this.onRetry,
    this.onUseSnowflake,
  });

  /// Whether the blockage looks like the network filtering Tor traffic.
  ///
  /// Advisory: the underlying diagnostic is best-effort upstream, so this
  /// offers an explanation, it does not assert that the user is censored.
  bool get _looksCensored => switch (connection) {
    TorConnecting(:final diagnostic) => diagnostic?.suggestsCensorship ?? false,
    // A bootstrap that gave up still carries why it gave up, and that is the
    // moment this matters most: in `direct` mode nothing falls back to
    // Snowflake, so without this the user is told to "try again" with no hint
    // that changing transport is the actual fix.
    TorUnavailable(failure: TorBootstrapFailure(:final diagnostic)) =>
      diagnostic?.suggestsCensorship ?? false,
    _ => false,
  };

  /// The latest diagnosis of a direct bootstrap, while trying or after it
  /// gave up.
  TorDiagnostic? get _diagnostic => switch (connection) {
    TorConnecting(:final diagnostic) => diagnostic,
    TorUnavailable(failure: TorBootstrapFailure(:final diagnostic)) =>
      diagnostic,
    _ => null,
  };

  /// Arti's own words about the bootstrap, untranslated, shown beneath the
  /// localized explanation so support has something precise to go on.
  TorBootstrapDetail? get _detail => switch (connection) {
    TorConnecting(:final detail) => detail,
    TorUnavailable(failure: TorBootstrapFailure(:final detail)) => detail,
    _ => null,
  };

  _VisualStatus get _status => switch (connection) {
    TorReady() => _VisualStatus.online,
    TorConnecting() => _VisualStatus.connecting,
    TorUnavailable() => _VisualStatus.offline,
    TorUninitialized() || TorStopped() => _VisualStatus.unknown,
  };

  bool get _showRetry => external
      ? onRetry != null &&
            (_status == _VisualStatus.offline ||
                _status == _VisualStatus.unknown)
      : onRetry != null && _offersRecovery;

  bool get _showUseSnowflake =>
      !external && onUseSnowflake != null && _offersRecovery;

  /// A bootstrap stuck on its directory, or failed on a clock the user has
  /// since fixed, is worth an explicit restart; arti keeps retrying on its
  /// own in every other case.
  bool get _offersRecovery => switch (_diagnostic) {
    TorDiagnostic.cantBootstrap => true,
    TorDiagnostic.clockSkewed => connection is TorUnavailable,
    _ => false,
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
              external
                  ? context.loc.torSettingsLocalProxyStatus
                  : context.loc.torSettingsConnectionStatus,
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
                      for (final line in [
                        ?_detail?.stage,
                        ?_detail?.blockage,
                      ]) ...[
                        const Gap(4),
                        Text(
                          line,
                          style: context.font.labelSmall?.copyWith(
                            color: context.appColors.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                      if (routeLabel != null) ...[
                        const Gap(4),
                        Text(routeLabel!, style: context.font.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_showRetry || _showUseSnowflake) ...[
              const Gap(12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_showUseSnowflake)
                      TextButton(
                        onPressed: onUseSnowflake,
                        child: Text(context.loc.torSettingsUseSnowflake),
                      ),
                    if (_showRetry)
                      TextButton(
                        onPressed: onRetry,
                        child: Text(context.loc.torSettingsRetry),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusTitle(BuildContext context) {
    if (external) {
      return switch (_status) {
        _VisualStatus.online => context.loc.torSettingsExternalProxyReachable,
        _VisualStatus.connecting =>
          context.loc.torSettingsExternalProxyChecking,
        _VisualStatus.offline =>
          context.loc.torSettingsExternalProxyUnavailable,
        _VisualStatus.unknown => context.loc.torSettingsExternalProxyNotChecked,
      };
    }
    if (_looksCensored) return context.loc.torSettingsStatusCensored;
    switch (_diagnostic) {
      case TorDiagnostic.offline:
        return context.loc.torSettingsStatusOffline;
      case TorDiagnostic.clockSkewed:
        return context.loc.torSettingsStatusClockSkewed;
      case TorDiagnostic.cantBootstrap:
        return context.loc.torSettingsStatusCantBootstrap;
      case TorDiagnostic.filtering ||
          TorDiagnostic.cantReachTor ||
          TorDiagnostic.unknown ||
          null:
        break;
    }
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
    if (external) {
      return switch (_status) {
        _VisualStatus.online =>
          context.loc.torSettingsExternalProxyReachableDescription,
        _VisualStatus.connecting =>
          context.loc.torSettingsExternalProxyCheckingDescription,
        _VisualStatus.offline =>
          context.loc.torSettingsExternalProxyUnavailableDescription,
        _VisualStatus.unknown =>
          context.loc.torSettingsExternalProxyNotCheckedDescription,
      };
    }
    if (_looksCensored) return context.loc.torSettingsDescCensored;
    switch (_diagnostic) {
      case TorDiagnostic.offline:
        return context.loc.torSettingsDescOffline;
      case TorDiagnostic.clockSkewed:
        return context.loc.torSettingsDescClockSkewed;
      case TorDiagnostic.cantBootstrap:
        return context.loc.torSettingsDescCantBootstrap;
      case TorDiagnostic.filtering ||
          TorDiagnostic.cantReachTor ||
          TorDiagnostic.unknown ||
          null:
        break;
    }
    switch (_status) {
      case _VisualStatus.online:
        return context.loc.torSettingsDescConnected;
      case _VisualStatus.connecting:
        return context.loc.torSettingsDescConnecting;
      case _VisualStatus.offline:
        return context.loc.torSettingsDescDisconnected;
      case _VisualStatus.unknown:
        return context.loc.torSettingsEmbeddedStatusUnknownDescription;
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
