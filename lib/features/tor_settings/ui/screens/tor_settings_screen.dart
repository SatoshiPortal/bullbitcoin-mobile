import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_connection_status_card.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_port_input_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class TorSettingsScreen extends StatefulWidget {
  const TorSettingsScreen({super.key});

  @override
  State<TorSettingsScreen> createState() => _TorSettingsScreenState();
}

class _TorSettingsScreenState extends State<TorSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TorSettingsCubit>().init();
  }

  @override
  Widget build(BuildContext context) {
    final torState = context.watch<TorSettingsCubit>().state;
    final useTorProxy = torState.useTorProxy;
    final torProxyPort = torState.torProxyPort;

    return Scaffold(
      appBar: AppBar(title: const Text('Tor Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useTorProxy) const TorConnectionStatusCard(),
              if (useTorProxy) const Gap(24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tor Proxy', style: context.font.titleMedium),
                      const Gap(8),
                      Text(
                        'Route Electrum server connections through Tor (Orbot) for enhanced privacy',
                        style: context.font.bodySmall?.copyWith(
                          color: context.colour.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const Gap(16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enable Tor Proxy',
                            style: context.font.bodyLarge,
                          ),
                          Switch(
                            value: useTorProxy,
                            onChanged: (value) {
                              context.read<TorSettingsCubit>().updateTorSettings(
                                useTorProxy: value,
                                torProxyPort: torProxyPort,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(16),

              if (useTorProxy)
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
                        context.read<TorSettingsCubit>().updateTorSettings(
                          useTorProxy: useTorProxy,
                          torProxyPort: newPort,
                        ).ignore();
                      }
                    },
                  ),
                ),
              if (useTorProxy) const Gap(24),

              Card(
                color: context.colour.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.colour.onPrimaryContainer,
                            size: 20,
                          ),
                          const Gap(8),
                          Text(
                            'Important Information',
                            style: context.font.titleSmall?.copyWith(
                              color: context.colour.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      Text(
                        '• Tor proxy only applies to Bitcoin (not Liquid)\n'
                        '• Default Orbot port is 9050\n'
                        '• Ensure Orbot is running before enabling\n'
                        '• Connection may be slower through Tor',
                        style: context.font.bodySmall?.copyWith(
                          color: context.colour.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
