import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
          title: context.loc.torSettingsEnableProxy,
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
          const Gap(16),
          InfoCard(
            title: context.loc.torSettingsInfoTitle,
            description: context.loc.torSettingsInfoDescription,
            bgColor: context.appColors.tertiaryContainer,
            tagColor: context.appColors.tertiary,
          ),
        ],
      ],
    );
  }
}
