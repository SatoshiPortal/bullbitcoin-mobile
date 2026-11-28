import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:swap_feature/src/autoswap/presentation/autoswap_failure_l10n.dart';
import 'package:swap_feature/src/autoswap/presentation/autoswap_settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullKeyboardActions,
        BullDropdown,
        BullFadingLinearProgress,
        BullInfoCard,
        BullInputText,
        BullPickerItem,
        BullShapesX,
        BullSwitch,
        BullText,
        Gap,
        BullTypographyX;

class AutoSwapSettingsScreen extends StatefulWidget {
  const AutoSwapSettingsScreen({super.key});

  @override
  State<AutoSwapSettingsScreen> createState() => _AutoSwapSettingsScreenState();
}

class _AutoSwapSettingsScreenState extends State<AutoSwapSettingsScreen> {
  final FocusNode _amountNode = FocusNode();
  final FocusNode _triggerNode = FocusNode();
  final FocusNode _feeNode = FocusNode();

  @override
  void dispose() {
    _amountNode.dispose();
    _triggerNode.dispose();
    _feeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.swapCopyForLocale.autoswapSettingsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child:
              BlocSelector<AutoSwapSettingsCubit, AutoSwapSettingsState, bool>(
                selector: (state) => state.loading,
                builder: (context, loading) => BullFadingLinearProgress(
                  height: 3,
                  trigger: loading,
                  backgroundColor: context.appColors.surface,
                  foregroundColor: context.appColors.primary,
                ),
              ),
        ),
      ),
      body: SafeArea(
        child: BullKeyboardActions(
          doneText: context.swapCopyForLocale.doneButton,
          disableScroll: true,
          child: BlocBuilder<AutoSwapSettingsCubit, AutoSwapSettingsState>(
            builder: (context, state) {
              final enabled = state.enabledToggle;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: state.loading
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Gap(16),
                            _EnabledToggle(),
                            if (state.failure case final failure?) ...[
                              const Gap(16),
                              BullInfoCard(
                                description: failure.toTranslated(context),
                                tagColor: context.appColors.error,
                                bgColor: context.appColors.errorContainer,
                              ),
                            ],
                            if (enabled) ...[
                              const Gap(16),
                              _AmountThresholdField(focusNode: _amountNode),
                              const Gap(16),
                              _TriggerBalanceField(focusNode: _triggerNode),
                              const Gap(16),
                              _FeeThresholdField(focusNode: _feeNode),
                              const Gap(16),
                              _WalletSelectionDropdown(),
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
            ExcludeSemantics(
              child: BullText(
                context.swapCopyForLocale.autoswapEnableToggleLabel,
                style: context.bullType.body
                    .copyWith(fontWeight: FontWeight.w500)
                    .copyWith(color: context.appColors.text),
              ),
            ),
            BullSwitch(
              value: enabled,
              semanticLabel:
                  context.swapCopyForLocale.autoswapEnableToggleLabel,
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
  const _AmountThresholdField({required this.focusNode});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final amountThresholdInput = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.amountThresholdInput,
    );
    final bitcoinUnit = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final amountThresholdFailure = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.amountThresholdFailure,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          context.swapCopyForLocale.autoswapTargetBalanceLabel,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.text),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BullInputText(
                value: amountThresholdInput ?? '',
                focusNode: focusNode,
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
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.badge,
                      ),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: BullText(
                      bitcoinUnit == BitcoinUnit.btc ? 'BTC' : 'sats',
                      style: context.bullType.body,
                    ),
                  ),
                ),
                onChanged: enabled
                    ? (value) {
                        context
                            .read<AutoSwapSettingsCubit>()
                            .onAmountThresholdChanged(value);
                        // Auto-save after a short delay to debounce rapid changes
                        // Only save if there's no validation error
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (context.mounted) {
                            final cubit = context.read<AutoSwapSettingsCubit>();
                            if (cubit.state.amountThresholdFailure == null) {
                              cubit.updateSettings();
                            }
                          }
                        });
                      }
                    : (_) {},
              ),
            ),
          ],
        ),
        if (amountThresholdFailure != null) ...[
          const Gap(8),
          BullText(
            amountThresholdFailure.toTranslated(context, unit: bitcoinUnit),
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.error),
          ),
        ],
        const Gap(4),
        BullText(
          context.swapCopyForLocale.autoswapBaseBalanceInfoText,
          style: context.bullType.caption.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TriggerBalanceField extends StatelessWidget {
  const _TriggerBalanceField({required this.focusNode});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final triggerBalanceSatsInput = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.triggerBalanceSatsInput,
    );
    final bitcoinUnit = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final triggerBalanceFailure = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.triggerBalanceFailure,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          context.swapCopyForLocale.autoswapMaximumBalanceLabel,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.text),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BullInputText(
                value: triggerBalanceSatsInput ?? '',
                focusNode: focusNode,
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
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.badge,
                      ),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: BullText(
                      bitcoinUnit == BitcoinUnit.btc ? 'BTC' : 'sats',
                      style: context.bullType.body,
                    ),
                  ),
                ),
                onChanged: enabled
                    ? (value) {
                        context
                            .read<AutoSwapSettingsCubit>()
                            .onTriggerBalanceChanged(value);
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
        if (triggerBalanceFailure != null) ...[
          const Gap(8),
          BullText(
            triggerBalanceFailure.toTranslated(context, unit: bitcoinUnit),
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.error),
          ),
        ],
        const Gap(4),
        BullText(
          context.swapCopyForLocale.autoswapTriggerAtBalanceInfoText,
          style: context.bullType.caption.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _FeeThresholdField extends StatelessWidget {
  const _FeeThresholdField({required this.focusNode});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final feeThresholdInput = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.feeThresholdInput,
    );
    final feeThresholdFailure = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.feeThresholdFailure,
    );
    final enabled = context.select(
      (AutoSwapSettingsCubit cubit) => cubit.state.enabledToggle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          context.swapCopyForLocale.autoswapMaxFeeLabel,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.text),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: BullInputText(
                value: feeThresholdInput ?? '',
                focusNode: focusNode,
                onlyNumbers: true,
                rightIcon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.badge,
                    ),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: BullText('%', style: context.bullType.body),
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
        if (feeThresholdFailure != null) ...[
          const Gap(8),
          BullText(
            feeThresholdFailure.toTranslated(context),
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.error),
          ),
        ],
        const Gap(4),
        BullText(
          context.swapCopyForLocale.autoswapMaxFeeInfoText,
          style: context.bullType.caption.copyWith(
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
            BullText(
              context.swapCopyForLocale.autoswapRecipientWalletLabel,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: context.appColors.text),
            ),
            if (enabled) ...[
              const Gap(4),
              BullText(
                context.swapCopyForLocale.autoswapRecipientWalletRequired,
                style: context.bullType.body
                    .copyWith(fontWeight: FontWeight.w500)
                    .copyWith(color: context.appColors.error),
              ),
            ],
          ],
        ),
        const Gap(8),
        BullDropdown<SwapWallet>(
          items: [
            for (final wallet in availableWallets)
              BullPickerItem(
                value: wallet,
                label: wallet.swapWalletLabel(context),
                leading: Image.asset(
                  wallet.isLiquid
                      ? 'assets/logos/liquid.png'
                      : 'assets/logos/bitcoin.png',
                  width: 20,
                  height: 20,
                ),
              ),
          ],
          value: selectedWallet,
          validator: enabled
              ? (value) {
                  if (value == null) {
                    return context
                        .swapCopyForLocale
                        .autoswapRecipientWalletPlaceholderRequired;
                  }
                  return null;
                }
              : null,
          hint: enabled
              ? context
                    .swapCopyForLocale
                    .autoswapRecipientWalletPlaceholderRequired
              : context.swapCopyForLocale.autoswapRecipientWalletPlaceholder,
          onChanged: (wallet) {
            context.read<AutoSwapSettingsCubit>().onWalletSelected(wallet.id);
            // Auto-save when wallet selection changes
            context.read<AutoSwapSettingsCubit>().updateSettings();
          },
        ),
        const Gap(4),
        BullText(
          context.swapCopyForLocale.autoswapRecipientWalletInfoText,
          style: context.bullType.caption.copyWith(
            color: enabled && selectedWalletId == null
                ? context.appColors.error
                : context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}
