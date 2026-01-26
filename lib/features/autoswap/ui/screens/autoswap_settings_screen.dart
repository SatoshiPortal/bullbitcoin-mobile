import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

class AutoSwapSettingsScreen extends StatelessWidget {
  const AutoSwapSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AutoSwapSettingsCubit>(
      create: (_) => sl<AutoSwapSettingsCubit>()..loadSettings(),
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.autoswapSettingsTitle)),
        body: SafeArea(
          child: BlocBuilder<AutoSwapSettingsCubit, AutoSwapSettingsState>(
            builder: (context, state) {
              final enabled = state.enabledToggle;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: state.loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Gap(16),
                            _EnabledToggle(),
                            if (enabled) ...[
                              const Gap(16),
                              _AmountThresholdField(),
                              const Gap(16),
                              _TriggerBalanceField(),
                              const Gap(16),
                              _FeeThresholdField(),
                              const Gap(16),
                              _WalletSelectionDropdown(),
                              const Gap(16),
                              _AlwaysBlockToggle(),
                            ],
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EnabledToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BBText(
              context.loc.autoswapEnableToggleLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.text,
              ),
            ),
            BBSwitch(
              value: enabled,
              onChanged: (value) {
                context.read<AutoSwapSettingsCubit>().onEnabledToggleChanged(
                  value,
                );
                // Auto-save when toggle changes
                if (value) {
                  context.read<AutoSwapSettingsCubit>().updateSettings();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _AmountThresholdField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final amountThresholdInput = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.amountThresholdInput,
    );
    final bitcoinUnit = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final amountThresholdError = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.amountThresholdError,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Target Instant Wallet Balance',
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.text,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BBInputText(
                value: amountThresholdInput ?? '',
                onlyNumbers: true,
                rightIcon: GestureDetector(
                  onTap: () {
                    context.read<AutoSwapSettingsCubit>().toggleBitcoinUnit();
                    // Auto-save when unit changes
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        context.read<AutoSwapSettingsCubit>().updateSettings();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: BBText(
                      bitcoinUnit == BitcoinUnit.btc ? 'BTC' : 'sats',
                      style: context.font.bodyMedium,
                    ),
                  ),
                ),
                onChanged: enabled
                    ? (value) {
                        context
                            .read<AutoSwapSettingsCubit>()
                            .onAmountThresholdChanged(value)
                            .then((_) {
                              // Auto-save after a short delay to debounce rapid changes
                              // Only save if there's no validation error
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (context.mounted) {
                                    final state = context
                                        .read<AutoSwapSettingsCubit>()
                                        .state;
                                    if (state.amountThresholdError == null) {
                                      context
                                          .read<AutoSwapSettingsCubit>()
                                          .updateSettings();
                                    }
                                  }
                                },
                              );
                            });
                      }
                    : (_) {},
              ),
            ),
          ],
        ),
        if (amountThresholdError != null) ...[
          const Gap(8),
          BBText(
            amountThresholdError.displayMessage(context.loc),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
        const Gap(4),
        BBText(
          context.loc.autoswapBaseBalanceInfoText,
          style: context.font.labelSmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TriggerBalanceField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final triggerBalanceSatsInput = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.triggerBalanceSatsInput,
    );
    final bitcoinUnit = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final error = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.error,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Maximum Instant Wallet Balance',
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.text,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BBInputText(
                value: triggerBalanceSatsInput ?? '',
                onlyNumbers: true,
                rightIcon: GestureDetector(
                  onTap: () {
                    context.read<AutoSwapSettingsCubit>().toggleBitcoinUnit();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        context.read<AutoSwapSettingsCubit>().updateSettings();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: BBText(
                      bitcoinUnit == BitcoinUnit.btc ? 'BTC' : 'sats',
                      style: context.font.bodyMedium,
                    ),
                  ),
                ),
                onChanged: enabled
                    ? (value) {
                        context
                            .read<AutoSwapSettingsCubit>()
                            .onTriggerBalanceChanged(value)
                            .then((_) {
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (context.mounted) {
                                    context
                                        .read<AutoSwapSettingsCubit>()
                                        .updateSettings();
                                  }
                                },
                              );
                            });
                      }
                    : (_) {},
              ),
            ),
          ],
        ),
        if (error == 'autoswapTriggerBalanceError') ...[
          const Gap(8),
          BBText(
            context.loc.autoswapTriggerBalanceError,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
        const Gap(4),
        BBText(
          context.loc.autoswapTriggerAtBalanceInfoText,
          style: context.font.labelSmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _FeeThresholdField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final feeThresholdInput = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.feeThresholdInput,
    );
    final feeThresholdError = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.feeThresholdError,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.autoswapMaxFeeLabel,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.text,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BBInputText(
                value: feeThresholdInput ?? '',
                onlyNumbers: true,
                rightIcon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: BBText('%', style: context.font.bodyMedium),
                ),
                onChanged: enabled
                    ? (value) {
                        context
                            .read<AutoSwapSettingsCubit>()
                            .onFeeThresholdChanged(value);
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (context.mounted) {
                            context
                                .read<AutoSwapSettingsCubit>()
                                .updateSettings();
                          }
                        });
                      }
                    : (_) {},
              ),
            ),
          ],
        ),
        if (feeThresholdError != null) ...[
          const Gap(8),
          BBText(
            feeThresholdError.displayMessage(context.loc),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
        const Gap(4),
        BBText(
          context.loc.autoswapMaxFeeInfoText,
          style: context.font.labelSmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _AlwaysBlockToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final alwaysBlock = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.alwaysBlock,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BBText(
              context.loc.autoswapAlwaysBlockLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.text,
              ),
            ),
            BBSwitch(
              value: alwaysBlock,
              onChanged: (value) {
                context
                    .read<AutoSwapSettingsCubit>()
                    .onAlwaysBlockToggleChanged(value);
                // Auto-save when toggle changes
                context.read<AutoSwapSettingsCubit>().updateSettings();
              },
            ),
          ],
        ),
        const Gap(4),
        BBText(
          alwaysBlock
              ? context.loc.autoswapAlwaysBlockInfoEnabled
              : context.loc.autoswapAlwaysBlockInfoDisabled,
          style: context.font.labelSmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _WalletSelectionDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final availableWallets = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.availableBitcoinWallets,
    );
    final selectedWalletId = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.selectedBitcoinWalletId,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    final selectedWallet = availableWallets
        .where((wallet) => wallet.id == selectedWalletId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BBText(
              context.loc.autoswapRecipientWalletLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.text,
              ),
            ),
            if (enabled) ...[
              const Gap(4),
              BBText(
                context.loc.autoswapRecipientWalletRequired,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ],
          ],
        ),
        const Gap(8),
        BBDropdown<Wallet>(
          items: availableWallets
              .map(
                (wallet) => DropdownMenuItem(
                  value: wallet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Row(
                      children: [
                        Image.asset(
                          wallet.isLiquid
                              ? 'assets/logos/liquid.png'
                              : 'assets/logos/bitcoin.png',
                          width: 20,
                          height: 20,
                        ),
                        const Gap(8),
                        Text(wallet.displayLabel(context)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          value: selectedWallet,
          validator: enabled
              ? (value) {
                  if (value == null) {
                    return context
                        .loc
                        .autoswapRecipientWalletPlaceholderRequired;
                  }
                  return null;
                }
              : null,
          hint: BBText(
            enabled
                ? context.loc.autoswapRecipientWalletPlaceholderRequired
                : context.loc.autoswapRecipientWalletPlaceholder,
            style: context.font.bodyMedium?.copyWith(
              color: enabled && selectedWalletId == null
                  ? context.appColors.error
                  : context.appColors.textMuted,
            ),
          ),
          onChanged: (wallet) {
            context.read<AutoSwapSettingsCubit>().onWalletSelected(wallet?.id);
            // Auto-save when wallet selection changes
            context.read<AutoSwapSettingsCubit>().updateSettings();
          },
        ),
        const Gap(4),
        BBText(
          context.loc.autoswapRecipientWalletInfoText,
          style: context.font.labelSmall?.copyWith(
            color: enabled && selectedWalletId == null
                ? context.appColors.error
                : context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}
