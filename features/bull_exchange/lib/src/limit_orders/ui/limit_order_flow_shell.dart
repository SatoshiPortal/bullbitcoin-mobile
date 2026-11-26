import 'package:bull_exchange/src/default_wallets/ui/default_wallets_router.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_exchange/src/funding/fund_exchange_router.dart';
import 'package:bull_exchange/src/limit_orders/limit_orders_navigation.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_order_flow_bloc.dart';
import 'package:bull_exchange/src/limit_orders/ui/screens/limit_order_pages.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The limit-order flow's one screen: its page is a function of the flow
/// state, and Back (app bar, system) is an event the machine answers.
class LimitFlowShell extends StatelessWidget {
  const LimitFlowShell({super.key, required this.payoutField});

  final ExchangePayoutField payoutField;

  void _leave(BuildContext context, LimitClosed closed) {
    final created = closed.created;
    final result = created == null
        ? null
        : LimitOrderCreated(created.id, openDetails: closed.openDetails);
    if (context.canPop()) {
      context.pop(result);
    } else {
      BullExchangeNavigation.goToDashboard(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LimitFlowBloc, LimitFlowState>(
      listenWhen: (previous, current) =>
          current is LimitClosed && previous is! LimitClosed,
      listener: (context, state) {
        if (state is LimitClosed) _leave(context, state);
      },
      builder: (context, state) {
        final bloc = context.read<LimitFlowBloc>();
        return PopScope(
          canPop: state is LimitClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const LimitBackPressed());
          },
          child: limitPageFor(
            state,
            payoutField: payoutField,
            onEvent: bloc.add,
            onFund: () => context.pushReplacementNamed(
              FundExchangeRoute.fundExchange.name,
            ),
            onManageDefaultWallets: () =>
                DefaultWalletsNavigation.open(context),
            onOpenKyc: () => context
                .push<void>(BullExchangeNavigation.kycPath)
                .then((_) => bloc.add(const LimitKycReturned())),
          ),
        );
      },
    );
  }
}

/// The page of [state].
Widget limitPageFor(
  LimitFlowState state, {
  required ExchangePayoutField payoutField,
  required void Function(LimitFlowEvent event) onEvent,
  required VoidCallback onFund,
  required VoidCallback onManageDefaultWallets,
  required VoidCallback onOpenKyc,
}) {
  Widget status({
    String Function(BuildContext)? headline,
    String Function(BuildContext)? message,
    bool busy = false,
    bool isError = false,
    List<FlowAction> Function(BuildContext)? actions,
  }) => Builder(
    builder: (context) => FlowStatusPage(
      title: context.loc.limitOrdersTitle,
      onBack: () => onEvent(const LimitBackPressed()),
      headline: headline?.call(context),
      message: message?.call(context),
      busy: busy,
      isError: isError,
      actions: actions?.call(context) ?? const [],
    ),
  );
  FlowAction back(BuildContext context) => FlowAction(
    context.loc.cancel,
    () => onEvent(const LimitBackPressed()),
    primary: false,
  );
  FlowAction retry(BuildContext context) =>
      FlowAction(context.loc.retry, () => onEvent(const LimitRetryPressed()));

  return switch (state) {
    LimitLoading(load: ContextFailed(:final problem)) => status(
      message: (context) => problem.toTranslated(context),
      isError: true,
      actions: (context) => [retry(context), back(context)],
    ),
    LimitLoading() => status(busy: true),
    LimitNoFundedBalance() => LimitNoBalancePage(
      onEvent: onEvent,
      onFund: onFund,
    ),
    LimitIntro() => LimitIntroPage(onEvent: onEvent),
    LimitTarget(:final open, :final step) => switch (step) {
      TargetReady(:final target, :final switchProblem) => LimitTargetPage(
        open: open,
        target: target,
        loading: false,
        switchProblem: switchProblem,
        onEvent: onEvent,
      ),
      TargetLoading(kept: final kept?) => LimitTargetPage(
        open: open,
        target: kept,
        loading: true,
        onEvent: onEvent,
      ),
      TargetLoading() => status(busy: true),
      TargetFailed(:final problem) => status(
        message: (context) => problem.toTranslated(context),
        isError: true,
        actions: (context) => [retry(context), back(context)],
      ),
    },
    LimitDestination(:final open, :final pick) => LimitDestinationPage(
      open: open,
      pick: pick,
      payoutField: payoutField,
      onEvent: onEvent,
      onManageDefaultWallets: onManageDefaultWallets,
    ),
    LimitAmount(:final amount) => switch (amount) {
      final AmountEditing editing => LimitAmountPage(
        key: const ValueKey('limit-amount'),
        state: state,
        editing: editing,
        onEvent: onEvent,
      ),
      AmountKycDetour() => status(
        headline: (context) => context.loc.sellKycPendingTitle,
        message: (context) => context.loc.sellKycPendingDescription,
        actions: (context) => [
          FlowAction(context.loc.sellCompleteKYC, onOpenKyc),
          back(context),
        ],
      ),
      AmountNoMarket() ||
      AmountFundingDetour() ||
      AmountDone() ||
      AmountSessionRejected() => status(busy: true),
    },
    LimitReview(:final request, :final check) => LimitReviewPage(
      request: request,
      check: check,
      onEvent: onEvent,
    ),
    LimitCreating(:final request, :final rate, :final confirm) =>
      LimitReviewPage(
        request: request,
        check: ReviewLive(rate),
        confirm: confirm,
        onEvent: onEvent,
      ),
    LimitDone(:final order) => LimitDonePage(order: order, onEvent: onEvent),
    LimitSessionEnded() => status(
      message: (context) => context.loc.exchangeFlowSessionEnded,
      actions: (context) => [
        FlowAction(
          context.loc.closeDialogButton,
          () => onEvent(const LimitDonePressed()),
        ),
      ],
    ),
    LimitClosed() => status(),
  };
}
