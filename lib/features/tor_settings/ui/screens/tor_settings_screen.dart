import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
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
    context.read<ElectrumSettingsBloc>().add(
      const ElectrumSettingsLoaded(isLiquid: false),
    );
    context.read<TorSettingsCubit>().init();
  }

  @override
  Widget build(BuildContext context) {
    final advancedOptions = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.advancedOptions,
    );
    final isLoading = context.select(
      (ElectrumSettingsBloc bloc) => bloc.state.isLoading,
    );

    final useTorProxy = advancedOptions?.useTorProxy ?? false;
    final torProxyPort = advancedOptions?.torProxyPort ?? 9050;
    final stopGap = advancedOptions?.stopGap ?? 20;
    final timeout = advancedOptions?.timeout ?? 5;
    final retry = advancedOptions?.retry ?? 5;
    final validateDomain = advancedOptions?.validateDomain ?? true;
    final socks5 = advancedOptions?.socks5;

    return Scaffold(
      appBar: AppBar(title: const Text('Tor Settings')),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
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
                              context.read<ElectrumSettingsBloc>().add(
                                ElectrumAdvancedOptionsSaved(
                                  stopGap: stopGap.toString(),
                                  timeout: timeout.toString(),
                                  retry: retry.toString(),
                                  validateDomain: validateDomain,
                                  socks5: socks5,
                                  useTorProxy: value,
                                  torProxyPort: torProxyPort,
                                ),
                              );
                              context
                                  .read<TorSettingsCubit>()
                                  .refreshSettings();
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
                      if (newPort != null) {
                        if (!context.mounted) return;
                        context.read<ElectrumSettingsBloc>().add(
                          ElectrumAdvancedOptionsSaved(
                            stopGap: stopGap.toString(),
                            timeout: timeout.toString(),
                            retry: retry.toString(),
                            validateDomain: validateDomain,
                            socks5: socks5,
                            useTorProxy: useTorProxy,
                            torProxyPort: newPort,
                          ),
                        );
                        await context
                            .read<TorSettingsCubit>()
                            .refreshSettings();
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
