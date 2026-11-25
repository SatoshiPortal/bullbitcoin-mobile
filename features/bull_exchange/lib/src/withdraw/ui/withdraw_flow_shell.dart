import 'dart:async';

import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/payout/ui/payout_requirement_view.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bull_exchange/src/recipients/public/recipient_pick_screen.dart';
import 'package:bull_exchange/src/session/exchange_session_scope.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow_bloc.dart';
import 'package:bull_exchange/src/withdraw/ui/screens/withdraw_amount_page.dart';
import 'package:bull_exchange/src/withdraw/ui/screens/withdraw_review_page.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSuccessScreen;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The withdraw flow's one screen: its page stack is a function of the flow
/// state, and Back (app bar, system, a removed page) is an event the machine
/// answers (WD-2, WD-4: no page holds a bloc of its own or reads
/// `state.extra`).
class WithdrawFlowShell extends StatefulWidget {
  const WithdrawFlowShell({
    super.key,
    required this.brandAsset,
    required this.openOrder,
  });

  final String brandAsset;
  final void Function(BuildContext, String) openOrder;

  @override
  State<WithdrawFlowShell> createState() => _WithdrawFlowShellState();
}

class _WithdrawFlowShellState extends State<WithdrawFlowShell> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: () => _visible(true),
    onHide: () => _visible(false),
  );

  void _visible(bool visible) {
    final bloc = context.read<WithdrawFlowBloc>();
    if (!bloc.isClosed) bloc.add(WithdrawVisibilityChanged(visible: visible));
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WithdrawFlowBloc, WithdrawFlowState>(
      listenWhen: (previous, current) =>
          (current is WithdrawClosed && previous is! WithdrawClosed) ||
          (current is WithdrawDone && previous is! WithdrawDone),
      listener: (context, state) {
        switch (state) {
          case WithdrawDone():
            // WD-5: the balances changed.
            unawaited(ExchangeSessionScope.refresh(context));
          case WithdrawClosed():
            if (context.canPop()) {
              context.pop();
            } else {
              BullExchangeNavigation.goToDashboard(context);
            }
          case WithdrawLoading() ||
              WithdrawAmount() ||
              WithdrawRecipient() ||
              WithdrawRequirements() ||
              WithdrawOrdering() ||
              WithdrawReview() ||
              WithdrawConfirming() ||
              WithdrawSessionEnded():
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<WithdrawFlowBloc>();
        final pages = withdrawPagesFor(
          state,
          brandAsset: widget.brandAsset,
          onEvent: bloc.add,
          openOrder: (orderId) => widget.openOrder(context, orderId),
        );
        return PopScope(
          canPop: state is WithdrawClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const WithdrawBackPressed());
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              // Only a page the user removed is Back; pages a new state
              // drops are not the top page of the state that built them.
              if (identical(bloc.state, state) && page.key == pages.last.key) {
                bloc.add(const WithdrawBackPressed());
              }
            },
          ),
        );
      },
    );
  }
}

const _amountKey = ValueKey('withdraw-amount');
const _recipientKey = ValueKey('withdraw-recipient');
const _requirementKey = ValueKey('withdraw-requirement');
const _orderingKey = ValueKey('withdraw-ordering');
const _reviewKey = ValueKey('withdraw-review');
const _endKey = ValueKey('withdraw-end');

