import 'dart:async';

import 'package:bull_exchange/src/dca/presentation/dca_flow.dart';
import 'package:bull_exchange/src/dca/presentation/dca_flow_bloc.dart';
import 'package:bull_exchange/src/dca/ui/screens/dca_payout_page.dart';
import 'package:bull_exchange/src/dca/ui/screens/dca_review_page.dart';
import 'package:bull_exchange/src/dca/ui/screens/dca_setup_page.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_exchange/src/funding/fund_exchange_router.dart';
import 'package:bull_exchange/src/session/exchange_session_scope.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSuccessScreen;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

/// The DCA flow's one screen: its page stack is a function of the flow
/// state and Back is an event the machine answers.
class DcaFlowShell extends StatelessWidget {
  const DcaFlowShell({super.key, required this.payoutField});

  final ExchangePayoutField payoutField;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DcaFlowBloc, DcaFlowState>(
      listenWhen: (previous, current) =>
          (current is DcaClosed && previous is! DcaClosed) ||
          (current is DcaDone && previous is! DcaDone),
      listener: (context, state) {
        switch (state) {
          case DcaDone():
            unawaited(ExchangeSessionScope.refresh(context));
          case DcaClosed():
            if (context.canPop()) {
              context.pop();
            } else {
              BullExchangeNavigation.goToDashboard(context);
            }
          case DcaLoading() ||
              DcaSetup() ||
              DcaPayoutPick() ||
              DcaReview() ||
              DcaConfirming() ||
              DcaSessionEnded():
            break;
        }
      },
      builder: (context, state) {
        final bloc = context.read<DcaFlowBloc>();
        final pages = dcaPagesFor(
          state,
          payoutField: payoutField,
          onEvent: bloc.add,
        );
        return PopScope(
          canPop: state is DcaClosed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const DcaBackPressed());
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              if (identical(bloc.state, state) && page.key == pages.last.key) {
                bloc.add(const DcaBackPressed());
              }
            },
          ),
        );
      },
    );
  }
}

const _setupKey = ValueKey('dca-setup');
const _detourKey = ValueKey('dca-detour');
const _payoutKey = ValueKey('dca-payout');
const _reviewKey = ValueKey('dca-review');
const _confirmKey = ValueKey('dca-confirm');
const _endKey = ValueKey('dca-end');

