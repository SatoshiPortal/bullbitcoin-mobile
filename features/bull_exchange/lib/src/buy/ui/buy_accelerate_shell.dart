import 'dart:async';

import 'package:bull_exchange/src/buy/presentation/buy_accelerate_bloc.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:exchange/steps.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDetailsTable,
        BullDetailsTableItem,
        BullLoader,
        BullSuccessScreen,
        BullTypographyX,
        Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;

/// The accelerate flow's one screen: its page is a function of the flow
/// state and Back is an event the machine answers.
class AccelerateFlowShell extends StatefulWidget {
  const AccelerateFlowShell({
    super.key,
    required this.unit,
    required this.openOrder,
  });

  final Stream<BitcoinUnit> unit;
  final void Function(BuildContext context, String orderId) openOrder;

  @override
  State<AccelerateFlowShell> createState() => _AccelerateFlowShellState();
}

class _AccelerateFlowShellState extends State<AccelerateFlowShell> {
  late final StreamSubscription<BitcoinUnit> _units;
  BitcoinUnit _unit = BitcoinUnit.btc;

  @override
  void initState() {
    super.initState();
    _units = widget.unit.listen((unit) {
      if (mounted) setState(() => _unit = unit);
    });
  }

  @override
  void dispose() {
    unawaited(_units.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccelerateFlowBloc, AccelerateFlowState>(
      listenWhen: (previous, current) =>
          current is AccelerateClosed && previous is! AccelerateClosed,
      listener: (context, state) {
        if (context.canPop()) {
          context.pop();
        } else {
          BullExchangeNavigation.goToDashboard(context);
        }
      },
      builder: (context, state) {
        final bloc = context.read<AccelerateFlowBloc>();
        return PopScope(
          canPop: state is AccelerateClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const AccelerateBackPressed());
          },
          child: accelerateViewFor(
            context,
            state,
            unit: _unit,
            onEvent: bloc.add,
            openOrder: (orderId) => widget.openOrder(context, orderId),
          ),
        );
      },
    );
  }
}

/// The page of [state].
Widget accelerateViewFor(
  BuildContext context,
  AccelerateFlowState state, {
  required BitcoinUnit unit,
  required void Function(AccelerateFlowEvent event) onEvent,
  required void Function(String orderId) openOrder,
}) {
  final title = context.loc.buyConfirmExpressWithdrawal;
  void onBack() => onEvent(const AccelerateBackPressed());
  FlowAction back() => FlowAction(context.loc.cancel, onBack, primary: false);
  return switch (state) {
    AccelerateLoading(load: ContextFailed(:final problem)) => FlowStatusPage(
      title: title,
      onBack: onBack,
      message: problem.toTranslated(context),
      isError: true,
      actions: [
        FlowAction(
          context.loc.retry,
          () => onEvent(const AccelerateRetryPressed()),
        ),
        back(),
      ],
    ),
    AccelerateLoading() => FlowStatusPage(
      title: title,
      onBack: onBack,
      busy: true,
    ),
    AccelerateReady(:final quote) => AccelerateFeePage(
      quote: quote,
      unit: unit,
      onEvent: onEvent,
    ),
    AccelerateConfirming(:final quote, :final confirm) => switch (confirm) {
      ConfirmWriteRefused(:final refusal) => AccelerateFeePage(
        quote: quote,
        unit: unit,
        problem: refusal.toTranslated(context),
        onEvent: onEvent,
      ),
      ConfirmFailed(:final problem) => AccelerateFeePage(
        quote: quote,
        unit: unit,
        problem: problem.toTranslated(context),
        onEvent: onEvent,
      ),
      ConfirmUnverified(:final problem) => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.exchangeStepUnverified,
        message: problem.toTranslated(context),
        isError: true,
        actions: [
          FlowAction(
            context.loc.exchangeStepCheckAgain,
            () => onEvent(const AccelerateRetryPressed()),
          ),
          FlowAction(
            context.loc.exchangePaymentSentLeave,
            () => onEvent(const AccelerateBackPressed()),
            primary: false,
          ),
        ],
      ),
      ConfirmVerifying() => FlowStatusPage(
        title: title,
        onBack: onBack,
        message: context.loc.exchangeStepVerifying,
        busy: true,
      ),
      ConfirmConfirming() ||
      ConfirmConfirmed() ||
      ConfirmSessionEnded() ||
      ConfirmLeft() => AccelerateFeePage(
        quote: quote,
        unit: unit,
        busy: true,
        onEvent: onEvent,
      ),
    },
    AccelerateDone(:final order) => BullSuccessScreen(
      title: context.loc.buyConfirmTitle,
      headline: context.loc.buyBitcoinSent,
      message: Text(context.loc.buyThatWasFast),
      onClose: () => onEvent(const AccelerateDonePressed()),
      actions: [
        BullButton.secondary(
          label: context.loc.buyViewDetails,
          onPressed: () => openOrder(order.orderId),
        ),
      ],
    ),
    AccelerateSessionEnded() => FlowStatusPage(
      title: title,
      onBack: onBack,
      message: context.loc.exchangeFlowSessionEnded,
      isError: true,
      actions: [
        FlowAction(
          context.loc.closeDialogButton,
          () => onEvent(const AccelerateDonePressed()),
        ),
      ],
    ),
    AccelerateClosed() => FlowStatusPage(
      title: title,
      onBack: onBack,
      busy: true,
    ),
  };
}

