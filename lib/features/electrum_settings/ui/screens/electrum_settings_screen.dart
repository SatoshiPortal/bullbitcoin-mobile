import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/ui/widgets/add_custom_server_dialog.dart';
import 'package:bb_mobile/features/electrum_settings/ui/widgets/draggable_server_list.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ElectrumSettingsScreen extends StatelessWidget {
  const ElectrumSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ElectrumSettingsBloc>(
      create: (_) => locator<ElectrumSettingsBloc>()..add(LoadServers()),
      child: const ElectrumSettingsContent(),
    );
  }
}

class ElectrumSettingsContent extends StatefulWidget {
  const ElectrumSettingsContent({super.key});

  @override
  State<ElectrumSettingsContent> createState() =>
      _ElectrumSettingsContentState();
}

class _ElectrumSettingsContentState extends State<ElectrumSettingsContent> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ElectrumSettingsBloc, ElectrumSettingsState>(
      listenWhen:
          (previous, current) =>
              previous.selectedProvider != current.selectedProvider ||
              previous.electrumServers != current.electrumServers ||
              previous.stagedServers != current.stagedServers ||
              previous.status != current.status,
      listener: (context, state) {},
      buildWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.stagedServers != current.stagedServers ||
              previous.selectedProvider != current.selectedProvider ||
              previous.statusError != current.statusError,
      builder: (context, state) {
        final currentNetwork = state.selectedNetwork;

        final defaultServers =
            state.electrumServers
                .where(
                  (s) =>
                      s.electrumServerProvider
                          is! CustomElectrumServerProvider &&
                      s.network == currentNetwork,
                )
                .toList();

        final customServers =
            state.electrumServers
                .where(
                  (s) =>
                      s.electrumServerProvider
                          is CustomElectrumServerProvider &&
                      s.network == currentNetwork,
                )
                .toList();

        return Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(
              title: 'Electrum Server Settings',
              onBack: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.status == ElectrumSettingsStatus.loading)
                  FadingLinearProgress(
                    height: 3,
                    trigger: state.status == ElectrumSettingsStatus.loading,
                    backgroundColor: context.colour.surface,
                    foregroundColor: context.colour.primary,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BBSegmentFull(
                    items: const {'Bitcoin', 'Liquid'},
                    initialValue:
                        state.isSelectedNetworkLiquid ? 'Liquid' : 'Bitcoin',
                    onSelected: (value) {
                      context.read<ElectrumSettingsBloc>().add(
                        value == 'Liquid'
                            ? const ConfigureLiquidSettings()
                            : const ConfigureBitcoinSettings(),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BBText(
                        'Show Testnet Servers',
                        style: context.font.bodyMedium,
                      ),
                      Switch(
                        value:
                            state.selectedNetwork == Network.bitcoinTestnet ||
                            state.selectedNetwork == Network.liquidTestnet,
                        onChanged: (_) {
                          context.read<ElectrumSettingsBloc>().add(
                            const ToggleTestnet(),
                          );
                        },
                        activeColor: context.colour.onSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: DraggableServerList(
                      defaultServers: defaultServers,
                      customServers: customServers,
                      onCustomServerReordered: (oldIndex, newIndex) {
                        context.read<ElectrumSettingsBloc>().add(
                          ReorderServers(
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                            network: state.selectedNetwork,
                          ),
                        );
                      },
                      onAddCustomServer: () {
                        AddCustomServerDialog.show(context);
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _ValidateDomainSwitch(context: context, state: state),
                      const SizedBox(height: 16),
                      _AdvancedOptions(state: state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ValidateDomainSwitch extends StatelessWidget {
  const _ValidateDomainSwitch({required this.context, required this.state});
  final BuildContext context;
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final currentServer = state.currentServer;
    final validateDomain = currentServer?.validateDomain ?? true;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Validate Domain',
            style: context.font.bodyLarge?.copyWith(
              color: context.colour.secondary,
            ),
          ),
          Switch(
            value: validateDomain,
            activeColor: context.colour.onSecondary,
            activeTrackColor: context.colour.secondary,
            inactiveThumbColor: context.colour.onSecondary,
            inactiveTrackColor: context.colour.surface,
            trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) => Colors.transparent,
            ),
            onChanged: (value) {
              context.read<ElectrumSettingsBloc>().add(
                const ToggleValidateDomain(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  const _AdvancedOptions({required this.state});
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _showAdvancedOptionsDialog(context, state),
      child: const Text('Advanced Options'),
    );
  }

  void _showAdvancedOptionsDialog(
    BuildContext context,
    ElectrumSettingsState state,
  ) {
    final currentServer = state.currentServer;
    final timeoutController = TextEditingController(
      text: currentServer?.timeout.toString() ?? '',
    );
    final retryController = TextEditingController(
      text: currentServer?.retry.toString() ?? '',
    );
    final stopGapController = TextEditingController(
      text: currentServer?.stopGap.toString() ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Advanced Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: timeoutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Timeout (seconds)',
                  ),
                ),
                TextField(
                  controller: retryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Retry Count'),
                ),
                TextField(
                  controller: stopGapController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stop Gap'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final timeout = int.tryParse(timeoutController.text);
                  final retry = int.tryParse(retryController.text);
                  final stopGap = int.tryParse(stopGapController.text);

                  context.read<ElectrumSettingsBloc>().add(
                    UpdateElectrumAdvancedOptions(
                      timeout: timeout,
                      retry: retry,
                      stopGap: stopGap,
                    ),
                  );

                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
