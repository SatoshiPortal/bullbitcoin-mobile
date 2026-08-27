import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/embedded_tor_status_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullDialog,
        BullInfoBar,
        BullInfoTone,
        Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmbeddedTorStatusIndicator extends StatelessWidget {
  const EmbeddedTorStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmbeddedTorStatusCubit, EmbeddedTorStatusState>(
      builder: (context, state) {
        if (!state.visible ||
            !state.configurationLoaded ||
            state.externalProxySelected) {
          return const SizedBox.shrink();
        }
        final presentation = _StatusPresentation.from(
          context,
          state.connection,
        );
        void openDetails() => _openDetails(context).ignore();
        return Material(
          color: context.appColors.surface,
          child: InkWell(
            onTap: openDetails,
            child: Semantics(
              button: true,
              excludeSemantics: true,
              label: presentation.label,
              onTap: openDetails,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 36),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: context.appColors.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusGlyph(presentation: presentation),
                    const Gap(8),
                    Flexible(
                      child: Text(
                        presentation.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.font.labelMedium?.copyWith(
                          color: presentation.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Gap(6),
                    Icon(
                      Icons.keyboard_arrow_up,
                      size: 18,
                      color: context.appColors.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDetails(BuildContext context) {
    final cubit = context.read<EmbeddedTorStatusCubit>();
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final details = BlocProvider.value(
      value: cubit,
      child: _EmbeddedTorStatusDetails(
        onOpenSettings: () {
          navigator.pop();
          router.pushNamed(TorSettingsRoute.torSettings.name);
        },
      ),
    );
    if (MediaQuery.sizeOf(context).width >= 600) {
      return BullDialog.show(context: context, builder: (_) => details);
    }
    return BullBottomSheet.show(context: context, child: details);
  }
}

class _EmbeddedTorStatusDetails extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _EmbeddedTorStatusDetails({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmbeddedTorStatusCubit, EmbeddedTorStatusState>(
      builder: (context, state) {
        final connection = state.connection;
        final presentation = _StatusPresentation.from(context, connection);
        final transport = switch (connection) {
          TorConnecting(:final transport) => transport,
          TorReady(:final route) => route.transport,
          _ => null,
        };
        final endpoint = switch (connection) {
          TorReady(:final route) => route.endpoint.authority,
          _ => null,
        };
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.loc.torStatusDetailsTitle,
                        style: context.font.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Gap(20),
                _DetailRow(
                  label: context.loc.torStatusStateLabel,
                  value: presentation.label,
                  valueColor: presentation.color,
                ),
                if (transport != null) ...[
                  const Gap(12),
                  _DetailRow(
                    label: context.loc.torStatusTransportLabel,
                    value: switch (transport) {
                      TorTransport.direct => context.loc.torSettingsModeDirect,
                      TorTransport.snowflake =>
                        context.loc.torSettingsModeSnowflake,
                    },
                  ),
                ],
                if (endpoint != null) ...[
                  const Gap(12),
                  _DetailRow(
                    label: context.loc.torStatusProxyEndpointLabel,
                    value: endpoint,
                  ),
                ],
                const Gap(20),
                Text(
                  context.loc.torStatusProtectedTrafficLabel,
                  style: context.font.titleSmall,
                ),
                const Gap(6),
                Text(
                  context.loc.torSettingsEmbeddedDescription,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const Gap(16),
                Text(presentation.description, style: context.font.bodyMedium),
                const Gap(16),
                BullInfoBar(
                  message: context.loc.torStatusTelemetryUnavailable,
                  tone: BullInfoTone.info,
                  icon: Icons.info_outline,
                ),
                const Gap(24),
                if (connection is TorUnavailable) ...[
                  BullButton.big(
                    label: context.loc.torSettingsRetry,
                    onPressed: () =>
                        context.read<EmbeddedTorStatusCubit>().retry().ignore(),
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    iconData: Icons.refresh,
                    iconFirst: true,
                  ),
                  const Gap(8),
                ],
                BullButton.big(
                  label: context.loc.settingsTorSettingsTitle,
                  onPressed: onOpenSettings,
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.primary,
                  iconData: Icons.settings_outlined,
                  iconFirst: true,
                  outlined: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: context.font.bodyMedium)),
        const Gap(16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.font.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  final _StatusPresentation presentation;

  const _StatusGlyph({required this.presentation});

  @override
  Widget build(BuildContext context) {
    if (presentation.connecting) {
      return SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          value: presentation.progress,
          strokeWidth: 2,
          color: presentation.color,
        ),
      );
    }
    return Icon(presentation.icon, size: 16, color: presentation.color);
  }
}

final class _StatusPresentation {
  final String label;
  final String description;
  final Color color;
  final IconData icon;
  final bool connecting;
  final double? progress;

  const _StatusPresentation({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
    this.connecting = false,
    this.progress,
  });

  factory _StatusPresentation.from(
    BuildContext context,
    TorConnectionState connection,
  ) {
    return switch (connection) {
      TorReady() => _StatusPresentation(
        label: context.loc.torStatusReady,
        description: context.loc.torSettingsDescConnected,
        color: context.appColors.success,
        icon: Icons.shield,
      ),
      TorConnecting() => _connecting(context, connection),
      TorUnavailable() => _StatusPresentation(
        label: context.loc.torStatusUnavailable,
        description: _unavailableDescription(context, connection),
        color: context.appColors.error,
        icon: Icons.error_outline,
      ),
      TorStopped() => _StatusPresentation(
        label: context.loc.torStatusStopped,
        description: context.loc.torStatusNotStartedDescription,
        color: context.appColors.onSurface.withValues(alpha: 0.65),
        icon: Icons.shield_outlined,
      ),
      TorUninitialized() => _StatusPresentation(
        label: context.loc.torStatusNotStarted,
        description: context.loc.torStatusNotStartedDescription,
        color: context.appColors.onSurface.withValues(alpha: 0.65),
        icon: Icons.shield_outlined,
      ),
    };
  }

  static _StatusPresentation _connecting(
    BuildContext context,
    TorConnecting connection,
  ) {
    final progress = connection.progress?.clamp(0.0, 1.0).toDouble();
    return _StatusPresentation(
      label: progress == null
          ? context.loc.torSettingsStatusConnecting
          : context.loc.torStatusConnecting((progress * 100).round()),
      description: _connectingDescription(context, connection),
      color: context.appColors.warning,
      icon: Icons.hourglass_empty,
      connecting: true,
      progress: progress,
    );
  }

  static String _connectingDescription(
    BuildContext context,
    TorConnecting connection,
  ) {
    return switch (connection.diagnostic) {
      TorDiagnostic.offline => context.loc.recoverbullTorOffline,
      TorDiagnostic.clockSkewed => context.loc.recoverbullTorClockSkewed,
      TorDiagnostic.filtering ||
      TorDiagnostic.cantReachTor => context.loc.torSettingsDescCensored,
      TorDiagnostic.cantBootstrap ||
      TorDiagnostic.unknown ||
      null => context.loc.torSettingsDescConnecting,
    };
  }

  static String _unavailableDescription(
    BuildContext context,
    TorUnavailable connection,
  ) {
    final diagnostic = switch (connection.failure) {
      TorBootstrapFailure(:final diagnostic) => diagnostic,
      _ => null,
    };
    return switch (diagnostic) {
      TorDiagnostic.offline => context.loc.recoverbullTorOffline,
      TorDiagnostic.clockSkewed => context.loc.recoverbullTorClockSkewed,
      TorDiagnostic.filtering ||
      TorDiagnostic.cantReachTor => context.loc.torSettingsDescCensored,
      TorDiagnostic.cantBootstrap ||
      TorDiagnostic.unknown ||
      null => context.loc.torSettingsDescDisconnected,
    };
  }
}
