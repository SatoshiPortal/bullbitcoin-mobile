import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/fees/fee_options_modal.dart';
import 'package:bb_mobile/core/widgets/fees/fee_selection_label.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SellSendPaymentScreen extends StatelessWidget {
  const SellSendPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isConfirmingPayment = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState &&
          (bloc.state as SellPaymentState).isConfirmingPayment,
    );
    final wallet = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).selectedWallet
          : null,
    );
    final bitcoinUnit = context.select((SellBloc bloc) {
      final state = bloc.state;
      if (state is SellPaymentState) return state.bitcoinUnit;
      return BitcoinUnit.btc;
    });
    final order = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).sellOrder
          : null,
    );
    final isPayjoinEnabled = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).isPayjoinEnabled
          : false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          Assets.logos.bbLogoSmall.path,
          height: 32,
          width: 32,
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isConfirmingPayment,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            const Gap(24.0),
            Text(
              context.loc.sellConfirmPayment,
              style: context.font.headlineMedium?.copyWith(
                color: context.appColors.secondary,
              ),
            ),
            const Gap(4.0),
            Row(
              mainAxisAlignment: .center,
              children: [
                Text(
                  context.loc.sellPriceWillRefreshIn,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.outline,
                  ),
                ),
                if (order?.confirmationDeadline case final deadline?)
                  Countdown(
                    until: deadline,
                    onTimeout: () {
                      context.read<SellBloc>().add(
                        const SellEvent.orderRefreshTimePassed(),
                      );
                    },
                  ),
              ],
            ),

            const Gap(8.0),
            _DetailRow(
              title: context.loc.sellOrderNumber,
              value: order?.orderNumber.toString(),
              copyValue: order?.orderNumber.toString(),
            ),
            // The payin goes to this address: showing it is the user's only
            // way to notice if it ever changed under them.
            _DetailRow(
              title: context.loc.sellDepositAddress,
              value: order?.toAddress,
              copyValue: order?.toAddress,
            ),
            _DetailRow(
              title: context.loc.sellPayoutRecipient,
              value: switch (order?.payoutMethod) {
                OrderPaymentMethod.cadBalance => context.loc.sellCadBalance,
                OrderPaymentMethod.crcBalance => context.loc.sellCrcBalance,
                OrderPaymentMethod.eurBalance => context.loc.sellEurBalance,
                OrderPaymentMethod.usdBalance => context.loc.sellUsdBalance,
                OrderPaymentMethod.mxnBalance => context.loc.sellMxnBalance,
                OrderPaymentMethod.arsBalance => context.loc.sellArsBalance,
                OrderPaymentMethod.copBalance => context.loc.sellCopBalance,
                _ => order?.payoutMethod.name,
              },
            ),
            const _Divider(),
            _DetailRow(
              title: context.loc.sellPayinAmount,
              value: order == null
                  ? null
                  : bitcoinUnit == BitcoinUnit.btc
                  ? FormatAmount.btc(order.payinAmount)
                  : FormatAmount.sats(
                      ConvertAmount.btcToSats(order.payinAmount),
                    ),
            ),
            _DetailRow(
              title: context.loc.sellPayoutAmount,
              value: order == null
                  ? null
                  : FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
            ),
            _DetailRow(
              title: context.loc.sellExchangeRate,
              value: order == null
                  ? null
                  : FormatAmount.fiat(
                      order.exchangeRateAmount ??
                          order.payoutAmount / order.payinAmount,
                      order.exchangeRateCurrency ?? order.payoutCurrency,
                    ),
            ),
            const _Divider(),
            _DetailRow(
              title: context.loc.sellPayFromWallet,
              value:
                  wallet?.label ??
                  (wallet?.isDefault == true
                      ? wallet?.isLiquid == true
                            ? context.loc.sellInstantPayments
                            : context.loc.sellSecureBitcoinWallet
                      : ''),
            ),
            // Liquid payins pay the network minimum, so there is nothing to pick.
            if (wallet != null && !wallet.isLiquid) const _FeePriorityRow(),
            _DetailRow(
              title: context.loc.sellSendPaymentNetworkFees,
              value: context.select((SellBloc bloc) {
                final state = bloc.state;
                if (state is SellPaymentState && state.absoluteFees != null) {
                  return bitcoinUnit == BitcoinUnit.btc
                      ? FormatAmount.btc(
                          ConvertAmount.satsToBtc(state.absoluteFees!),
                        )
                      : FormatAmount.sats(state.absoluteFees!);
                }
                return context.loc.sellCalculating;
              }),
            ),
            if (wallet != null &&
                !wallet.isLiquid &&
                order?.payjoinBip21 != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.loc.payjoinUseToggle,
                      style: context.font.bodyMedium,
                    ),
                  ),
                  BBSwitch(
                    value: isPayjoinEnabled,
                    onChanged: isConfirmingPayment
                        ? null
                        : (enabled) => context.read<SellBloc>().add(
                            SellEvent.payjoinToggled(enabled),
                          ),
                  ),
                ],
              ),
            const Spacer(),
            _BottomButtons(
              onContinuePressed: () {
                context.read<SellBloc>().add(
                  const SellEvent.sendPaymentConfirmed(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Fee Priority" row: opens the shared fee modal and shows the committed
/// selection (#2521). The row goes inert — plain text, no chevron — once the
/// confirmation starts, since the payin being signed was built at the rate
/// showing here and the broadcast latch must not be reopened (#2522).
class _FeePriorityRow extends StatelessWidget {
  const _FeePriorityRow();

  @override
  Widget build(BuildContext context) {
    final (selectedFeeOption, customFee, canEditFees) = context.select((
      SellBloc bloc,
    ) {
      final state = bloc.state;
      if (state is! SellPaymentState) {
        return (FeeSelection.fastest, null as NetworkFee?, false);
      }
      return (state.selectedFeeOption, state.customFee, state.canEditFees);
    });

    return _DetailRow(
      title: context.loc.sellFeePriority,
      value: feeSelectionRowLabel(
        context,
        selection: selectedFeeOption,
        customFee: customFee,
        fastestLabel: context.loc.sellFastest,
      ),
      onTap: canEditFees
          ? () async {
              final bloc = context.read<SellBloc>();
              final selected = await BlurredBottomSheet.show<String>(
                context: context,
                child: FeeOptionsModal(
                  viewState: bloc,
                  actions: bloc,
                  defaultAbsoluteCustomFee: false,
                  customFeeColors: FeeModalCustomFeeColors(
                    tile: context.appColors.surface,
                    shadow: context.appColors.border,
                    unselectedIcon: context.appColors.textMuted,
                  ),
                ),
              );
              if (selected != null) {
                // A preset tile was tapped; the handler discards any arm left
                // over from typing in the custom field.
                bloc.add(
                  SellEvent.feeOptionSelected(
                    FeeSelectionName.fromString(selected),
                  ),
                );
              } else {
                // Dismissed without picking. Typing IS the selection and
                // dismissing IS the apply, so a typed rate is committed here
                // (or rolled back when it is below the relay floor).
                bloc.add(const SellEvent.customFeeFinalized());
              }
            }
          : null,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String? value;
  final void Function()? onTap;
  final String? copyValue;

  const _DetailRow({
    required this.title,
    required this.value,
    this.onTap,
    this.copyValue,
  }) : super();

  @override
  Widget build(BuildContext context) {
    final valueColor = onTap == null
        ? context.appColors.outlineVariant
        : context.appColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: value == null
          ? const LoadingLineContent()
          : Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  title,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: onTap == null
                      ? Row(
                          mainAxisAlignment: .end,
                          children: [
                            Flexible(
                              child: Text(
                                value!,
                                textAlign: .end,
                                maxLines: 2,
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.appColors.secondary,
                                ),
                              ),
                            ),
                            if (copyValue != null) ...[
                              const Gap(8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: copyValue!),
                                  );
                                  SnackBarUtils.showCopiedSnackBar(context);
                                },
                                child: Icon(
                                  Icons.copy,
                                  color: context.appColors.primary,
                                  size: 16,
                                ),
                              ),
                            ],
                          ],
                        )
                      : GestureDetector(
                          onTap: onTap,
                          behavior: .opaque,
                          child: Row(
                            mainAxisAlignment: .end,
                            children: [
                              Flexible(
                                child: Text(
                                  value!,
                                  textAlign: .end,
                                  maxLines: 2,
                                  style: context.font.bodyMedium?.copyWith(
                                    color: valueColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: valueColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: context.appColors.secondaryFixedDim, height: 1);
  }
}

class _BottomButtons extends StatelessWidget {
  final VoidCallback onContinuePressed;

  const _BottomButtons({required this.onContinuePressed}) : super();

  @override
  Widget build(BuildContext context) {
    final isConfirmingPayment = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState &&
          (bloc.state as SellPaymentState).isConfirmingPayment,
    );
    final isPayinBroadcast = context.select(
      (SellBloc bloc) =>
          bloc.state is SellPaymentState &&
          (bloc.state as SellPaymentState).isPayinBroadcast,
    );
    final wallet = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).selectedWallet
          : null,
    );
    return Column(
      children: [
        const _SellError(),
        const _PaymentInFlightStatus(),
        if (wallet != null && !wallet.isLiquid) ...[
          BBButton.big(
            label: context.loc.sellAdvancedSettings,
            // Changing coin selection or RBF mid-confirmation would rebuild the
            // transaction under the payment being sent.
            disabled: isConfirmingPayment || isPayinBroadcast,
            onPressed: () {
              BlurredBottomSheet.show(
                context: context,
                child: BlocProvider.value(
                  value: context.read<SellBloc>(),
                  child: const SellAdvancedOptionsBottomSheet(),
                ),
              );
            },
            bgColor: context.appColors.transparent,
            textColor: context.appColors.secondary,
            outlined: true,
            borderColor: context.appColors.secondary,
          ),
          const Gap(16),
        ],
        BBButton.big(
          label: context.loc.sellSendPaymentContinue,
          disabled: isConfirmingPayment || isPayinBroadcast,
          onPressed: onContinuePressed,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}

/// Spinner and status text right above the confirm button, so the in-flight
/// payment is visible where the user is looking (#2522).
class _PaymentInFlightStatus extends StatelessWidget {
  const _PaymentInFlightStatus();

  @override
  Widget build(BuildContext context) {
    final (isConfirmingPayment, isPayinBroadcast) = context.select((
      SellBloc bloc,
    ) {
      final state = bloc.state;
      if (state is! SellPaymentState) return (false, false);
      return (state.isConfirmingPayment, state.isPayinBroadcast);
    });

    if (!isConfirmingPayment && !isPayinBroadcast) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: .center,
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.appColors.primary,
            ),
          ),
          const Gap(8),
          Flexible(
            child: Text(
              isPayinBroadcast
                  ? context.loc.sellPaymentSentRefreshingOrder
                  : context.loc.sellSendingPayment,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.outline,
              ),
              textAlign: .center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellError extends StatelessWidget {
  const _SellError();

  @override
  Widget build(BuildContext context) {
    final sellError = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState
          ? (bloc.state as SellPaymentState).error
          : null,
    );

    if (sellError == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Text(
          sellError.toTranslated(context),
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