/// The page stack of [state].
List<Page<void>> withdrawPagesFor(
  WithdrawFlowState state, {
  required String brandAsset,
  required void Function(WithdrawFlowEvent event) onEvent,
  required void Function(String orderId) openOrder,
}) {
  Page<void> page(LocalKey key, Widget child) =>
      MaterialPage(key: key, child: child);
  Page<void> status(
    LocalKey key,
    String Function(BuildContext) title, {
    String Function(BuildContext)? message,
    bool busy = false,
    bool isError = false,
    List<FlowAction> Function(BuildContext)? actions,
  }) => page(
    key,
    Builder(
      builder: (context) => FlowStatusPage(
        title: title(context),
        onBack: () => onEvent(const WithdrawBackPressed()),
        message: message?.call(context),
        busy: busy,
        isError: isError,
        actions: actions?.call(context) ?? const [],
      ),
    ),
  );
  String title(BuildContext context) => context.loc.withdrawAmountTitle;
  FlowAction back(BuildContext context) => FlowAction(
    context.loc.cancel,
    () => onEvent(const WithdrawBackPressed()),
    primary: false,
  );
  FlowAction retry(BuildContext context) => FlowAction(
    context.loc.retry,
    () => onEvent(const WithdrawRetryPressed()),
  );

  List<Page<void>> amountPages(WithdrawOpen open, AmountEntryState amount) =>
      switch (amount) {
        final AmountEditing editing => [
          page(
            _amountKey,
            WithdrawAmountPage(open: open, editing: editing, onEvent: onEvent),
          ),
        ],
        AmountNoMarket() => [
          status(
            _amountKey,
            title,
            message: (context) => context.loc.withdrawNoFundedBalance,
            actions: (context) => [back(context)],
          ),
        ],
        AmountKycDetour() ||
        AmountFundingDetour() ||
        AmountDone() ||
        AmountSessionRejected() => [status(_amountKey, title, busy: true)],
      };
  List<Page<void>> pickPages(
    WithdrawOpen open,
    EnteredAmount amount, {
    Recipient? refused,
  }) => [
    ...amountPages(
      open,
      AmountEditing(
        draft: amount.draft,
        quote: RateReady(amount.rate),
        context: open.context.amountContext,
      ),
    ),
    page(
      _recipientKey,
      Builder(
        builder: (context) => RecipientPickScreen(
          filter: withdrawRecipientFilter(amount.market),
          onPicked: (recipient) => onEvent(WithdrawRecipientPicked(recipient)),
          onBack: () => onEvent(const WithdrawBackPressed()),
          problem: refused == null
              ? null
              : const RecipientsSelectionFailure().toTranslated(context),
        ),
      ),
    ),
  ];

  return switch (state) {
    WithdrawLoading(load: ContextFailed(:final problem)) => [
      status(
        _amountKey,
        title,
        message: (context) => problem.toTranslated(context),
        isError: true,
        actions: (context) => [retry(context), back(context)],
      ),
    ],
    WithdrawLoading() => [status(_amountKey, title, busy: true)],
    WithdrawAmount(:final open, :final amount) => amountPages(open, amount),
    WithdrawRecipient(:final open, :final amount, :final refused) => pickPages(
      open,
      amount,
      refused: refused,
    ),
    WithdrawRequirements(:final open, :final amount, :final requirements) => [
      ...pickPages(open, amount),
      page(
        _requirementKey,
        Builder(
          builder: (context) => PayoutRequirementView(
            title: title(context),
            running: requirements,
            onEvent: (event) => onEvent(WithdrawRequirementsChanged(event)),
            onBack: () => onEvent(const WithdrawBackPressed()),
          ),
        ),
      ),
    ],
    WithdrawOrdering(:final open, :final amount, :final order) => [
      ...pickPages(open, amount),
      switch (order) {
        OrderWriteRefused(:final refusal) => status(
          _orderingKey,
          title,
          message: (context) => refusal.toTranslated(context),
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        OrderCreateFailed(:final problem) => status(
          _orderingKey,
          title,
          message: (context) => problem.toTranslated(context),
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        OrderUnverified(:final problem) => status(
          _orderingKey,
          title,
          message: (context) =>
              '${context.loc.exchangeStepUnverified}\n'
              '${problem.toTranslated(context)}',
          isError: true,
          actions: (context) => [retry(context), back(context)],
        ),
        OrderVerifying() => status(
          _orderingKey,
          title,
          message: (context) => context.loc.exchangeStepVerifying,
          busy: true,
        ),
        OrderCreating() ||
        OrderQuoted() ||
        OrderPlaced() ||
        OrderCommitted() ||
        OrderSessionEnded() ||
        OrderAmountRefused() ||
        OrderLeft() => status(_orderingKey, title, busy: true),
      },
    ],
    WithdrawReview(:final recipient, :final order) => [
      page(
        _reviewKey,
        WithdrawReviewPage(
          brandAsset: brandAsset,
          recipient: recipient,
          order: order,
          confirm: null,
          onEvent: onEvent,
        ),
      ),
    ],
    WithdrawConfirming(:final recipient, :final order, :final confirm) => [
      page(
        _reviewKey,
        WithdrawReviewPage(
          brandAsset: brandAsset,
          recipient: recipient,
          order: order,
          confirm: confirm,
          onEvent: onEvent,
        ),
      ),
    ],
    WithdrawDone(:final order) => [
      page(
        _endKey,
        Builder(
          builder: (context) => BullSuccessScreen(
            title: context.loc.withdrawAmountTitle,
            headline: context.loc.withdrawSuccessTitle,
            onClose: () => onEvent(const WithdrawDonePressed()),
            actions: [
              BullButton.secondary(
                label: context.loc.withdrawSuccessOrderDetails,
                onPressed: () => openOrder(order.orderId),
              ),
            ],
          ),
        ),
      ),
    ],
    WithdrawSessionEnded() => [
      status(
        _endKey,
        title,
        message: (context) => context.loc.exchangeFlowSessionEnded,
        actions: (context) => [
          FlowAction(
            context.loc.closeDialogButton,
            () => onEvent(const WithdrawDonePressed()),
          ),
        ],
      ),
    ],
    WithdrawClosed() => [status(_endKey, title)],
  };
}
