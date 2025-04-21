import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/bottom_sheet/x.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ElectrumServerSettingsBottomSheet extends StatelessWidget {
  const ElectrumServerSettingsBottomSheet({super.key});

  static Future<void> showBottomSheet(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: BlocProvider(
        create: (_) => locator<ElectrumSettingsBloc>()..add(LoadServers()),
        child: const ElectrumServerSettingsBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const ElectrumServerSettingsContent();
  }
}

class ElectrumServerSettingsContent extends StatefulWidget {
  const ElectrumServerSettingsContent({super.key});

  @override
  State<ElectrumServerSettingsContent> createState() =>
      _ElectrumServerSettingsContentState();
}

class _ElectrumServerSettingsContentState
    extends State<ElectrumServerSettingsContent> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ElectrumSettingsBloc, ElectrumSettingsState>(
      listenWhen: (previous, current) =>
          previous.selectedProvider != current.selectedProvider ||
          previous.electrumServers != current.electrumServers ||
          previous.stagedServers != current.stagedServers,
      listener: (context, state) {
        if (state.status == ElectrumSettingsStatus.loading) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: LinearProgressIndicator(),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      },
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.stagedServers != current.stagedServers ||
          previous.selectedProvider != current.selectedProvider,
      builder: (context, state) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, state),
              if (state.status == ElectrumSettingsStatus.loading) ...[
                const LinearProgressIndicator(),
                const Gap(150),
              ] else if (state.status != ElectrumSettingsStatus.loading) ...[
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildServerTypeSelector(context, state),
                          const Gap(24),
                          if (state.isCustomProvider)
                            _ServerUrls(context: context, state: state),
                          const Gap(16),
                          _ValidateDomainSwitch(context: context, state: state),
                          const Gap(32),
                          _buildSaveButton(context, state),
                          const Gap(24),
                        ],
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ElectrumSettingsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Column(
        children: [
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              BBText(
                state.isSelectedNetworkLiquid
                    ? 'Liquid Network'
                    : 'Bitcoin Network',
                style: context.font.headlineMedium,
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          BBButton.big(
            label:
                'Configure ${state.isSelectedNetworkLiquid ? "Bitcoin" : "Liquid"} Network',
            onPressed: () => context.read<ElectrumSettingsBloc>().add(
                state.isSelectedNetworkLiquid
                    ? ConfigureBitcoinSettings()
                    : ConfigureLiquidSettings()),
            textStyle: context.font.labelMedium,
            bgColor: Colors.transparent,
            textColor: context.colour.primary,
          )
        ],
      ),
    );
  }

  Widget _buildServerTypeSelector(
      BuildContext context, ElectrumSettingsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(state.serverProviderLabels.length, (index) {
          final isSelected = index == state.selectedServerTypeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                final provider = _getProviderFromIndex(index);

                context.read<ElectrumSettingsBloc>().add(
                      ToggleSelectedProvider(provider),
                    );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    state.serverProviderLabels[index],
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  ElectrumServerProvider _getProviderFromIndex(int index) {
    switch (index) {
      case 0:
        return ElectrumServerProvider.blockstream;
      case 2:
        return ElectrumServerProvider.custom;
      case 1:
      default:
        return ElectrumServerProvider.bullBitcoin;
    }
  }

  Widget _buildSaveButton(BuildContext context, ElectrumSettingsState state) {
    final bool hasChanges = state.hasPendingChanges;

    bool disableSave = false;
    if (state.isCustomProvider && hasChanges) {
      final mainnetNetwork = state.isSelectedNetworkLiquid
          ? Network.liquidMainnet
          : Network.bitcoinMainnet;

      final testnetNetwork = state.isSelectedNetworkLiquid
          ? Network.liquidTestnet
          : Network.bitcoinTestnet;

      final mainnetServer = state.getServerForNetworkAndProvider(
        mainnetNetwork,
        state.selectedProvider,
      );

      final testnetServer = state.getServerForNetworkAndProvider(
        testnetNetwork,
        state.selectedProvider,
      );

      disableSave = (mainnetServer?.url ?? '').isEmpty ||
          (testnetServer?.url ?? '').isEmpty;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasChanges && !disableSave
            ? () {
                context
                    .read<ElectrumSettingsBloc>()
                    .add(SaveElectrumServerChanges());
                Navigator.of(context).pop();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(hasChanges
            ? disableSave
                ? 'Fill All URLs'
                : 'Save'
            : 'No Changes'),
      ),
    );
  }
}

class _ValidateDomainSwitch extends StatelessWidget {
  const _ValidateDomainSwitch({
    required this.context,
    required this.state,
  });

  final BuildContext context;
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final validateDomain =
        state.getValidateDomainForProvider(state.selectedProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Validate Domain'),
        Switch(
          value: validateDomain,
          onChanged: (value) {
            context.read<ElectrumSettingsBloc>().add(
                  ToggleValidateDomain(),
                );
          },
        ),
      ],
    );
  }
}

class _ServerUrls extends StatelessWidget {
  const _ServerUrls({
    required this.context,
    required this.state,
  });

  final BuildContext context;
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    // Get current server configurations from the state
    final mainnetNetwork = state.isSelectedNetworkLiquid
        ? Network.liquidMainnet
        : Network.bitcoinMainnet;

    final testnetNetwork = state.isSelectedNetworkLiquid
        ? Network.liquidTestnet
        : Network.bitcoinTestnet;

    // Try to get values from staged changes first, then fallback to original servers
    final mainnetServer = state.getServerForNetworkAndProvider(
      mainnetNetwork,
      state.selectedProvider,
    );

    final testnetServer = state.getServerForNetworkAndProvider(
      testnetNetwork,
      state.selectedProvider,
    );

    final mainnetKey = ValueKey('mainnet-${state.selectedProvider}');
    final testnetKey = ValueKey('testnet-${state.selectedProvider}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mainnet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(8),
        TextFormField(
          key: mainnetKey,
          initialValue: mainnetServer?.url ?? '',
          enabled: state.isCustomProvider,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            hintText: 'ssl://example.com:50002',
          ),
          onChanged: (value) {
            if (state.isCustomProvider) {
              context.read<ElectrumSettingsBloc>().add(
                    UpdateCustomServerMainnet(value),
                  );
            }
          },
        ),
        const Gap(16),
        const Text(
          'Testnet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(8),
        TextFormField(
          key: testnetKey,
          initialValue: testnetServer?.url ?? '',
          enabled: state.isCustomProvider,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            hintText: 'ssl://testnet.example.com:50002',
          ),
          onChanged: (value) {
            if (state.isCustomProvider) {
              context.read<ElectrumSettingsBloc>().add(
                    UpdateCustomServerTestnet(value),
                  );
            }
          },
        ),
      ],
    );
  }
}
