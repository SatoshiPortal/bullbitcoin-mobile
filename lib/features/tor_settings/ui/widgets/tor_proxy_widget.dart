import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_connection_status_card.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_port_input_bottom_sheet.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_tor/tor.dart';

class TorProxyWidget extends StatelessWidget {
  const TorProxyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final torState = context.watch<TorSettingsCubit>().state;
    final useTorProxy = torState.useTorProxy;
    final torProxyPort = torState.torProxyPort;
    final showExternalStatus =
        useTorProxy || torState.externalProxyAttempt != null;
    final activeTransport = switch (torState.embeddedConnection) {
      TorReady(:final route) => route.transport,
      TorConnecting(:final transport) => transport,
      _ => null,
    };

    return Column(
      children: [
        InfoCard(
          title: context.loc.torSettingsEmbeddedTitle,
          description: context.loc.torSettingsEmbeddedDescription,
          bgColor: context.appColors.tertiaryContainer,
          tagColor: context.appColors.tertiary,
        ),
        const Gap(16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Text(
                  context.loc.torSettingsTransportMode,
                  style: context.font.titleMedium,
                ),
                const Gap(12),
                BBDropdown<TorTransportMode>(
                  value: torState.transportMode,
                  items: TorTransportMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(_modeLabel(context, mode)),
                        ),
                      )
                      .toList(),
                  onChanged: (mode) {
                    if (mode == null) return;
                    context
                        .read<TorSettingsCubit>()
                        .updateTransportMode(mode)
                        .ignore();
                  },
                ),
                const Gap(8),
                Text(
                  _modeDescription(context, torState.transportMode),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!useTorProxy) ...[
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
        const Gap(24),
        SettingsEntryItem(
          icon: Icons.security,
          title: context.loc.torSettingsExternalProxyTitle,
          trailing: Switch(
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.loc.torSettingsExternalProxyDescription,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),

        if (showExternalStatus) ...[
          const Gap(16),
          if (useTorProxy)
            TorConnectionStatusCard(
              connection: torState.connection,
              readyTitle: context.loc.torSettingsExternalProxyReachable,
              readyDescription:
                  context.loc.torSettingsExternalProxyReachableDescription,
            ),
          if (torState.externalProxyAttempt != null) ...[
            const Gap(16),
            TorConnectionStatusCard(
              connection: torState.externalProxyAttempt!,
              readyTitle: context.loc.torSettingsExternalProxyReachable,
              readyDescription:
                  context.loc.torSettingsExternalProxyReachableDescription,
            ),
          ],
          const Gap(16),
          Card(
            child: SettingsEntryItem(
              icon: Icons.settings_ethernet,
              title: context.loc.torSettingsProxyPort,
              trailing: Text(
                context.loc.torSettingsPortDisplay(torProxyPort),
                style: context.font.bodySmall,
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
        ],
      ],
    );
  }

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

  String _transportLabel(BuildContext context, TorTransport transport) =>
      switch (transport) {
        TorTransport.direct => context.loc.torSettingsModeDirect,
        TorTransport.snowflake => context.loc.torSettingsModeSnowflake,
      };
}
