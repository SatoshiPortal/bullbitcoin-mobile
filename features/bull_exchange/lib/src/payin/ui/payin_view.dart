import 'dart:async';

import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/payin/payin_l10n.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bip21_uri/bip21_uri.dart';
import 'package:bull_exchange/src/payin/exchange_liquid_asset.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullCountdown,
        BullQrCode,
        BullSnackBar,
        BullText,
        BullTypographyX,
        Gap;
import 'package:flutter/services.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// The page of a payin that is still running (sell and pay, composition §6
/// "Payin screen"). Terminal payin states are the flow's own pages. No page
/// offers a new send once a payin may be out: Verifying and Unverified only
/// look it up, Unseen resends the same signed transaction.
/// The copy of the external payin page; sell and pay ship their own.
typedef PayinExternalLabels = ({
  String refreshIn,
  String copyInvoice,
  String showQr,
  String qrTitle,
});

class PayinView extends StatelessWidget {
  const PayinView({
    super.key,
    required this.title,
    required this.state,
    required this.onEvent,
    required this.onBack,
    required this.externalLabels,
  });

  final String title;

  /// The flow's back event; the app bar shows it on every payin page.
  final VoidCallback onBack;
  final PayinExternalLabels externalLabels;
  final PayinState<PayinSpend> state;
  final void Function(PayinEvent<PayinSpend> event) onEvent;

  @override
  Widget build(BuildContext context) {
    FlowAction retry() =>
        FlowAction(context.loc.retry, () => onEvent(const PayinRetryPressed()));
    FlowAction back() => FlowAction(
      context.loc.cancel,
      () => onEvent(const PayinBackPressed()),
      primary: false,
    );
    FlowStatusPage page({
      String? headline,
      String? message,
      bool busy = false,
      bool isError = false,
      List<FlowAction> actions = const [],
    }) => FlowStatusPage(
      title: title,
      onBack: onBack,
      headline: headline,
      message: message,
      busy: busy,
      isError: isError,
      actions: actions,
    );
    return switch (state) {
      PayinBuilding() || PayinBroadcasting() => page(
        headline: context.loc.exchangePayinSending,
        busy: true,
      ),
      PayinWriteRefused(:final refusal) => page(
        message: refusal.toTranslated(context),
        isError: true,
        actions: [retry(), back()],
      ),
      PayinSendFailed(:final problem) => page(
        headline: context.loc.exchangePayinNotSent,
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry(), back()],
      ),
      PayinRechecking() => page(
        message: context.loc.exchangeStepVerifying,
        busy: true,
      ),
      PayinRecheckFailed(:final problem) => page(
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry(), back()],
      ),
      PayinPayjoinNegotiating() => page(
        headline: context.loc.exchangePayinPayjoinNegotiating,
        busy: true,
      ),
      PayinPayjoinPaused() => page(
        headline: context.loc.exchangePayinPayjoinPaused,
        actions: [retry()],
      ),
      PayinVerifying() => page(
        headline: context.loc.exchangePaymentOutcomeUnknownChecking,
        busy: true,
      ),
      PayinUnseen(:final txid) => page(
        headline: context.loc.exchangePayinUnseen,
        message: txid,
        actions: [
          FlowAction(
            context.loc.exchangePayinResend,
            () => onEvent(const PayinResendPressed()),
          ),
          FlowAction(
            context.loc.exchangeStepCheckAgain,
            () => onEvent(const PayinRetryPressed()),
            primary: false,
          ),
        ],
      ),
      PayinUnverified(:final txid, :final problem) => page(
        headline: context.loc.exchangeStepUnverified,
        message: [problem.toTranslated(context), ?txid].join('\n'),
        isError: true,
        actions: [
          FlowAction(
            context.loc.exchangeStepCheckAgain,
            () => onEvent(const PayinRetryPressed()),
          ),
        ],
      ),
      PayinWatching(:final txid, :final watch) => switch (watch) {
        WatchUnreadable() || WatchTimedOut() => page(
          headline: context.loc.exchangePaymentSentRefreshingOrder,
          message: [context.loc.exchangeStepTimedOut, ?txid].join('\n'),
          actions: [
            FlowAction(
              context.loc.exchangeStepCheckAgain,
              () => onEvent(const PayinWatchEvent(WatchRetryPressed())),
            ),
            FlowAction(
              context.loc.exchangePaymentSentLeave,
              () => onEvent(const PayinWatchEvent(WatchLeavePressed())),
              primary: false,
            ),
          ],
        ),
        WatchWatching() ||
        WatchPaused() ||
        WatchDone() ||
        WatchReceipt() ||
        WatchFailed() ||
        WatchSessionEnded() ||
        WatchLeft() => page(
          headline: context.loc.exchangePaymentSentRefreshingOrder,
          message: txid,
          busy: true,
        ),
      },
      PayinExternal(:final order, :final target) => _ExternalPayin(
        title: title,
        labels: externalLabels,
        order: order,
        target: target,
        onBack: () => onEvent(const PayinBackPressed()),
      ),
      PayinExternalLeaving() => page(
        headline: context.loc.exchangePayinLeaveTitle,
        message: context.loc.exchangePayinLeaveMessage,
        actions: [
          FlowAction(
            context.loc.exchangePayinStay,
            () => onEvent(const PayinLeaveCancelled()),
          ),
          FlowAction(
            context.loc.exchangePaymentSentLeave,
            () => onEvent(const PayinLeaveConfirmed()),
            primary: false,
          ),
        ],
      ),
      PayinCompleted() ||
      PayinRefusedByExchange() ||
      PayinQuoteLapsed() ||
      PayinOrderEnded() ||
      PayinDepositRefused() ||
      PayinLeft() ||
      PayinLeftPending() ||
      PayinSessionEnded() => page(busy: true),
    };
  }
}