/// What the express payout costs, with Wait and Confirm express.
class AccelerateFeePage extends StatelessWidget {
  const AccelerateFeePage({
    super.key,
    required this.quote,
    required this.unit,
    required this.onEvent,
    this.problem,
    this.busy = false,
  });

  final AccelerateQuote quote;
  final BitcoinUnit unit;
  final void Function(AccelerateFlowEvent event) onEvent;
  final String? problem;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fee = quote.fee;
    final problem = this.problem;
    return Scaffold(
      appBar: AppBar(
        // The route can be opened with nothing under it: Back is the
        // flow's event, never implied.
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () => onEvent(const AccelerateBackPressed()),
        ),
        title: Text(context.loc.buyConfirmExpressWithdrawal),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(16),
              Text(
                context.loc.buyNetworkFeeExplanation,
                textAlign: TextAlign.center,
                style: context.bullType.body.copyWith(
                  color: context.appColors.text,
                ),
              ),
              const Gap(32),
              BullDetailsTable(
                items: [
                  BullDetailsTableItem(
                    label: context.loc.buyNetworkFees,
                    displayValue: unit == BitcoinUnit.sats
                        ? FormatAmount.sats(fee.sats)
                        : FormatAmount.btc(ConvertAmount.satsToBtc(fee.sats)),
                  ),
                  BullDetailsTableItem(
                    label: context.loc.buyEstimatedFeeValue,
                    displayValue: FormatAmount.fiat(
                      ConvertAmount.satsToFiat(fee.sats, fee.fiatPerBitcoin),
                      quote.order.payinCurrency,
                    ),
                  ),
                  BullDetailsTableItem(
                    label: context.loc.buyNetworkFeeRate,
                    displayValue:
                        '${fee.satPerVbyte.toStringAsFixed(2)} sat/vB',
                  ),
                  BullDetailsTableItem(
                    label: context.loc.buyConfirmationTime,
                    displayValue: context.loc.buyConfirmationTimeValue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (problem != null) ...[
                Text(
                  problem,
                  style: context.bullType.body.copyWith(
                    color: context.appColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
              ],
              if (busy)
                const Center(child: BullLoader.small())
              else
                BullButton.secondary(
                  label: context.loc.buyWaitForFreeWithdrawal,
                  onPressed: () => onEvent(const AccelerateBackPressed()),
                ),
              const Gap(16),
              BullButton.primary(
                label: context.loc.buyConfirmExpress,
                onPressed: busy
                    ? null
                    : () => onEvent(const AccelerateConfirmPressed()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
