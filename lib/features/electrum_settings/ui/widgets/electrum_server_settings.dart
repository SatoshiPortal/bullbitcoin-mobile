import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/ui/widgets/privacy_notice.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ElectrumServerSettingsBottomSheet extends StatelessWidget {
  const ElectrumServerSettingsBottomSheet({super.key});

  static Future<void> showBottomSheet(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: BlocProvider<ElectrumSettingsBloc>(
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
  Widget build(BuildContext context) {
    return BlocConsumer<ElectrumSettingsBloc, ElectrumSettingsState>(
      listenWhen:
          (previous, current) =>
              previous.selectedProvider != current.selectedProvider ||
              previous.electrumServers != current.electrumServers ||
              previous.stagedServers != current.stagedServers ||
              previous.status != current.status,
      listener: (context, state) {
        if (state.saveSuccessful) {
          log.fine('Settings saved successfully');
        }
      },
      buildWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.stagedServers != current.stagedServers ||
              previous.selectedProvider != current.selectedProvider ||
              previous.statusError != current.statusError,
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
              _Header(state: state),
              if (state.status == ElectrumSettingsStatus.loading)
                FadingLinearProgress(
                  height: 3,
                  trigger: state.status == ElectrumSettingsStatus.loading,
                  backgroundColor: context.colour.surface,
                  foregroundColor: context.colour.primary,
                ),

              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.status !=
                              ElectrumSettingsStatus.loading) ...[
                            const Gap(16),
                            ServerTypeSelector(state: state),
                            const Gap(24),
                            if (state.isCustomServerSelected)
                              _ServerUrls(state: state),
                            const Gap(16),
                            _ValidateDomainSwitch(
                              context: context,
                              state: state,
                            ),
                            const Gap(16),
                            _AdvancedOptions(state: state),
                            const Gap(32),
                            _SaveButton(state: state),
                          ],
                          const Gap(30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.state});
  final ElectrumSettingsState state;

  void _handleSave(BuildContext context) {
    // Get the bloc before any async operations
    final bloc = context.read<ElectrumSettingsBloc>();

    if (state.isCustomServerSelected) {
      // Show privacy notice and handle everything within the dialog callback
      PrivacyNoticeBottomSheet.show(context).then((result) {
        if (result == true) {
          bloc.add(const SaveElectrumServerChanges());
          if (context.mounted) {
            context.pop();
          }
        }
      });
    } else {
      // For default servers, no privacy notice needed
      bloc.add(const SaveElectrumServerChanges());
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasChanges = state.hasPendingChanges;

    bool disableSave = state.status == ElectrumSettingsStatus.loading;

    if (state.isCustomServerSelected && hasChanges) {
      final mainnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidMainnet
              : Network.bitcoinMainnet;

      final testnetNetwork =
          state.isSelectedNetworkLiquid
              ? Network.liquidTestnet
              : Network.bitcoinTestnet;

      // Get both from effective servers to ensure we're seeing the latest state
      const customProvider = ElectrumServerProvider.customProvider();
      final mainnetServer = state.getServerForNetworkAndProvider(
        mainnetNetwork,
        customProvider,
      );

      final testnetServer = state.getServerForNetworkAndProvider(
        testnetNetwork,
        customProvider,
      );

      // Fixed validation logic - ensure URLs are truly empty, not just containing blockstream.info
      final mainnetUrlEmpty =
          mainnetServer == null || mainnetServer.url.trim().isEmpty;
      final testnetUrlEmpty =
          testnetServer == null || testnetServer.url.trim().isEmpty;

      disableSave = disableSave || mainnetUrlEmpty || testnetUrlEmpty;
    }

    return BBButton.big(
      label: 'Save',
      onPressed:
          hasChanges && !disableSave ? () => _handleSave(context) : () {},
      bgColor:
          (hasChanges && !disableSave)
              ? context.colour.secondary
              : context.colour.surfaceContainer,
      textStyle: context.font.headlineLarge,
      textColor: context.colour.onSecondary,
    );
  }
}

class _ServerField extends StatelessWidget {
  const _ServerField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

  final String label;
  final String? initialValue;
  final Function(String) onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(label, style: context.font.labelSmall),
        const Gap(8),
        TextFormField(
          initialValue: initialValue ?? '',
          enabled: enabled,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            errorText: errorText,
            errorStyle: context.font.labelSmall?.copyWith(
              color: context.colour.error,
            ),
          ),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _ServerUrls extends StatelessWidget {
  const _ServerUrls({required this.state});
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final mainnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;
    final testnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidTestnet
            : Network.bitcoinTestnet;

    final mainnetServer = state.getServerForNetworkAndProvider(
      mainnetNetwork,
      const ElectrumServerProvider.customProvider(),
    );

    final testnetServer = state.getServerForNetworkAndProvider(
      testnetNetwork,
      const ElectrumServerProvider.customProvider(),
    );

    final String mainnetUrl = mainnetServer?.url ?? '';
    final String testnetUrl = testnetServer?.url ?? '';

    // Parse error messages
    String? mainnetError;
    String? testnetError;

    if (state.status == ElectrumSettingsStatus.error) {
      final errorMsg = state.statusError;
      if (errorMsg.contains('Mainnet:')) {
        mainnetError = errorMsg;
      } else if (errorMsg.contains('Testnet:')) {
        testnetError = errorMsg;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ServerField(
          label: 'Mainnet',
          initialValue: mainnetUrl,
          enabled: state.isCustomServerSelected,
          errorText: mainnetError,
          onChanged: (value) {
            final bloc = context.read<ElectrumSettingsBloc>();
            bloc.add(UpdateCustomServerMainnet(customServer: value));
          },
        ),
        const Gap(16),
        _ServerField(
          label: 'Testnet',
          initialValue: testnetUrl,
          enabled: state.isCustomServerSelected,
          errorText: testnetError,
          onChanged: (value) {
            final bloc = context.read<ElectrumSettingsBloc>();
            bloc.add(UpdateCustomServerTestnet(customServer: value));
          },
        ),
      ],
    );
  }
}

class ServerTypeSelector extends StatelessWidget {
  const ServerTypeSelector({required this.state});
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final selectedOption = state.isCustomServerSelected ? 'Custom' : 'Default';

    return BBSegmentFull(
      items: const {'Default', 'Custom'},
      initialValue: selectedOption,
      onSelected: (selected) {
        final isCustom = selected == 'Custom';
        context.read<ElectrumSettingsBloc>().add(
          ToggleCustomServer(isCustomSelected: isCustom),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final networkText =
        state.isSelectedNetworkLiquid ? 'Liquid Network' : 'Bitcoin Network';
    final mainnetNetwork =
        state.isSelectedNetworkLiquid
            ? Network.liquidMainnet
            : Network.bitcoinMainnet;

    Widget? statusIndicator;
    if (state.status == ElectrumSettingsStatus.loading) {
      // Show loading indicator when checking server status
      statusIndicator = null;
    } else {
      final selectedServer = state.getServerForNetworkAndProvider(
        mainnetNetwork,
        state.selectedProvider,
      );

      if (selectedServer != null) {
        final isConnected =
            selectedServer.status == ElectrumServerStatus.online;
        final dotColor =
            isConnected ? context.colour.inverseSurface : context.colour.error;
        statusIndicator = Container(
          margin: const EdgeInsets.only(left: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Column(
        children: [
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              Row(
                children: [
                  BBText(networkText, style: context.font.headlineMedium),
                  if (statusIndicator != null) statusIndicator,
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          BBButton.big(
            label:
                'Toggle ${state.isSelectedNetworkLiquid ? "Bitcoin" : "Liquid"} Network',
            onPressed:
                () => context.read<ElectrumSettingsBloc>().add(
                  state.isSelectedNetworkLiquid
                      ? const ConfigureBitcoinSettings()
                      : const ConfigureLiquidSettings(),
                ),
            textStyle: context.font.labelMedium?.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            bgColor: Colors.transparent,
            textColor: context.colour.primary,
          ),
        ],
      ),
    );
  }
}

class _ValidateDomainSwitch extends StatelessWidget {
  const _ValidateDomainSwitch({required this.context, required this.state});
  final BuildContext context;
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final validateDomain = state.getValidateDomainForProvider(
      state.selectedProvider,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BBText(
          'Validate Domain',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
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
          onChanged: (_) {
            context.read<ElectrumSettingsBloc>().add(
              const ToggleValidateDomain(),
            );
          },
        ),
      ],
    );
  }
}

class _AdvancedField extends StatelessWidget {
  const _AdvancedField({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(label, style: context.font.bodyMedium),
        const Gap(8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: placeholder,
            hintStyle: TextStyle(color: context.colour.surfaceContainer),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  const _AdvancedOptions({required this.state});
  final ElectrumSettingsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ElectrumSettingsBloc>();

    return BBButton.big(
      label: 'Advanced Options >>',
      onPressed: () => _showAdvancedOptionsBottomSheet(context, bloc),
      bgColor: Colors.transparent,
      textStyle: context.font.bodySmall,
      textColor: context.colour.inversePrimary,
    );
  }

  void _showAdvancedOptionsBottomSheet(
    BuildContext context,
    ElectrumSettingsBloc bloc,
  ) {
    final server = state.currentServer;

    final stopGapController = TextEditingController(
      text: (server != null) ? server.stopGap.toString() : '',
    );

    final retryController = TextEditingController(
      text: (server != null) ? server.retry.toString() : '',
    );

    final timeoutController = TextEditingController(
      text: (server != null) ? server.timeout.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Gap(24),
                    BBText(
                      'Electrum Options',
                      style: context.font.headlineMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Gap(24),
                _AdvancedField(
                  label: 'Stop gap',
                  controller: stopGapController,
                  placeholder: '20',
                ),
                const Gap(16),
                _AdvancedField(
                  label: 'Retry (seconds)',
                  controller: retryController,
                  placeholder: '5',
                ),
                const Gap(16),
                _AdvancedField(
                  label: 'Timeout (seconds)',
                  controller: timeoutController,
                  placeholder: '5',
                ),
                const Gap(24),
                BBButton.big(
                  label: 'Save',
                  onPressed: () {
                    final stopGapStr = stopGapController.text.trim();
                    final retryStr = retryController.text.trim();
                    final timeoutStr = timeoutController.text.trim();

                    final stopGap =
                        stopGapStr.isNotEmpty ? int.tryParse(stopGapStr) : null;
                    final retry =
                        retryStr.isNotEmpty ? int.tryParse(retryStr) : null;
                    final timeout =
                        timeoutStr.isNotEmpty ? int.tryParse(timeoutStr) : null;

                    if (stopGap != null || retry != null || timeout != null) {
                      bloc.add(
                        UpdateElectrumAdvancedOptions(
                          stopGap: stopGap,
                          retry: retry,
                          timeout: timeout,
                        ),
                      );
                    }

                    Navigator.pop(context);
                  },
                  bgColor: context.colour.secondary,
                  textStyle: context.font.headlineLarge,
                  textColor: context.colour.onSecondary,
                ),
              ],
            ),
          ),
    );
  }
}
