import 'package:bb_mobile/features/sell/domain/sell_order_payin_x.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_payout_details_v2.dart';
import 'package:bb_mobile/core/widgets/lists/payment_detail_row.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/fees/fee_options_modal.dart';
import 'package:bb_mobile/core/widgets/fees/fee_selection_label.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAsyncStatus,
        BullBottomSheet,
        BullButton,
        BullCountdown,
        BullReferenceNotice,
        BullSwitch,
        Gap;

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
      (SellBloc bloc) => switch (bloc.state) {
        SellPaymentState(:final selectedWallet) => selectedWallet,
        SellPreparingPaymentState(:final selectedWallet) => selectedWallet,
        _ => null,
      },
    );
    final recipient = context.select(
      (SellBloc bloc) => switch (bloc.state) {
        SellPaymentState(:final payoutRecipient) => payoutRecipient,
        _ => null,
      },
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

    final preparationFailure = context.select(
      (SellBloc bloc) => switch (bloc.state) {
        SellPreparingPaymentState(:final error) => error,
        _ => null,
      },
    );
    final canLeave = context.select(
      (SellBloc bloc) => switch (bloc.state) {
        final SellPaymentState s => s.canLeavePaymentScreen,
        _ => !isConfirmingPayment,
      },
    );
    final isPayinPastDeadline = context.select(
      (SellBloc bloc) => switch (bloc.state) {
        SellPaymentState(:final isPayinPastDeadline) => isPayinPastDeadline,
        _ => false,
      },
    );
    return PopScope<Object?>(
      // Back on a payin reported past its deadline leaves the whole flow, like
      // the Leave button: popping to the wallet selection would land on a flow
      // still latched to the paid order.
      canPop: canLeave && !isPayinPastDeadline,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isPayinPastDeadline) {
          _leavePastDeadlinePayin(context);
          return;
        }
        if (didPop) {
          context.read<SellBloc>().add(
            const SellEvent.paymentPreparationAbandoned(),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Image.asset(
            Assets.logos.bbLogoSmall.path,
            height: 32,
            width: 32,
          ),
        ),
        body: preparationFailure != null && order == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    preparationFailure.toTranslated(context),
                    textAlign: TextAlign.center,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
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
                            BullCountdown(until: deadline),
                        ],
                      ),

                      const Gap(8.0),
                      PaymentDetailRow(
                        title: context.loc.sellOrderNumber,
                        value: order?.orderNumber.toString(),
                        copyValue: order?.orderNumber.toString(),
                      ),
                      // The payin goes to this address: showing it is the user's only
                      // way to notice if it ever changed under them.
                      PaymentDetailRow(
                        title: context.loc.sellDepositAddress,
                        isAddress: true,
                        value: order?.toAddress,
                        copyValue: order?.toAddress,
                      ),
                      if (recipient != null)
                        SellPayoutDetailsV2(recipient: recipient)
                      else
                        PaymentDetailRow(
                          title: context.loc.sellPayoutRecipient,
                          value: switch (order?.payoutMethod) {
                            OrderPaymentMethod.cadBalance =>
                              context.loc.sellCadBalance,
                            OrderPaymentMethod.crcBalance =>
                              context.loc.sellCrcBalance,
                            OrderPaymentMethod.eurBalance =>
                              context.loc.sellEurBalance,
                            OrderPaymentMethod.usdBalance =>
                              context.loc.sellUsdBalance,
                            OrderPaymentMethod.mxnBalance =>
                              context.loc.sellMxnBalance,
                            OrderPaymentMethod.arsBalance =>
                              context.loc.sellArsBalance,
                            OrderPaymentMethod.copBalance =>
                              context.loc.sellCopBalance,
                            _ => order?.payoutMethod.name,
                          },
                        ),
                      const _Divider(),
                      PaymentDetailRow(
                        title: context.loc.sellPayinAmount,
                        value: order == null
                            ? null
                            : bitcoinUnit == BitcoinUnit.btc
                            ? FormatAmount.btc(order.payinAmount)
                            : FormatAmount.sats(
                                ConvertAmount.btcToSats(order.payinAmount),
                              ),
                      ),
                      PaymentDetailRow(
                        title: context.loc.sellPayoutAmount,
                        value: order == null
                            ? null
                            : FormatAmount.fiat(
                                order.payoutAmount,
                                order.payoutCurrency,
                              ),
                      ),
                      PaymentDetailRow(
                        title: context.loc.sellExchangeRate,
                        value: order == null
                            ? null
                            : FormatAmount.fiat(
                                order.sellExchangeRateAmount ??
                                    order.payoutAmount / order.payinAmount,
                                order.sellExchangeRateCurrency ??
                                    order.payoutCurrency,
                              ),
                      ),
                      const _Divider(),
                      PaymentDetailRow(
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
                      if (wallet != null && !wallet.isLiquid)
                        const _FeePriorityRow(),
                      PaymentDetailRow(
                        title: context.loc.sellSendPaymentNetworkFees,
                        value: context.select((SellBloc bloc) {
                          final state = bloc.state;
                          if (state case SellPaymentState(
                            absoluteFees: final fees?,
                          )) {
                            return bitcoinUnit == BitcoinUnit.btc
                                ? FormatAmount.btc(
                                    ConvertAmount.satsToBtc(fees),
                                  )
                                : FormatAmount.sats(fees);
                          }
                          return null;
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
                            BullSwitch(
                              value: isPayjoinEnabled,
                              onChanged: isConfirmingPayment
                                  ? null
                                  : (enabled) => context.read<SellBloc>().add(
                                      SellEvent.payjoinToggled(enabled),
                                    ),
                            ),
                          ],
                        ),
                      const Gap(24),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _BottomButtons(
              onContinuePressed: () {
                context.read<SellBloc>().add(
                  const SellEvent.sendPaymentConfirmed(),
                );
              },
            ),
          ),
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

    return PaymentDetailRow(
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
              final selected = await BullBottomSheet.show<String>(
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
      (SellBloc bloc) => switch (bloc.state) {
        SellPaymentState(:final selectedWallet) => selectedWallet,
        SellPreparingPaymentState(:final selectedWallet) => selectedWallet,
        _ => null,
      },
    );
    final isReady = context.select(
      (SellBloc bloc) => bloc.state is SellPaymentState,
    );
    final pastDeadlineTxid = context.select(
      (SellBloc bloc) => switch (bloc.state) {
        SellPaymentState(
          isPayinPastDeadline: true,
          :final payinBroadcastTxid?,
        ) =>
          payinBroadcastTxid,
        _ => null,
      },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SellError(),
        if (wallet != null &&
            !wallet.isLiquid &&
            !isConfirmingPayment &&
            !isPayinBroadcast) ...[
          BullButton.big(
            label: context.loc.sellAdvancedSettings,
            // Changing coin selection or RBF mid-confirmation would rebuild the
            // transaction under the payment being sent.
            disabled: !isReady || isConfirmingPayment || isPayinBroadcast,
            onPressed: () {
              BullBottomSheet.show(
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
        if (pastDeadlineTxid != null)
          BullReferenceNotice(
            message: context.loc.exchangePaymentSentPastDeadline,
            reference: pastDeadlineTxid,
            copiedMessage: context.loc.copiedToClipboard,
            actionLabel: context.loc.exchangePaymentSentLeave,
            onAction: () => _leavePastDeadlinePayin(context),
          )
        else if (isConfirmingPayment || isPayinBroadcast)
          BullAsyncStatus.progress(
            label: isPayinBroadcast
                ? context.loc.exchangePaymentSentRefreshingOrder
                : context.loc.exchangeSendingPayment,
            color: context.appColors.secondary,
            textStyle: context.font.bodyMedium,
          )
        else
          BullButton.big(
            label: context.loc.sellSendPaymentContinue,
            disabled: !isReady || isConfirmingPayment || isPayinBroadcast,
            onPressed: onContinuePressed,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
      ],
    );
  }
}

class _SellError extends StatelessWidget {
  const _SellError();

  @override
  Widget build(BuildContext context) {
    final SellFailure? sellError = context.select(
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

/// Leaves the flow for good: the bloc that holds the paid order's latch goes
/// with it, so a new order can be started from scratch.
void _leavePastDeadlinePayin(BuildContext context) =>
    context.goNamed(WalletRoute.walletHome.name);