/// Pay the order from another wallet: the deposit of the order's rail and
/// the amount. The order watch runs meanwhile; Back asks first (PAY-4).
class _ExternalPayin extends StatelessWidget {
  const _ExternalPayin({
    required this.title,
    required this.labels,
    required this.order,
    required this.target,
    required this.onBack,
  });

  final String title;
  final PayinExternalLabels labels;
  final Order order;
  final DepositTarget target;
  final VoidCallback onBack;

  /// What another wallet pays: a payment link with the amount on chain and
  /// on Liquid (with the L-BTC asset), the invoice itself on Lightning.
  String get _invoice => switch (target) {
    OnchainDeposit(:final address) => Bip21Uri(
      scheme: 'bitcoin',
      address: address,
      amount: order.payinAmount,
    ).toString(),
    LiquidDeposit(:final address) => ExchangeLiquidAsset.paymentUri(
      address: address,
      amountBtc: order.payinAmount,
      isTestnet: order.isTestnet,
    ),
    LightningInvoiceDeposit(:final invoice) => invoice,
  };

  @override
  Widget build(BuildContext context) {
    final deposit = switch (target) {
      OnchainDeposit(:final address) ||
      LiquidDeposit(:final address) => address,
      LightningInvoiceDeposit(:final invoice) => invoice,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.loc.exchangePayinExternalTitle,
                      style: context.bullType.subtitle,
                    ),
                    if (order.confirmationDeadline case final deadline?)
                      Row(
                        children: [
                          Text(
                            labels.refreshIn,
                            style: context.bullType.body.copyWith(
                              color: context.appColors.outline,
                            ),
                          ),
                          BullCountdown(until: deadline),
                        ],
                      ),
                    const Gap(16),
                    Text(
                      '${order.payinAmount} ${order.payinCurrency}',
                      style: context.bullType.headline,
                    ),
                    const Gap(16),
                    AddressViewer(deposit),
                    const Gap(16),
                    Text(
                      context.loc.exchangePayinExternalWaiting,
                      style: context.bullType.body,
                    ),
                    const Gap(24),
                    Row(
                      children: [
                        Expanded(
                          child: BullButton.secondary(
                            label: labels.copyInvoice,
                            onPressed: () {
                              unawaited(
                                Clipboard.setData(
                                  ClipboardData(text: _invoice),
                                ),
                              );
                              BullSnackBar.show(
                                context,
                                message: context.loc.copiedToClipboard,
                              );
                            },
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: BullButton.secondary(
                            label: labels.showQr,
                            onPressed: () => unawaited(
                              BullBottomSheet.show<void>(
                                context: context,
                                child: _PayinQrSheet(
                                  title: labels.qrTitle,
                                  data: _invoice,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: BullButton.secondary(
                label: context.loc.exchangePaymentSentLeave,
                onPressed: onBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayinQrSheet extends StatelessWidget {
  const _PayinQrSheet({required this.title, required this.data});

  final String title;
  final String data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BullText(
                title,
                style: context.bullType.subtitle,
                color: context.appColors.secondary,
              ),
              IconButton(
                tooltip: context.loc.closeDialogButton,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Gap(24),
          Center(
            child: BullQrCode(data: data, size: 280, semanticsLabel: title),
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
