import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_bloc.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_event.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_state.dart';
import 'package:bb_mobile/features/bitaxe/ui/bitaxe_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BitaxeConnectionScreen extends StatefulWidget {
  const BitaxeConnectionScreen({super.key});

  @override
  State<BitaxeConnectionScreen> createState() => _BitaxeConnectionScreenState();
}

class _BitaxeConnectionScreenState extends State<BitaxeConnectionScreen> {
  final _ipController = TextEditingController();
  Wallet? _selectedWallet;

  @override
  void initState() {
    super.initState();
    // Select default Bitcoin wallet on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectDefaultBitcoinWallet();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _selectDefaultBitcoinWallet() {
    final wallets = context.read<WalletBloc>().state.wallets;
    final bitcoinWallets = wallets.where((w) => !w.network.isLiquid).toList();

    if (bitcoinWallets.isNotEmpty) {
      setState(() {
        _selectedWallet = bitcoinWallets.firstWhere(
          (w) => w.isDefault,
          orElse: () => bitcoinWallets.first,
        );
      });
    }
  }

  bool _validateIpAddress(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(value)) {
      return false;
    }
    // Validate each octet is 0-255
    final parts = value.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    return true;
  }

  void _handleConnect() {
    final ipAddress = _ipController.text.trim();

    if (!_validateIpAddress(ipAddress)) {
      SnackBarUtils.showSnackBar(context, 'Please enter a valid IP address');
      return;
    }

    if (_selectedWallet == null) {
      SnackBarUtils.showSnackBar(context, 'Please select a Bitcoin wallet');
      return;
    }

    context.read<BitaxeBloc>().add(
      BitaxeEvent.connectToDevice(
        ipAddress: ipAddress,
        wallet: _selectedWallet!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Connect Bitaxe Device',
          onBack: () => context.pop(),
        ),
      ),
      body: BlocConsumer<BitaxeBloc, BitaxeState>(
        listenWhen: (previous, current) {
          // Only react when transitioning TO completed (avoids re-running on rebuilds)
          if (current.currentStep == ConnectionStep.completed) {
            return previous.currentStep != ConnectionStep.completed;
          }
          return true; // Always react to error
        },
        listener: (context, state) {
          if (state.currentStep == ConnectionStep.completed) {
            // 1. Replace Connection with Dashboard
            context.pushReplacementNamed(BitaxeRoute.dashboard.name);
            // 2. Push Success on top so Done/back pops to Dashboard
            if (context.mounted) {
              context.pushNamed(BitaxeRoute.success.name);
            }
          }
          if (state.error != null) {
            SnackBarUtils.showSnackBar(context, state.error!.message);
            context.read<BitaxeBloc>().add(const BitaxeEvent.clearError());
          }
        },
        builder: (context, state) {
          return _ScreenContent(
            ipController: _ipController,
            selectedWallet: _selectedWallet,
            isConnecting: state.isConnecting,
            currentStep: state.currentStep,
            onWalletChanged: (wallet) {
              setState(() {
                _selectedWallet = wallet;
              });
            },
            onConnect: _handleConnect,
          );
        },
      ),
    );
  }
}

class _ScreenContent extends StatelessWidget {
  const _ScreenContent({
    required this.ipController,
    required this.selectedWallet,
    required this.isConnecting,
    required this.currentStep,
    required this.onWalletChanged,
    required this.onConnect,
  });

  final TextEditingController ipController;
  final Wallet? selectedWallet;
  final bool isConnecting;
  final ConnectionStep? currentStep;
  final ValueChanged<Wallet> onWalletChanged;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final bitcoinWallets = context.select(
      (WalletBloc bloc) =>
          bloc.state.wallets.where((w) => !w.network.isLiquid).toList(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Gap(16),
          BBText(
            'Enter the IP address of your Bitaxe device',
            style: context.font.bodyMedium,
            color: context.appColors.text,
          ),
          const Gap(8),
          BBInputText(
            value: ipController.text,
            onChanged: (value) {
              ipController.value = TextEditingValue(
                text: value,
                selection: TextSelection.collapsed(offset: value.length),
              );
            },
            hint: '10.0.2.2',
            disabled: isConnecting,
            onlyNumbers: true,
            maxLines: 1,
            onDone: (_) {
              FocusScope.of(context).unfocus();
            },
          ),
          const Gap(16),
          BBText(
            'Select Bitcoin Wallet',
            style: context.font.headlineSmall,
            color: context.appColors.text,
          ),
          const Gap(8),
          if (bitcoinWallets.isEmpty)
            InfoCard(
              description:
                  'No Bitcoin wallets found. Please create a Bitcoin wallet first.',
              tagColor: context.appColors.warning,
              bgColor: context.appColors.warningContainer,
            )
          else
            ...bitcoinWallets.map((wallet) {
              final isSelected = selectedWallet?.id == wallet.id;
              return Card(
                color: isSelected
                    ? context.appColors.primary.withValues(alpha: 0.1)
                    : context.appColors.cardBackground,
                child: ListTile(
                  title: BBText(
                    wallet.displayLabel(context),
                    style: context.font.bodyLarge,
                    color: context.appColors.text,
                  ),
                  subtitle: BBText(
                    wallet.networkString,
                    style: context.font.bodySmall,
                    color: context.appColors.textMuted,
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: context.appColors.primary,
                        )
                      : null,
                  onTap: isConnecting ? null : () => onWalletChanged(wallet),
                  selected: isSelected,
                ),
              );
            }),
          const Gap(24),
          if (isConnecting) ...[
            const Center(child: CircularProgressIndicator()),
            const Gap(16),
            Center(
              child: BBText(
                _getStepMessage(currentStep),
                style: context.font.bodyMedium,
                color: context.appColors.text,
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            BBButton.big(
              label: 'Connect',
              onPressed: onConnect,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
              disabled: selectedWallet == null || bitcoinWallets.isEmpty,
            ),
          const Gap(16),
        ],
      ),
    );
  }

  String _getStepMessage(ConnectionStep? step) {
    switch (step) {
      case ConnectionStep.testingConnection:
        return 'Testing connection...';
      case ConnectionStep.completed:
        return 'Connection completed!';
      default:
        return 'Connecting...';
    }
  }
}
