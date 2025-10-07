import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class AutoSwapSettingsBottomSheet extends StatelessWidget {
  const AutoSwapSettingsBottomSheet({super.key});

  static Future<void> showBottomSheet(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: BlocProvider<AutoSwapSettingsCubit>(
        create: (_) => locator<AutoSwapSettingsCubit>()..loadSettings(),
        child: const AutoSwapSettingsBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const AutoSwapSettingsContent();
  }
}

class AutoSwapSettingsContent extends StatefulWidget {
  const AutoSwapSettingsContent({super.key});

  @override
  State<AutoSwapSettingsContent> createState() =>
      _AutoSwapSettingsContentState();
}

class _AutoSwapSettingsContentState extends State<AutoSwapSettingsContent> {
  @override
  Widget build(BuildContext context) {
    final loading = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.loading,
    );

    return BlocListener<AutoSwapSettingsCubit, AutoSwapSettingsState>(
      listenWhen:
          (previous, current) =>
              previous.successfullySaved != current.successfullySaved &&
              current.successfullySaved,
      listener: (context, state) {
        Navigator.of(context).pop();
      },
      child: Container(
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
            _Header(),

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
                        if (!loading) ...[
                          const Gap(16),
                          _EnabledToggle(),
                          const Gap(16),
                          _AmountThresholdField(),
                          const Gap(16),
                          _FeeThresholdField(),
                          const Gap(16),
                          _WalletSelectionDropdown(),
                          const Gap(16),
                          _AlwaysBlockToggle(),
                          const Gap(32),
                          _SaveButton(),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final showInfo = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.showInfo,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Column(
        children: [
          const Gap(20),
          Row(
            children: [
              GestureDetector(
                onTap:
                    () =>
                        context
                            .read<AutoSwapSettingsCubit>()
                            .onInfoToggleChanged(),
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color:
                      showInfo
                          ? context.colour.secondary
                          : context.colour.surfaceContainer,
                ),
              ),
              Expanded(
                child: Center(
                  child: BBText(
                    'Auto Transfer Settings',
                    style: context.font.headlineMedium,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close),
              ),
            ],
          ),
        ],
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
              'Enable Auto Transfer',
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.onSurface,
              ),
            ),
            Switch(
              value: enabled,
              activeColor: context.colour.onSecondary,
              activeTrackColor: context.colour.secondary,
              inactiveThumbColor: context.colour.onSecondary,
              inactiveTrackColor: context.colour.surface,
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => Colors.transparent,
              ),
              onChanged: (value) {
                context.read<AutoSwapSettingsCubit>().onEnabledToggleChanged(
                  value,
                );
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
    final showInfo = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.showInfo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Max Instant Wallet Balance',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.onSurface,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BBInputText(
                value: amountThresholdInput ?? '',
                onlyNumbers: true,
                rightIcon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colour.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colour.outline),
                  ),
                  child: BBText(
                    bitcoinUnit == BitcoinUnit.btc ? 'BTC' : 'sats',
                    style: context.font.bodyMedium,
                  ),
                ),
                onChanged: (value) {
                  context
                      .read<AutoSwapSettingsCubit>()
                      .onAmountThresholdChanged(value);
                },
              ),
            ),
          ],
        ),
        if (amountThresholdError != null) ...[
          const Gap(8),
          BBText(
            amountThresholdError.displayMessage(),
            style: context.font.bodySmall?.copyWith(
              color: context.colour.error,
            ),
          ),
        ],
        if (showInfo) ...[
          const Gap(4),
          BBText(
            'When wallet balance exceeds double this amount, auto-transfer will trigger to reduce balance to this level',
            style: context.font.labelSmall?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
        ],
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
    final showInfo = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.showInfo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Max Transfer Fee',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.onSurface,
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
                    color: context.colour.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colour.outline),
                  ),
                  child: BBText('%', style: context.font.bodyMedium),
                ),
                onChanged: (value) {
                  context.read<AutoSwapSettingsCubit>().onFeeThresholdChanged(
                    value,
                  );
                },
              ),
            ),
          ],
        ),
        if (feeThresholdError != null) ...[
          const Gap(8),
          BBText(
            feeThresholdError.displayMessage(),
            style: context.font.bodySmall?.copyWith(
              color: context.colour.error,
            ),
          ),
        ],
        if (showInfo) ...[
          const Gap(4),
          BBText(
            'If total transfer fee is above the set percentage, the auto-transfer will be blocked',
            style: context.font.labelSmall?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
        ],
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
    final showInfo = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.showInfo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BBText(
              'Always Block High Fees',
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.onSurface,
              ),
            ),
            Switch(
              value: alwaysBlock,
              activeColor: context.colour.onSecondary,
              activeTrackColor: context.colour.secondary,
              inactiveThumbColor: context.colour.onSecondary,
              inactiveTrackColor: context.colour.surface,
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => Colors.transparent,
              ),
              onChanged: (value) {
                context
                    .read<AutoSwapSettingsCubit>()
                    .onAlwaysBlockToggleChanged(value);
              },
            ),
          ],
        ),
        if (showInfo) ...[
          const Gap(4),
          BBText(
            alwaysBlock
                ? 'When enabled, auto-transfers with fees above the set limit will always be blocked'
                : 'When disabled, you will be given the option to allow an auto-transfer that is blocked due to high fees',
            style: context.font.labelSmall?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
        ],
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
    final showInfo = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.showInfo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BBText(
              'Recipient Bitcoin Wallet',
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.onSurface,
              ),
            ),
            if (enabled) ...[
              const Gap(4),
              BBText(
                '*',
                style: context.font.bodyLarge?.copyWith(
                  color: context.colour.error,
                ),
              ),
            ],
          ],
        ),
        const Gap(8),
        DropdownButtonFormField<String>(
          value: selectedWalletId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color:
                    enabled && selectedWalletId == null
                        ? context.colour.error
                        : context.colour.surfaceContainer,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color:
                    enabled && selectedWalletId == null
                        ? context.colour.error
                        : context.colour.surfaceContainer,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color:
                    enabled && selectedWalletId == null
                        ? context.colour.error
                        : context.colour.primary,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: BBText(
            enabled ? 'Select a Bitcoin wallet *' : 'Select a Bitcoin wallet',
            style: context.font.bodyMedium?.copyWith(
              color:
                  enabled && selectedWalletId == null
                      ? context.colour.error
                      : context.colour.surfaceContainer,
            ),
          ),
          items:
              availableWallets.map((wallet) {
                return DropdownMenuItem<String>(
                  value: wallet.id,
                  child: BBText(
                    wallet.label ?? 'Bitcoin Wallet',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.onSurface,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (walletId) {
            context.read<AutoSwapSettingsCubit>().onWalletSelected(walletId);
          },
        ),
        if (showInfo) ...[
          const Gap(4),
          BBText(
            'Choose which Bitcoin wallet will receive the transferred funds (required)',
            style: context.font.labelSmall?.copyWith(
              color:
                  enabled && selectedWalletId == null
                      ? context.colour.error
                      : context.colour.surfaceContainer,
            ),
          ),
        ],
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final saving = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.saving,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );
    final selectedWalletId = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.selectedBitcoinWalletId,
    );

    final isDisabled =
        saving || !enabled || (enabled && selectedWalletId == null);

    return BBButton.big(
      label: 'Save',
      disabled: isDisabled,
      onPressed:
          isDisabled
              ? () {}
              : () {
                context
                    .read<AutoSwapSettingsCubit>()
                    .updateSettings()
                    .catchError((e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: BBText(
                              'Failed to save settings: $e',
                              style: context.font.bodyMedium,
                            ),
                          ),
                        );
                      }
                    });
              },
      bgColor: context.colour.secondary,
      textStyle: context.font.headlineLarge,
      textColor: context.colour.onSecondary,
    );
  }
}
