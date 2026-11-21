import 'package:bull_ui/bull_ui.dart'
    show BullThemeX, BullButton, BullButtonSize;

import '../../../network_l10n.dart';
import '../../presentation/tor_settings_cubit.dart';
import 'tor_connection_status_card.dart';
import 'tor_port_input_bottom_sheet.dart';

import 'package:bull_ui/bull_ui.dart'
    show
        BullDropdown,
        BullInfoCard,
        BullPickerItem,
        BullSettingsEntryItem,
        BullSnackBar,
        Gap,
        BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_tor/tor.dart';
import 'package:url_launcher/url_launcher.dart';

class TorProxyWidget extends StatelessWidget {
  const TorProxyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final torState = context.watch<TorSettingsCubit>().state;
    final useTorProxy = torState.useTorProxy;
    final torProxyPort = torState.torProxyPort;
    final attemptedPort = torState.externalProxyAttemptPort;
    final externalConnection =
        torState.externalProxyAttempt ??
        (useTorProxy ? torState.connection : null);
    final activeExternalPort = switch (torState.connection) {
      TorReady(:final route) when route.source == TorSource.external =>
        route.endpoint.port,
      _ => null,
    };
    final externalRouteLabel = attemptedPort == null
        ? null
        : useTorProxy && activeExternalPort != null
        ? context.loc.torSettingsProxyAttemptWithActivePort(
            attemptedPort,
            activeExternalPort,
          )
        : context.loc.torSettingsProxyAttemptPort(attemptedPort);
    final activeTransport = switch (torState.embeddedConnection) {
      TorReady(:final route) => route.transport,
      TorConnecting(:final transport) => transport,
      _ => null,
    };

    return Column(
      children: [
        BullSettingsEntryItem(
          icon: Icons.security,
          title: context.loc.torSettingsLocalProxyTitle,
          trailing: Semantics(
            label: context.loc.torSettingsLocalProxyTitle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Switch(
                value: useTorProxy,
                onChanged: (value) {
                  context
                      .read<TorSettingsCubit>()
                      .updateTorSettings(
                        useTorProxy: value,
                        torProxyPort: torProxyPort,
                      )
                      .ignore();
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.loc.torSettingsLocalProxyDescription,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.bull.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        const Gap(8),
        BullButton.secondary(
          label: context.loc.torSettingsLearnAboutOrbot,
          onPressed: () => _learnAboutOrbot(context),
          size: BullButtonSize.small,
          compact: true,
        ),
        Card(
          child: BullSettingsEntryItem(
            icon: Icons.settings_ethernet,
            title: context.loc.torSettingsProxyPort,
            trailing: Text(
              context.loc.torSettingsPortDisplay(torProxyPort),
              style: context.bullType.label.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            onTap: () async {
              final newPort = await TorPortInputBottomSheet.show(
                context,
                torProxyPort,
              );
              if (newPort != null && context.mounted) {
                context
                    .read<TorSettingsCubit>()
                    .updateTorSettings(
                      useTorProxy: useTorProxy,
                      torProxyPort: newPort,
                    )
                    .ignore();
              }
            },
          ),
        ),
        if (externalConnection != null) ...[
          const Gap(16),
          TorConnectionStatusCard(
            connection: externalConnection,
            external: true,
            routeLabel: externalRouteLabel,
            onRetry: () =>
                _retry(context, useTorProxy, torProxyPort, attemptedPort),
          ),
        ],
        if (!useTorProxy) ...[
          const Gap(24),
          BullInfoCard(
            title: context.loc.torSettingsEmbeddedTitle,
            description: context.loc.torSettingsEmbeddedDescription,
            bgColor: context.bull.tertiaryContainer,
            tagColor: context.bull.tertiary,
          ),
          const Gap(16),
          _EmbeddedTransportCard(state: torState),
          const Gap(16),
          TorConnectionStatusCard(
            connection: torState.embeddedConnection,
            routeLabel: activeTransport == null
                ? null
                : context.loc.torSettingsActiveTransport(
                    _transportLabel(context, activeTransport),
                  ),
          ),
        ],
      ],
    );
  }

  void _retry(
    BuildContext context,
    bool useTorProxy,
    int port,
    int? attemptedPort,
  ) {
    final cubit = context.read<TorSettingsCubit>();
    if (attemptedPort != null) {
      cubit
          .updateTorSettings(useTorProxy: true, torProxyPort: attemptedPort)
          .ignore();
    } else if (useTorProxy) {
      cubit.checkConnectionStatus().ignore();
    } else {
      cubit.updateTorSettings(useTorProxy: true, torProxyPort: port).ignore();
    }
  }

  Future<void> _learnAboutOrbot(BuildContext context) async {
    try {
      final launched = await launchUrl(
        Uri.parse('https://orbot.app/'),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        BullSnackBar.show(
          context,
          message: context.loc.torSettingsOrbotLinkFailed,
        );
      }
    } catch (_) {
      if (context.mounted) {
        BullSnackBar.show(
          context,
          message: context.loc.torSettingsOrbotLinkFailed,
        );
      }
    }
  }

  String _transportLabel(BuildContext context, TorTransport transport) =>
      switch (transport) {
        TorTransport.direct => context.loc.torSettingsModeDirect,
        TorTransport.snowflake => context.loc.torSettingsModeSnowflake,
      };
}

class _EmbeddedTransportCard extends StatelessWidget {
  const _EmbeddedTransportCard({required this.state});

  final TorSettingsState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(
            context.loc.torSettingsTransportMode,
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          ),
          const Gap(12),
          Semantics(
            label: context.loc.torSettingsTransportMode,
            child: BullDropdown<TorTransportMode>(
              value: state.transportMode,
              items: [
                for (final mode in TorTransportMode.values)
                  BullPickerItem(value: mode, label: _modeLabel(context, mode)),
              ],
              onChanged: (mode) => context
                  .read<TorSettingsCubit>()
                  .updateTransportMode(mode)
                  .ignore(),
            ),
          ),
          const Gap(8),
          Text(
            _modeDescription(context, state.transportMode),
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    ),
  );

  String _modeLabel(BuildContext context, TorTransportMode mode) =>
      switch (mode) {
        TorTransportMode.automatic => context.loc.torSettingsModeAutomatic,
        TorTransportMode.direct => context.loc.torSettingsModeDirect,
        TorTransportMode.snowflake => context.loc.torSettingsModeSnowflake,
      };

  String _modeDescription(BuildContext context, TorTransportMode mode) =>
      switch (mode) {
        TorTransportMode.automatic =>
          context.loc.torSettingsModeAutomaticDescription,
        TorTransportMode.direct => context.loc.torSettingsModeDirectDescription,
        TorTransportMode.snowflake =>
          context.loc.torSettingsModeSnowflakeDescription,
      };
}
