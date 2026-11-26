import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/funding/domain/usecases/open_funding_payment_link_usecase.dart';
import 'package:bull_exchange/src/funding/presentation/fund_exchange_failure_l10n.dart';
import 'package:bull_exchange/src/funding/domain/fund_flow.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow_bloc.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow_l10n.dart';
import 'package:bull_exchange/src/funding/ui/screens/fund_cop_input_page.dart';
import 'package:bull_exchange/src/funding/ui/screens/fund_instructions_page.dart';
import 'package:bull_exchange/src/funding/ui/screens/fund_methods_page.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_consent_sheet.dart';
import 'package:bull_exchange/src/recipients/ui/screens/virtual_iban_funding_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInfoCard;
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

/// The fund flow's one screen: its page stack is a function of the flow
/// state, and Back (app bar, system, a dismissed sheet) is an event the
/// machine answers (FUND-9: no page holds a bloc of its own).
class FundFlowShell extends StatelessWidget {
  const FundFlowShell({super.key, required this.openLink});

  final OpenFundingPaymentLinkUsecase openLink;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FundFlowBloc, FundFlowState>(
      listenWhen: (previous, current) =>
          current is FundClosed && previous is! FundClosed,
      listener: (context, _) {
        if (context.canPop()) {
          context.pop();
        } else {
          BullExchangeNavigation.goToDashboard(context);
        }
      },
      builder: (context, state) {
        final bloc = context.read<FundFlowBloc>();
        final pages = fundPagesFor(
          state,
          onEvent: bloc.add,
          onOpenLink: (link) => _openLink(context, openLink, link),
        );
        return PopScope(
          canPop: switch (state) {
            FundLoading() ||
            FundRestricted() ||
            FundPicking() ||
            FundSessionEnded() ||
            FundClosed() => true,
            FundConsenting() ||
            FundInstitutions() ||
            FundCopInput() ||
            FundVirtualIban() ||
            FundFetching() ||
            FundShowing() ||
            FundRefused() ||
            FundFetchFailed() => false,
          },
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const FundBackPressed());
          },
          child: Navigator(
            pages: pages,
            onDidRemovePage: (page) {
              // Only a page the user removed is Back; pages a new state
              // drops are not the top page of the state that built them.
              if (identical(bloc.state, state) && page.key == pages.last.key) {
                bloc.add(const FundBackPressed());
              }
            },
          ),
        );
      },
    );
  }

  static Future<void> _openLink(
    BuildContext context,
    OpenFundingPaymentLinkUsecase openLink,
    Uri link,
  ) async {
    final result = await openLink.execute(
      OpenFundingPaymentLinkCommand(paymentLink: link.toString()),
    );
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.toTranslated(context))));
    }
  }
}

const _methodsKey = ValueKey('fund-methods');
const _consentKey = ValueKey('fund-consent');
const _copInputKey = ValueKey('fund-cop-input');
const _virtualIbanKey = ValueKey('fund-virtual-iban');
const _instructionsKey = ValueKey('fund-instructions');
const _problemKey = ValueKey('fund-problem');
const _endKey = ValueKey('fund-end');

