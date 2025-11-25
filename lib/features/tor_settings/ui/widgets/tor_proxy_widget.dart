import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_connection_status_card.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_port_input_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class TorProxyWidget extends StatelessWidget {
  const TorProxyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final torState = context.watch<TorSettingsCubit>().state;
    final useTorProxy = torState.useTorProxy;
    final torProxyPort = torState.torProxyPort;

    return Column(
      children: [
        SettingsEntryItem(
          icon: Icons.security,
          title: 'Enable Tor Proxy',
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

        if (useTorProxy) ...[
          const Gap(16),
          TorConnectionStatusCard(status: torState.status),
          const Gap(16),
          Card(
            child: SettingsEntryItem(
              icon: Icons.settings_ethernet,
              title: 'Tor Proxy Port',
              trailing: Text(
                'Port: $torProxyPort',
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
          const Gap(16),
          InfoCard(
            title: 'Important Information',
            description:
                '• Tor proxy only applies to Bitcoin (not Liquid)\n'
                '• Default Orbot port is 9050\n'
                '• Ensure Orbot is running before enabling\n'
                '• Connection may be slower through Tor',
            bgColor: context.colour.tertiary.withValues(alpha: 0.1),
            tagColor: context.colour.onTertiary,
          ),
        ],
      ],
    );
  }
}
