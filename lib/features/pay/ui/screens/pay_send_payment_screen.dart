import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:fees/fees.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show ConvertAmount, FormatAmount;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/presentation/pay_failure_l10n.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_advanced_options_bottom_sheet.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAdvancedOptionsLink,
        BullAsyncStatus,
        BullBottomSheet,
        BullButton,
        BullCountdown,
        BullDetailsTableItem,
        BullReferenceNotice,
        BullSwitch,
        Gap,
        BullTypographyX;

class PaySendPaymentScreen extends StatelessWidget {
  const PaySendPaymentScreen({super.key});

  String _formatSinpePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return 'N/A';

    // Remove any existing formatting
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add +506 prefix
    final String formattedNumber = '+506$cleanNumber';

    // Add dashes every 4 digits after the prefix
    if (cleanNumber.length >= 4) {
      const String prefix = '+506';
      final String number = cleanNumber;
      final StringBuffer formatted = StringBuffer(prefix);

      for (int i = 0; i < number.length; i += 4) {
        final int end = (i + 4 < number.length) ? i + 4 : number.length;
        formatted.write('-${number.substring(i, end)}');
      }

      return formatted.toString();
    }

    return formattedNumber;
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmingPayment = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState &&
          (bloc.state as PayPaymentState).isConfirmingPayment,
    );
    final isPayinBroadcast = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState &&
          (bloc.state as PayPaymentState).isPayinBroadcast,
    );
    final wallet = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(:final selectedWallet) => selectedWallet,
        PayPreparingPaymentState(:final selectedWallet) => selectedWallet,
        _ => null,
      },
    );
    final order = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).payOrder
          : null,
    );
    final recipient = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).selectedRecipient
          : null,
    );
    final isPayjoinEnabled = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? (bloc.state as PayPaymentState).isPayjoinEnabled
          : false,
    );

    final preparationFailure = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPreparingPaymentState(:final error) => error,
        _ => null,
      },
    );
    final canLeave = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        final PayPaymentState s => s.canLeavePaymentScreen,
        _ => !isConfirmingPayment,
      },
    );
    final isPayinPastDeadline = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(:final isPayinPastDeadline) => isPayinPastDeadline,
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
          context.read<PayBloc>().add(
            const PayEvent.paymentPreparationAbandoned(),
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
                    style: context.bullType.body.copyWith(
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
                        context.loc.payConfirmPayment,
                        style: context.bullType.subtitle
                            .copyWith(fontWeight: FontWeight.w500)
                            .copyWith(color: context.appColors.secondary),
                      ),
                      const Gap(4.0),
                      Row(
                        mainAxisAlignment: .center,
                        children: [
                          Text(
                            context.loc.payPriceRefreshIn,
                            style: context.bullType.body.copyWith(
                              color: context.appColors.outline,
                            ),
                          ),
                          if (order?.confirmationDeadline case final deadline?)
                            BullCountdown(until: deadline),
                        ],
                      ),

                      const Gap(8.0),
                      BullDetailsTableItem(
                        label: context.loc.payOrderNumber,
                        displayValue: order?.orderNumber.toString(),
                        copyValue: order?.orderNumber.toString(),
                        copiedMessage: context.loc.copiedToClipboard,
                      ),
                      // The payin goes to this address: showing it is the user's only
                      // way to notice if it ever changed under them.
                      BullDetailsTableItem(
                        label: context.loc.payDepositAddress,
                        displayWidget: switch (order?.toAddress) {
                          final address? => AddressViewer(
                            address,
                            textAlign: TextAlign.end,
                          ),
                          null => null,
                        },
                      ),
                      if (order?.paymentDescription case final description?
                          when description.isNotEmpty)
                        BullDetailsTableItem(
                          label: context.loc.payPaymentDescription,
                          displayValue: description,
                        ),
                      BullDetailsTableItem(
                        label: context.loc.payRecipientType,
                        displayValue: recipient?.type.label(context),
                      ),
                      BullDetailsTableItem(
                        label: context.loc.payRecipientName,
                        displayValue: recipient?.displayName,
                      ),
                      BullDetailsTableItem(
                        label: context.loc.payRecipientDetails,
                        displayValue: recipient != null
                            ? _getRecipientInfoValue(recipient)
                            : null,
                      ),
                      const _Divider(),
                      BullDetailsTableItem(
                        label: context.loc.payPayinAmount,
                        displayValue: order == null
                            ? null
                            : FormatAmount.btc(order.payinAmount),
                      ),
                      BullDetailsTableItem(
                        label: context.loc.payPayoutAmount,
                        displayValue: order == null
                            ? null
                            : FormatAmount.fiat(
                                order.payoutAmount,
                                order.payoutCurrency,
                              ),
                      ),
                      BullDetailsTableItem(
                        label: context.loc.payExchangeRate,
                        displayValue: order == null
                            ? null
                            : FormatAmount.fiat(
                                order.exchangeRateAmount ??
                                    order.payoutAmount / order.payinAmount,
                                order.exchangeRateCurrency ??
                                    order.payoutCurrency,
                              ),
                      ),
                      const _Divider(),
                      BullDetailsTableItem(
                        label: context.loc.payPayFromWallet,
                        displayValue:
                            wallet?.label ??
                            (wallet?.isDefault == true
                                ? wallet?.isLiquid == true
                                      ? context.loc.payInstantPayments
                                      : context.loc.paySecureBitcoinWallet
                                : ''),
                      ),
                      // Liquid payins pay the network minimum, so there is nothing to pick.
                      if (wallet != null && !wallet.isLiquid)
                        const _FeePriorityRow(),
                      BullDetailsTableItem(
                        label: context.loc.payNetworkFees,
                        displayValue: context.select((PayBloc bloc) {
                          final state = bloc.state;
                          if (state case PayPaymentState(
                            absoluteFees: final fees?,
                          )) {
                            return FormatAmount.btc(
                              ConvertAmount.satsToBtc(fees),
                            );
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
                                style: context.bullType.body,
                              ),
                            ),
                            BullSwitch(
                              value: isPayjoinEnabled,
                              onChanged: isConfirmingPayment || isPayinBroadcast
                                  ? null
                                  : (enabled) => context.read<PayBloc>().add(
                                      PayEvent.payjoinToggled(enabled),
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
                context.read<PayBloc>().add(
                  const PayEvent.sendPaymentConfirmed(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String? _getRecipientInfoValue(RecipientViewModel recipient) {
    switch (recipient.type) {
      case RecipientType.bankAccountArgentina:
      case RecipientType.pseColombia:
        return recipient.bankAccount;
      case RecipientType.nequiColombia:
        return recipient.phoneNumber;
      case RecipientType.interacEmailCad:
        return recipient.email;
      case RecipientType.billPaymentCad:
        return recipient.payeeName ??
            recipient.payeeCode ??
            recipient.payeeAccountNumber;
      case RecipientType.bankTransferCad:
        return '${recipient.institutionNumber}-${recipient.transitNumber}-${recipient.accountNumber}';
      case RecipientType.sepaEur:
      case RecipientType.confidentialSepaEur:
        return recipient.iban;
      case RecipientType.speiClabeMxn:
        return recipient.clabe;
      case RecipientType.speiSmsMxn:
        return recipient.phoneNumber;
      case RecipientType.speiCardMxn:
        return recipient.debitcard;
      case RecipientType.sinpeIbanUsd:
        return recipient.iban;
      case RecipientType.sinpeIbanCrc:
        return recipient.iban;
      case RecipientType.sinpeMovilCrc:
        return _formatSinpePhoneNumber(recipient.phoneNumber);
    }
  }
}

/// "Fee Priority" row: opens the shared fee modal and shows the committed
/// selection (#2521). The row goes inert — plain text, no chevron — once the
/// confirmation starts, since the payin being signed was built at the rate
/// showing here.
class _FeePriorityRow extends StatelessWidget {
  const _FeePriorityRow();

  @override
  Widget build(BuildContext context) {
    final (selectedFeeOption, customFee, canEditFees) = context.select((
      PayBloc bloc,
    ) {
      final state = bloc.state;
      if (state is! PayPaymentState) {
        return (FeeSelection.fastest, null as NetworkFee?, false);
      }
      return (state.selectedFeeOption, state.customFee, state.canEditFees);
    });

    return BullDetailsTableItem(
      label: context.loc.payFeePriority,
      displayValue: feeSelectionRowLabel(
        context,
        ui: FeeUi.standard,
        selection: selectedFeeOption,
        customFee: customFee,
        fastestLabel: context.loc.payFastest,
      ),
      onValueTap: canEditFees
          ? () async {
              final bloc = context.read<PayBloc>();
              final selected = await BullBottomSheet.show<String>(
                context: context,
                child: FeeOptionsModal(
                  ui: FeeUi.standard,
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
                  PayEvent.feeOptionSelected(
                    FeeSelectionName.fromString(selected),
                  ),
                );
              } else {
                // Dismissed without picking. Typing IS the selection and
                // dismissing IS the apply, so a typed rate is committed here
                // (or rolled back when it is below the relay floor).
                bloc.add(const PayEvent.customFeeFinalized());
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
      (PayBloc bloc) =>
          bloc.state is PayPaymentState &&
          (bloc.state as PayPaymentState).isConfirmingPayment,
    );
    final isPayinBroadcast = context.select(
      (PayBloc bloc) =>
          bloc.state is PayPaymentState &&
          (bloc.state as PayPaymentState).isPayinBroadcast,
    );
    final wallet = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(:final selectedWallet) => selectedWallet,
        PayPreparingPaymentState(:final selectedWallet) => selectedWallet,
        _ => null,
      },
    );
    final isReady = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(:final error) =>
          error is! PayPayinOutcomeUnknownFailure,
        _ => false,
      },
    );
    final paused = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(:final pausedPayjoinSession) => pausedPayjoinSession,
        _ => null,
      },
    );
    final retrying = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(:final isRetryingPayjoinProposal) =>
          isRetryingPayjoinProposal,
        _ => false,
      },
    );
    final pastDeadlineTxid = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayPaymentState(
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
        const _PayError(),
        if (wallet != null &&
            !wallet.isLiquid &&
            !isConfirmingPayment &&
            !isPayinBroadcast) ...[
          BullAdvancedOptionsLink(
            label: context.loc.payAdvancedSettings,
            onPressed: (!isReady || isConfirmingPayment || isPayinBroadcast)
                ? null
                : () {
                    BullBottomSheet.show(
                      context: context,
                      child: BlocProvider.value(
                        value: context.read<PayBloc>(),
                        child: const PayAdvancedOptionsBottomSheet(),
                      ),
                    );
                  },
          ),
          const Gap(16),
        ],
        if (pastDeadlineTxid != null)
          BullReferenceNotice(
            message: context.loc.exchangePaymentSentPastDeadline,
            reference: pastDeadlineTxid,
            copiedMessage: context.loc.copiedToClipboard,
            copyLabel: context.loc.copyDialogButton,
            actionLabel: context.loc.exchangePaymentSentLeave,
            onAction: () => _leavePastDeadlinePayin(context),
          )
        else if (paused != null && !isPayinBroadcast)
          BullButton.secondary(
            label: context.loc.retry,
            onPressed: (retrying || !paused.canRetryProposal)
                ? null
                : () => context.read<PayBloc>().add(
                    const PayEvent.payjoinProposalRetryRequested(),
                  ),
          )
        else if (isConfirmingPayment || isPayinBroadcast)
          BullAsyncStatus.progress(
            label: isPayinBroadcast
                ? context.loc.exchangePaymentSentRefreshingOrder
                : context.loc.exchangeSendingPayment,
            color: context.appColors.secondary,
            textStyle: context.bullType.body,
          )
        else
          BullButton.primary(
            label: context.loc.payContinue,
            onPressed: (!isReady || isConfirmingPayment || isPayinBroadcast)
                ? null
                : onContinuePressed,
          ),
      ],
    );
  }
}

class _PayError extends StatelessWidget {
  const _PayError();

  @override
  Widget build(BuildContext context) {
    final payError = context.select(
      (PayBloc bloc) => bloc.state is PayPaymentState
          ? ((bloc.state as PayPaymentState).pausedPayjoinSession != null
                ? const PayPayjoinPausedFailure()
                : (bloc.state as PayPaymentState).error)
          : null,
    );

    if (payError == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Text(
          payError.toTranslated(context),
          style: context.bullType.body.copyWith(color: context.appColors.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Leaves the flow for good: the bloc that holds the paid order's latch goes
/// with it, so a new order can be started from scratch.
void _leavePastDeadlinePayin(BuildContext context) =>
    context.goNamed(ExchangeRoute.exchangeHome.name);