/// The page stack of [state].
List<Page<void>> dcaPagesFor(
  DcaFlowState state, {
  required ExchangePayoutField payoutField,
  required void Function(DcaFlowEvent event) onEvent,
}) {
  Page<void> page(LocalKey key, Widget child) =>
      MaterialPage(key: key, child: child);
  Page<void> status(
    LocalKey key, {
    String Function(BuildContext)? headline,
    String Function(BuildContext)? message,
    bool busy = false,
    bool isError = false,
    List<FlowAction> Function(BuildContext)? actions,
  }) => page(
    key,
    Builder(
      builder: (context) => FlowStatusPage(
        title: context.loc.dcaSetupTitle,
        headline: headline?.call(context),
        message: message?.call(context),
        busy: busy,
        isError: isError,
        actions: actions?.call(context) ?? const [],
      ),
    ),
  );
  FlowAction back(BuildContext context) => FlowAction(
    context.loc.cancel,
    () => onEvent(const DcaBackPressed()),
    primary: false,
  );

  List<Page<void>> setupPages(DcaSetup setup) => [
    page(_setupKey, DcaSetupPage(setup: setup, onEvent: onEvent)),
    ...switch (setup.amount) {
      AmountFundingDetour() => [
        status(
          _detourKey,
          headline: (context) => context.loc.dcaSetupInsufficientBalance,
          message: (context) => context.loc.dcaSetupInsufficientBalanceMessage,
          actions: (context) => [
            FlowAction(context.loc.dcaSetupFundAccount, () {
              unawaited(
                context
                    .push<void>(FundExchangeRoute.fundExchange.path)
                    .then((_) => onEvent(const DcaFundingReturned())),
              );
            }),
            back(context),
          ],
        ),
      ],
      AmountKycDetour() => [
        status(
          _detourKey,
          headline: (context) => context.loc.buyInputKycPending,
          message: (context) => context.loc.buyInputKycMessage,
          actions: (context) => [
            FlowAction(context.loc.buyInputCompleteKyc, () {
              unawaited(
                context
                    .push<void>(BullExchangeNavigation.kycPath)
                    .then((_) => onEvent(const DcaKycReturned())),
              );
            }),
            back(context),
          ],
        ),
      ],
      AmountEditing() ||
      AmountNoMarket() ||
      AmountDone() ||
      AmountSessionRejected() => const <Page<void>>[],
    },
  ];
  List<Page<void>> payoutPages(DcaPayoutPick pick) => [
    ...setupPages(dcaSetupUnder(pick.open, pick.amount, pick.frequency)),
    page(
      _payoutKey,
      DcaPayoutPage(pick: pick, payoutField: payoutField, onEvent: onEvent),
    ),
  ];
  List<Page<void>> reviewBase(DcaOpen open, DcaPlan plan) =>
      payoutPages(DcaPayoutPick(open, plan.amount, plan.frequency));

  return switch (state) {
    DcaLoading(load: ContextFailed(:final problem)) => [
      status(
        _setupKey,
        message: (context) => problem.toTranslated(context),
        isError: true,
        actions: (context) => [
          FlowAction(context.loc.retry, () => onEvent(const DcaRetryPressed())),
          back(context),
        ],
      ),
    ],
    DcaLoading() => [status(_setupKey, busy: true)],
    final DcaSetup setup => setupPages(setup),
    final DcaPayoutPick pick => payoutPages(pick),
    DcaReview(:final open, :final plan) => [
      ...reviewBase(open, plan),
      page(_reviewKey, DcaReviewPage(plan: plan, onEvent: onEvent)),
    ],
    DcaConfirming(:final open, :final plan, :final confirm) => [
      ...reviewBase(open, plan),
      switch (confirm) {
        ConfirmWriteRefused(:final refusal) => page(
          _reviewKey,
          Builder(
            builder: (context) => DcaReviewPage(
              plan: plan,
              onEvent: onEvent,
              problem: refusal.toTranslated(context),
            ),
          ),
        ),
        ConfirmFailed(:final problem) => page(
          _reviewKey,
          Builder(
            builder: (context) => DcaReviewPage(
              plan: plan,
              onEvent: onEvent,
              problem: problem.toTranslated(context),
            ),
          ),
        ),
        ConfirmUnverified(:final problem) => status(
          _confirmKey,
          headline: (context) => context.loc.exchangeStepUnverified,
          message: (context) => problem.toTranslated(context),
          isError: true,
          actions: (context) => [
            FlowAction(
              context.loc.exchangeStepCheckAgain,
              () => onEvent(const DcaRetryPressed()),
            ),
            FlowAction(
              context.loc.exchangePaymentSentLeave,
              () => onEvent(const DcaBackPressed()),
              primary: false,
            ),
          ],
        ),
        ConfirmVerifying() => status(
          _confirmKey,
          message: (context) => context.loc.exchangeStepVerifying,
          busy: true,
        ),
        ConfirmConfirming() ||
        ConfirmConfirmed() ||
        ConfirmSessionEnded() ||
        ConfirmLeft() => page(
          _reviewKey,
          DcaReviewPage(plan: plan, onEvent: onEvent, busy: true),
        ),
      },
    ],
    DcaDone(:final plan) => [
      page(
        _endKey,
        Builder(
          builder: (context) => _DonePage(plan: plan, onEvent: onEvent),
        ),
      ),
    ],
    DcaSessionEnded() => [
      status(
        _endKey,
        message: (context) => context.loc.exchangeFlowSessionEnded,
        isError: true,
        actions: (context) => [
          FlowAction(
            context.loc.closeDialogButton,
            () => onEvent(const DcaDonePressed()),
          ),
        ],
      ),
    ],
    DcaClosed() => [status(_endKey, busy: true)],
  };
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.plan, required this.onEvent});

  final DcaPlan plan;
  final void Function(DcaFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    final amount = FormatAmount.fiat(plan.fiat, plan.currency.code);
    void close() => onEvent(const DcaDonePressed());
    return BullSuccessScreen(
      title: context.loc.dcaSetupTitle,
      headline: context.loc.dcaSuccessTitle,
      onClose: close,
      message: Text(switch (plan.frequency) {
        DcaBuyFrequency.hourly => context.loc.dcaSuccessMessageHourly(amount),
        DcaBuyFrequency.daily => context.loc.dcaSuccessMessageDaily(amount),
        DcaBuyFrequency.weekly => context.loc.dcaSuccessMessageWeekly(amount),
        DcaBuyFrequency.monthly => context.loc.dcaSuccessMessageMonthly(amount),
      }),
      actions: [
        BullButton.secondary(
          label: context.loc.dcaBackToHomeButton,
          onPressed: close,
        ),
      ],
    );
  }
}