/// The page stack of [state].
List<Page<void>> fundPagesFor(
  FundFlowState state, {
  required void Function(FundFlowEvent event) onEvent,
  required void Function(Uri link) onOpenLink,
}) {
  Page<void> methods(FundMethodsView view) => MaterialPage(
    key: _methodsKey,
    child: FundMethodsPage(view: view, onEvent: onEvent),
  );
  Page<void> railMethods(
    FundOpen open,
    FundingRail rail, {
    bool busy = false,
  }) => methods(
    FundMethodsPicking(
      rail.jurisdiction,
      open.account.railsIn(rail.jurisdiction),
      busy: busy,
    ),
  );
  Page<void> copInput(
    FundOpen open,
    List<FundingInstitution> institutions, {
    required bool busy,
  }) => MaterialPage(
    key: _copInputKey,
    child: FundCopInputPage(
      institutions: institutions,
      senderName: '${open.account.firstName} ${open.account.lastName}'
          .toUpperCase(),
      busy: busy,
      onEvent: onEvent,
    ),
  );
  Page<void> virtualIban() => MaterialPage(
    key: _virtualIbanKey,
    child: VirtualIbanFundingScreen(
      onUseRegularSepa: () => onEvent(const FundRegularSepaChosen()),
      onDone: () => onEvent(const FundDonePressed()),
      onBack: () => onEvent(const FundBackPressed()),
    ),
  );
  List<Page<void>> origin(
    FundOpen open,
    FundingRequest request,
    FundOrigin from, {
    required bool busy,
  }) => switch (from) {
    FundFromPicking() => [railMethods(open, request.rail, busy: busy)],
    FundFromCopInput(:final institutions) => [
      railMethods(open, request.rail),
      copInput(open, institutions, busy: busy),
    ],
    FundFromVirtualIban() => [
      railMethods(open, const ConfidentialSepaFundingRail()),
      virtualIban(),
    ],
  };

  return switch (state) {
    FundLoading(:final load) => [
      methods(
        FundMethodsLoading(switch (load) {
          ContextFailed(:final problem) => problem,
          ContextLoading() ||
          ContextReady() ||
          ContextSessionRejected() => null,
        }),
      ),
    ],
    FundRestricted() => [methods(const FundMethodsRestricted())],
    FundPicking(:final jurisdiction, :final rails) => [
      methods(FundMethodsPicking(jurisdiction, rails)),
    ],
    FundConsenting(:final open, :final rail) => [
      railMethods(open, rail, busy: true),
      _SheetPage(
        key: _consentKey,
        child: _ConsentSheetHost(onEvent: onEvent),
      ),
    ],
    FundInstitutions(:final open, :final load) => [
      methods(
        FundMethodsPicking(
          const CopBankTransferFundingRail().jurisdiction,
          open.account.railsIn(const CopBankTransferFundingRail().jurisdiction),
          busy: load is ContextLoading,
          problem: switch (load) {
            ContextFailed(:final problem) => problem,
            ContextLoading() ||
            ContextReady() ||
            ContextSessionRejected() => null,
          },
        ),
      ),
    ],
    FundCopInput(:final open, :final institutions) => [
      railMethods(open, const CopBankTransferFundingRail()),
      copInput(open, institutions, busy: false),
    ],
    FundVirtualIban(:final open) => [
      railMethods(open, const ConfidentialSepaFundingRail()),
      virtualIban(),
    ],
    FundFetching(:final open, :final request, origin: final from) => origin(
      open,
      request,
      from,
      busy: true,
    ),
    FundShowing(
      :final open,
      :final request,
      origin: final from,
      :final instructions,
    ) =>
      [
        ...origin(open, request, from, busy: false),
        MaterialPage(
          key: _instructionsKey,
          child: FundInstructionsPage(
            rail: request.rail,
            instructions: instructions,
            onOpenLink: onOpenLink,
            onEvent: onEvent,
          ),
        ),
      ],
    FundRefused(
      :final open,
      :final request,
      origin: final from,
      :final reason,
    ) =>
      [
        ...origin(open, request, from, busy: false),
        MaterialPage(
          key: _problemKey,
          child: Builder(
            builder: (context) => FundProblemPage(
              title: reason.title(context),
              message: reason.message(context),
              onEvent: onEvent,
            ),
          ),
        ),
      ],
    FundFetchFailed(
      :final open,
      :final request,
      origin: final from,
      problem: final readProblem,
    ) =>
      [
        ...origin(open, request, from, busy: false),
        MaterialPage(
          key: _problemKey,
          child: Builder(
            builder: (context) => FundProblemPage(
              title: null,
              message: fundReadProblemMessage(
                context,
                readProblem,
                otherwise: context.loc.fundExchangeErrorLoadingDetails,
              ),
              canRetry: true,
              onEvent: onEvent,
            ),
          ),
        ),
      ],
    FundSessionEnded() => [
      MaterialPage(
        key: _endKey,
        child: _SessionEndedPage(onEvent: onEvent),
      ),
    ],
    FundClosed() => const [
      MaterialPage(
        key: _endKey,
        child: Scaffold(body: SizedBox.shrink()),
      ),
    ],
  };
}

/// The consent sheet as a page, so it is part of the state's page stack.
class _SheetPage extends Page<void> {
  const _SheetPage({required super.key, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => ModalBottomSheetRoute<void>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    builder: (_) => child,
  );
}

/// The sheet's route is built once; its content follows the gate.
class _ConsentSheetHost extends StatelessWidget {
  const _ConsentSheetHost({required this.onEvent});

  final void Function(FundFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<FundFlowBloc, FundFlowState>(
        builder: (context, state) => switch (state) {
          FundConsenting(:final gate) => FundConsentSheet(
            gate: gate,
            onEvent: onEvent,
          ),
          FundLoading() ||
          FundRestricted() ||
          FundPicking() ||
          FundInstitutions() ||
          FundCopInput() ||
          FundVirtualIban() ||
          FundFetching() ||
          FundShowing() ||
          FundRefused() ||
          FundFetchFailed() ||
          FundSessionEnded() ||
          FundClosed() => const SizedBox.shrink(),
        },
      );
}

class _SessionEndedPage extends StatelessWidget {
  const _SessionEndedPage({required this.onEvent});

  final void Function(FundFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: BackButton(onPressed: () => onEvent(const FundBackPressed())),
      title: Text(context.loc.fundExchangeTitle),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullInfoCard(
              description: context.loc.fundExchangeSessionEnded,
              bgColor: context.appColors.error.withValues(alpha: 0.1),
              tagColor: context.appColors.primary,
            ),
            const SizedBox(height: 24.0),
            BullButton.primary(
              label: context.loc.fundExchangeDoneButton,
              onPressed: () => onEvent(const FundDonePressed()),
            ),
          ],
        ),
      ),
    ),
  );
}
