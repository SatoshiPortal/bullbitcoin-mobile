import 'dart:async';

import 'package:bull_exchange/src/autobuy/presentation/autobuy_bloc.dart';
import 'package:bull_exchange/src/autobuy/presentation/autobuy_flow.dart';
import 'package:bull_exchange/src/default_wallets/default_wallets_payout_fields.dart';
import 'package:bull_exchange/src/default_wallets/ui/widgets/default_wallets_editor.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullButton,
        BullInfoCard,
        BullShimmerLine,
        BullSpacing,
        Gap,
        BullTypographyX;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the AutoBuy pages need from the host.
typedef AutoBuyPageHost = ({
  Exchange exchange,
  DefaultWalletsPayoutFields payoutFields,
  Widget Function(BuildContext, String) addressViewer,
  Uri terms,
});

/// The AutoBuy flow's one screen: its page is a function of the flow state,
/// Back is an event. The flow leaves once AutoBuy is verified active.
class AutoBuyFlowShell extends StatelessWidget {
  const AutoBuyFlowShell({super.key, required this.host});

  final AutoBuyPageHost host;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AutoBuyFlowBloc, AutoBuyFlowState>(
      listenWhen: (previous, current) =>
          (current is AutoBuyClosed || current is AutoBuyDone) &&
          previous.runtimeType != current.runtimeType,
      listener: (context, state) {
        if (context.canPop()) {
          context.pop();
        } else {
          BullExchangeNavigation.goToDashboard(context);
        }
      },
      builder: (context, state) {
        final bloc = context.read<AutoBuyFlowBloc>();
        return PopScope(
          canPop: state is AutoBuyClosed || state is AutoBuyDone,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const AutoBuyBackPressed());
          },
          child: autoBuyPageFor(
            state,
            host: host,
            onEvent: bloc.add,
            onOpenKyc: () => unawaited(
              context
                  .push<void>(BullExchangeNavigation.kycPath)
                  .then((_) => bloc.add(const AutoBuyKycReturned())),
            ),
          ),
        );
      },
    );
  }
}

/// The page of [state].
Widget autoBuyPageFor(
  AutoBuyFlowState state, {
  required AutoBuyPageHost host,
  required void Function(AutoBuyFlowEvent event) onEvent,
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
      title: context.loc.autoBuyTitle,
      onBack: () => onEvent(const AutoBuyBackPressed()),
      headline: headline?.call(context),
      message: message?.call(context),
      busy: busy,
      isError: isError,
      actions: actions?.call(context) ?? const [],
    ),
  );
  FlowAction back(BuildContext context) => FlowAction(
    context.loc.cancel,
    () => onEvent(const AutoBuyBackPressed()),
    primary: false,
  );
  return switch (state) {
    AutoBuyLoading(load: ContextFailed(:final problem)) => status(
      message: (context) => problem.toTranslated(context),
      isError: true,
      actions: (context) => [
        FlowAction(
          context.loc.retry,
          () => onEvent(const AutoBuyRetryPressed()),
        ),
        back(context),
      ],
    ),
    AutoBuyLoading() => _AutoBuyPage(
      title: (context) => context.loc.autoBuyTitle,
      onEvent: onEvent,
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullShimmerLine(height: 20),
          BullShimmerLine(height: 20, width: 200),
          BullShimmerLine(height: 20),
        ],
      ),
    ),
    AutoBuyIntro(:final gate) => _AutoBuyPage(
      title: (context) => context.loc.autoBuyTitle,
      onEvent: onEvent,
      body: _IntroStep(
        restricted: switch (gate) {
          RestrictionAllowed() => false,
          RestrictionRestricted() || RestrictionLeft() => true,
        },
        terms: host.terms,
        onEvent: onEvent,
      ),
    ),
    AutoBuyKyc() => status(
      headline: (context) => context.loc.sellKycPendingTitle,
      message: (context) => context.loc.sellKycPendingDescription,
      actions: (context) => [
        FlowAction(context.loc.sellCompleteKYC, onOpenKyc),
        back(context),
      ],
    ),
    AutoBuyWallets() => _AutoBuyPage(
      title: (context) => context.loc.exchangeBitcoinWalletsTitle,
      onEvent: onEvent,
      body: DefaultWalletsEditor(
        exchange: host.exchange,
        payoutFields: host.payoutFields,
        footerBuilder: (context, wallets, status) => BullButton.primary(
          label: context.loc.continueButton,
          onPressed:
              (!wallets.hasAnyWallet || status.isEditing || status.isSaving)
              ? null
              : () => onEvent(AutoBuyWalletsContinued(wallets)),
        ),
      ),
    ),
    AutoBuyReview(:final wallets, :final alreadyActive) => _AutoBuyPage(
      title: (context) => context.loc.autoBuyConfirmTitle,
      onEvent: onEvent,
      body: _ReviewStep(
        wallets: wallets,
        viewer: host.addressViewer,
        footer: (context) => alreadyActive
            ? [
                Text(context.loc.autoBuyAlreadyActive),
                const Gap(BullSpacing.md),
                BullButton.primary(
                  label: context.loc.doneButton,
                  onPressed: () => onEvent(const AutoBuyDonePressed()),
                ),
              ]
            : [
                BullButton.primary(
                  label: context.loc.autoBuyActivate,
                  onPressed: () => onEvent(const AutoBuyActivatePressed()),
                ),
              ],
      ),
    ),
    AutoBuyActivating(:final wallets, :final confirm) => _AutoBuyPage(
      title: (context) => context.loc.autoBuyConfirmTitle,
      onEvent: onEvent,
      body: _ReviewStep(
        wallets: wallets,
        viewer: host.addressViewer,
        footer: (context) => switch (confirm) {
          ConfirmConfirming() ||
          ConfirmConfirmed() ||
          ConfirmSessionEnded() ||
          ConfirmLeft() => [
            const BullShimmerLine(height: 52, padding: EdgeInsets.zero),
          ],
          ConfirmVerifying() => [
            Text(context.loc.exchangeStepVerifying),
            const Gap(BullSpacing.md),
            const BullShimmerLine(height: 52, padding: EdgeInsets.zero),
          ],
          ConfirmWriteRefused(:final refusal) => [
            _error(context, refusal.toTranslated(context)),
            BullButton.primary(
              label: context.loc.retry,
              onPressed: () => onEvent(const AutoBuyRetryPressed()),
            ),
          ],
          ConfirmFailed(:final problem) => [
            _error(context, switch (problem) {
              WriteProblemNotApplied() => context.loc.autoBuyUpdateError,
              WriteProblemRefused() ||
              WriteProblemNotSent() => problem.toTranslated(context),
            }),
            BullButton.primary(
              label: context.loc.autoBuyActivate,
              onPressed: () => onEvent(const AutoBuyActivatePressed()),
            ),
          ],
          ConfirmUnverified(:final problem) => [
            _error(
              context,
              '${context.loc.exchangeStepUnverified}\n'
              '${problem.toTranslated(context)}',
            ),
            BullButton.primary(
              label: context.loc.exchangeStepCheckAgain,
              onPressed: () => onEvent(const AutoBuyRetryPressed()),
            ),
          ],
        },
      ),
    ),
    AutoBuySessionEnded() => status(
      message: (context) => context.loc.exchangeFlowSessionEnded,
      actions: (context) => [
        FlowAction(
          context.loc.closeDialogButton,
          () => onEvent(const AutoBuyDonePressed()),
        ),
      ],
    ),
    AutoBuyDone() || AutoBuyClosed() => status(busy: true),
  };
}

