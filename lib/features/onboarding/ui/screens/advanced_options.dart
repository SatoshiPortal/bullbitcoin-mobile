import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_port_input_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AdvancedOptions extends StatefulWidget {
  const AdvancedOptions({super.key});

  @override
  State<AdvancedOptions> createState() => _AdvancedOptionsState();
}

class _AdvancedOptionsState extends State<AdvancedOptions> {
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
      appBar: AppBar(title: const Text('Advanced Options')),
      body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                'Configure advanced settings before creating or recovering your wallet',
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.colour.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                            const Gap(8),
                            SettingsEntryItem(
                              icon: Icons.security,
                              title: 'Enable Tor Proxy',
                              trailing: Switch(
                                value: useTorProxy,
                                onChanged: (value) {
                                  context.read<TorSettingsCubit>().updateTorSettings(
                                    useTorProxy: value,
                                    torProxyPort: torProxyPort,
                                  ).ignore();
                                },
                              ),
                            ),
                            if (useTorProxy)
                              SettingsEntryItem(
                                icon: Icons.settings_ethernet,
                                title: 'Tor Proxy Port',
                                trailing: Text(
                                  'Port: $torProxyPort',
                                  style: context.font.bodyMedium,
                                ),
                                onTap: () async {
                                  final newPort =
                                      await TorPortInputBottomSheet.show(
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
                            SettingsEntryItem(
                              icon: Icons.settings_input_component,
                              title: 'Custom Electrum Server',
                              onTap: () {
                                context.pushNamed(
                                  ElectrumSettingsRoute.electrumSettings.name,
                                );
                              },
                            ),
                            SettingsEntryItem(
                              icon: Icons.cloud_sync,
                              title: 'Custom Recoverbull Server',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const SettingsPage(),
                                  ),
                                );
                              },
                            ),
                            const Gap(24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'You can change these settings later in Bitcoin Settings',
                                style: context.font.bodySmall?.copyWith(
                                  color: context.colour.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: BBButton.big(
                        label: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                        bgColor: context.colour.primary,
                        textColor: context.colour.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
