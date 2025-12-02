import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      listenWhen: (previous, current) =>
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
          color: context.appColors.surface,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Column(
        children: [
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: BBText(
                    context.loc.autoswapSettingsTitle,
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
              context.loc.autoswapEnableToggleLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.text,
              ),
            ),
            Switch(
              value: enabled,
              activeThumbColor: context.appColors.onSecondary,
              activeTrackColor: context.appColors.secondary,
              inactiveThumbColor: context.appColors.onSecondary,
              inactiveTrackColor: context.appColors.surface,
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => context.appColors.transparent,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.autoswapMaxBalanceLabel,
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
              color: context.appColors.error,
            ),
          ),
        ],
        const Gap(4),
        BBText(
          context.loc.autoswapMaxBalanceInfoText,
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
            Switch(
              value: alwaysBlock,
              activeThumbColor: context.appColors.onSecondary,
              activeTrackColor: context.appColors.secondary,
              inactiveThumbColor: context.appColors.onSecondary,
              inactiveTrackColor: context.appColors.surface,
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => context.appColors.transparent,
              ),
              onChanged: (value) {
                context
                    .read<AutoSwapSettingsCubit>()
                    .onAlwaysBlockToggleChanged(value);
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
        DropdownButtonFormField<String>(
          initialValue: selectedWalletId,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: enabled && selectedWalletId == null
                    ? context.appColors.error
                    : context.appColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: enabled && selectedWalletId == null
                    ? context.appColors.error
                    : context.appColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: enabled && selectedWalletId == null
                    ? context.appColors.error
                    : context.appColors.primary,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          hint: BBText(
            enabled
                ? context.loc.autoswapRecipientWalletPlaceholderRequired
                : context.loc.autoswapRecipientWalletPlaceholder,
            enabled
                ? context.loc.autoswapRecipientWalletPlaceholderRequired
                : context.loc.autoswapRecipientWalletPlaceholder,
            style: context.font.bodyMedium?.copyWith(
              color: enabled && selectedWalletId == null
                  ? context.appColors.error
                  : context.appColors.textMuted,
            ),
          ),
          items: availableWallets.map((wallet) {
            return DropdownMenuItem<String>(
              value: wallet.id,
              child: BBText(
                wallet.label ?? context.loc.autoswapRecipientWalletDefaultLabel,
                wallet.label ?? context.loc.autoswapRecipientWalletDefaultLabel,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.text,
                ),
              ),
            );
          }).toList(),
          onChanged: (walletId) {
            context.read<AutoSwapSettingsCubit>().onWalletSelected(walletId);
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
      label: context.loc.autoswapSaveButton,
      disabled: isDisabled,
      onPressed: isDisabled
          ? () {}
          : () {
              context.read<AutoSwapSettingsCubit>().updateSettings().catchError(
                (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: BBText(
                          context.loc.autoswapSaveErrorMessage(e.toString()),
                          context.loc.autoswapSaveErrorMessage(e.toString()),
                          style: context.font.bodyMedium,
                        ),
                      ),
                    );
                  }
                },
              );
            },
      bgColor: context.appColors.onSurface,
      textStyle: context.font.headlineLarge,
      textColor: context.appColors.surface,
    );
  }
}