Widget _error(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: BullSpacing.md),
  child: Text(text, style: TextStyle(color: context.appColors.error)),
);

class _AutoBuyPage extends StatelessWidget {
  const _AutoBuyPage({
    required this.title,
    required this.onEvent,
    required this.body,
  });

  final String Function(BuildContext) title;
  final void Function(AutoBuyFlowEvent event) onEvent;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title(context)),
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back),
        onPressed: () => onEvent(const AutoBuyBackPressed()),
      ),
    ),
    body: body,
  );
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.restricted,
    required this.terms,
    required this.onEvent,
  });

  final bool restricted;
  final Uri terms;
  final void Function(AutoBuyFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(BullSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.autoBuyDescription,
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          ),
          const Gap(BullSpacing.md),
          BullBorderedTile(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.autoBuyHowItWorks,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(BullSpacing.sm),
                _Bullet(text: context.loc.autoBuyConnectWallet),
                const Gap(BullSpacing.xs),
                _Bullet(text: context.loc.autoBuyPurchaseCreated),
                const Gap(BullSpacing.xs),
                _Bullet(text: context.loc.autoBuyBitcoinSent),
              ],
            ),
          ),
          const Gap(BullSpacing.md),
          Text(
            context.loc.autoBuyRiskDisclaimer,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.textMuted),
          ),
          const Gap(BullSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              link: true,
              child: TextButton(
                onPressed: () =>
                    launchUrl(terms, mode: LaunchMode.inAppBrowserView),
                child: Text(
                  context.loc.settingsTermsOfServiceTitle,
                  style: context.bullType.label
                      .copyWith(fontWeight: FontWeight.w400)
                      .copyWith(
                        color: context.appColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: context.appColors.primary,
                      ),
                ),
              ),
            ),
          ),
          const Gap(BullSpacing.lg),
          if (restricted)
            BullInfoCard(
              title: context.loc.fundExchangeRestrictedTitle,
              description: context.loc.fundExchangeRestrictedMessage,
              bgColor: context.appColors.error.withValues(alpha: 0.1),
              tagColor: context.appColors.error,
            )
          else
            BullButton.primary(
              label: context.loc.autoBuyGetStarted,
              onPressed: () => onEvent(const AutoBuyGetStartedPressed()),
            ),
        ],
      ),
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('•', style: context.bullType.body),
      const Gap(BullSpacing.xs),
      Expanded(child: Text(text, style: context.bullType.body)),
    ],
  );
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.wallets,
    required this.viewer,
    required this.footer,
  });

  final DefaultWallets wallets;
  final Widget Function(BuildContext, String) viewer;
  final List<Widget> Function(BuildContext) footer;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String address) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Gap(BullSpacing.xs),
        Text(label, style: context.bullType.caption),
        const Gap(BullSpacing.xs),
        viewer(context, address),
        const Gap(BullSpacing.xs),
      ],
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.loc.autoBuyInfoMessage, style: context.bullType.body),
            const Gap(BullSpacing.lg),
            if (wallets.bitcoinAddress.isNotEmpty)
              row(
                context.loc.exchangeBitcoinWalletsBitcoinAddressLabel,
                wallets.bitcoinAddress,
              ),
            if (wallets.lightningAddress.isNotEmpty)
              row(
                context.loc.exchangeBitcoinWalletsLightningAddressLabel,
                wallets.lightningAddress,
              ),
            if (wallets.liquidAddress.isNotEmpty)
              row(
                context.loc.exchangeBitcoinWalletsLiquidAddressLabel,
                wallets.liquidAddress,
              ),
            const Gap(BullSpacing.lg),
            ...footer(context),
          ],
        ),
      ),
    );
  }
}
