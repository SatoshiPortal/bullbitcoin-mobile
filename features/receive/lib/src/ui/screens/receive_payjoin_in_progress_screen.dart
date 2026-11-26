import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:receive/src/ui/receive_localizations.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:receive/receive.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/presentation/receive_failure_l10n.dart';
import 'package:transactions/payment_status.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart' show TransactionsLocalizations;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullAmount,
        BullButton,
        BullCountdown,
        BullFadingLinearProgress,
        BullPaymentDirection,
        BullPaymentNetwork,
        BullPaymentTransition,
        BullPaymentViews,
        BullPaymentViewSwitch,
        BullTopBar,
        Gap,
        BullTypographyX;

class ReceivePayjoinInProgressScreen extends StatefulWidget {
  final void Function(BuildContext) openHome;

  const ReceivePayjoinInProgressScreen({super.key, required this.openHome});

  @override
  State<ReceivePayjoinInProgressScreen> createState() =>
      _ReceivePayjoinInProgressScreenState();
}

bool _isSettled(ReceiveState state) =>
    state.payjoin?.isCompleted == true && state.showPaymentAnimations != null;

class _ReceivePayjoinInProgressScreenState
    extends State<ReceivePayjoinInProgressScreen> {
  bool _showDetailsView = false;
  void _showDetails(
    String id, {
    TransactionDetailsView view = TransactionDetailsView.status,
  }) {
    if (!mounted) return;
    TransactionsNavigation.goToDetails(
      context,
      TransactionDetailsTarget.payjoin(id),
      returnHome: true,
      view: view,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBroadcasting = context.select(
      (ReceiveBloc bloc) => bloc.state.isBroadcastingOriginalTransaction,
    );
    final payjoin = context.select((ReceiveBloc bloc) => bloc.state.payjoin);
    final confirmed = context.select(
      (ReceiveBloc bloc) => bloc.state.settlementConfirmed,
    );
    final animationsEnabled = context.select(
      (ReceiveBloc bloc) => bloc.state.showPaymentAnimations == true,
    );
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final showViews = animationsEnabled && !reduced && payjoin != null;
    // The root route owns its handoff. A fallback or expiry stays here so the
    // user can read the explanation and access the recovery action.
    return BlocListener<ReceiveBloc, ReceiveState>(
      // An unknown preference waits: completion hands off once it is read.
      listenWhen: (previous, current) =>
          !_isSettled(previous) && _isSettled(current),
      listener: (context, state) {
        final payjoin = state.payjoin;
        if (payjoin == null) return;
        if (state.showPaymentAnimations == false) {
          _showDetails(payjoin.id, view: TransactionDetailsView.details);
        }
        // With animations on, including reduced motion, stay on this screen.
      },
      // TODO: PopScope can be removed since we can do pop here now
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return; // Don't allow back navigation

          widget.openHome(context);
        },
        child: showViews
            ? Builder(
                builder: (context) {
                  final steps = [
                    context.loc.receiveStepOriginalReceived,
                    context.loc.receiveStepProposalSent,
                    context.loc.receiveStepPaymentDetected,
                    context.loc.receiveStepConfirmed,
                  ];
                  final progress = receivePayjoinProgress(
                    steps: steps,
                    status: payjoin.status,
                    hasOriginal: payjoin.hasOriginalTransaction,
                    hasProposal: payjoin.hasProposal,
                    confirmed: confirmed,
                  );
                  final status = switch (payjoin.status) {
                    PayjoinStatus.started => context.loc.receiveStatusStarted,
                    PayjoinStatus.requested =>
                      context.loc.receiveStatusRequested,
                    PayjoinStatus.proposed => context.loc.receiveStatusProposed,
                    PayjoinStatus.completed => confirmed ? steps[3] : steps[2],
                    PayjoinStatus.aborted =>
                      context.loc.receivePayjoinFallbackCompleted,
                    PayjoinStatus.expired => context.loc.receiveStatusExpired,
                  };
                  final labels = TransactionsLocalizations.of(context);
                  return Scaffold(
                    body: BullPaymentViews(
                      showingStatus: !_showDetailsView,
                      switcher: BullPaymentViewSwitch(
                        showingStatus: !_showDetailsView,
                        statusLabel: labels.paymentStatusViewTransaction,
                        detailsLabel: labels.paymentStatusViewDetails,
                        semanticsLabel: labels.paymentStatusViewsLabel,
                        onStatus: () =>
                            setState(() => _showDetailsView = false),
                        onDetails: () =>
                            setState(() => _showDetailsView = true),
                      ),
                      views: IndexedStack(
                        sizing: StackFit.expand,
                        index: _showDetailsView ? 1 : 0,
                        children: [
                          TickerMode(
                            enabled: !_showDetailsView,
                            child: BullPaymentTransition(
                              network: BullPaymentNetwork.payjoin,
                              direction: BullPaymentDirection.incoming,
                              phase: receivePayjoinPhase(
                                status: payjoin.status,
                                confirmed: confirmed,
                              ),
                              progress: progress,
                              status: confirmed
                                  ? steps.last
                                  : payjoin.isExpired
                                  ? context.loc.receiveStatusExpired
                                  : context.loc.receiveStepPending,
                              statusTag: status,
                              onBack: () => widget.openHome(context),
                              onDone: () {},
                            ),
                          ),
                          const PayjoinInProgressPage(),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Scaffold(
                appBar: AppBar(
                  forceMaterialTransparency: true,
                  automaticallyImplyLeading: false,
                  flexibleSpace: BullTopBar(
                    title: context.loc.receiveTitle,
                    onAction: () => widget.openHome(context),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(3.0),
                    child: BullFadingLinearProgress(
                      trigger: isBroadcasting,
                      backgroundColor: context.appColors.onPrimary,
                      foregroundColor: context.appColors.primary,
                    ),
                  ),
                ),
                body: const PayjoinInProgressPage(),
              ),
      ),
    );
  }
}

class PayjoinInProgressPage extends StatelessWidget {
  const PayjoinInProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final payjoin = context.select((ReceiveBloc bloc) => bloc.state.payjoin);
    final confirmed = context.select(
      (ReceiveBloc bloc) => bloc.state.settlementConfirmed,
    );
    final showAnimation = context.select(
      (ReceiveBloc bloc) => bloc.state.showPaymentAnimations == true,
    );
    final progress = payjoin == null || !showAnimation
        ? null
        : receivePayjoinProgress(
            steps: [
              context.loc.receiveStepOriginalReceived,
              context.loc.receiveStepProposalSent,
              context.loc.receiveStepPaymentDetected,
              context.loc.receiveStepConfirmed,
            ],
            status: payjoin.status,
            hasOriginal: payjoin.hasOriginalTransaction,
            hasProposal: payjoin.hasProposal,
            confirmed: confirmed,
          );
    final amountSat = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.amountSat,
    );
    final amountFiat = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoinAmountFiat,
    );
    final fiatCurrencyCode = context.select(
      (ReceiveBloc bloc) => bloc.state.fiatCurrencyCode,
    );
    final payjoinId = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.id,
    );
    // A completed negotiation is not necessarily confirmed on chain.
    final isRealPayjoin = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.isCompleted == true,
    );
    // Completed, but NOT via a real payjoin: the plain-broadcast fallback
    // paid the sender instead — declined below the anti-probing minimum, a
    // failed negotiation, or an expiry with no proposal ever exchanged (see
    // PayjoinStatus.aborted). Unlike isRealPayjoin, this state is NOT
    // auto-navigated away from: the user explicitly expected a payjoin, so
    // they get to read why one didn't happen instead of landing on
    // transaction details unannounced.
    final isFallbackCompleted = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.isAborted == true,
    );
    // The specific, most informative case: the request was declined solely
    // because its amount fell under the configured anti-probing threshold.
    // Exact, not a heuristic — see ReceiveState.isPayjoinBelowMinimum.
    final isBelowMinimum = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinBelowMinimum,
    );
    // Distinct from a completed session: the session's own window closed
    // WITHOUT the counterparty completing it. The automatic plain-broadcast
    // fallback (PayjoinRepositoryImpl._processExpiredPayjoin) usually
    // resolves this into isFallbackCompleted=true within a second or two,
    // but if that fallback itself fails (no network at that exact moment),
    // status stays `expired` indefinitely — without this branch the screen
    // kept showing the same "in progress, wait" copy forever, giving the
    // user no signal that waiting longer would not help and the manual
    // "receive normally" button below was their only way out.
    final isExpired = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.status == PayjoinStatus.expired,
    );
    // The single source of truth ReceiveBloc's own action guard
    // (_onPayjoinOriginalTxBroadcasted) agrees with — see
    // ReceiveState.canOfferPayjoinFallback. Deriving the button's visibility
    // from the exact same getter as the action means they can never disagree.
    final canManuallyBroadcastOriginal = context.select(
      (ReceiveBloc bloc) => bloc.state.canOfferPayjoinFallback,
    );
    final payjoinExpiresAt = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.expiresAt,
    );
    // The default session expiry is 24h; the BullCountdown widget renders
    // minutes:seconds (a day would show a meaningless "1440:00"), so only
    // reveal it when the fallback is genuinely imminent (≤ 1h remaining).
    // Computed once per build — acceptable for a display-only hint, the
    // screen rebuilds on each cubit emit (once per poll at most).
    final isFallbackImminent =
        payjoinExpiresAt != null &&
        payjoinExpiresAt.difference(DateTime.now()) <= const Duration(hours: 1);

    // Keep the content scrollable without intrinsic measurements: BullText and
    // BullButton may contain LayoutBuilder, which cannot provide them.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisAlignment: .spaceEvenly,
              children: [
                if (progress != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (var i = 0; i < progress.steps.length; i++)
                          Semantics(
                            label: progress.steps[i],
                            value: progress.skippedAt == i
                                ? context.loc.receiveStepSkipped
                                : i < progress.completed ||
                                      (confirmed &&
                                          i == progress.steps.length - 1)
                                ? context.loc.receiveStepComplete
                                : progress.failedAt == i
                                ? context.loc.receiveStepFailed
                                : context.loc.receiveStepPending,
                            child: ExcludeSemantics(
                              child: Text(
                                '${progress.skippedAt == i
                                    ? '— '
                                    : i < progress.completed || (confirmed && i == progress.steps.length - 1)
                                    ? '✓ '
                                    : progress.failedAt == i
                                    ? '✕ '
                                    : '○ '}${progress.steps[i]}',
                                style: progress.skippedAt == i
                                    ? context.bullType.body.copyWith(
                                        color: context.appColors.secondary,
                                        decoration: TextDecoration.lineThrough,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const Gap(32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (isBelowMinimum) ...[
                        BullText(
                          context.loc.receivePayjoinBelowMinimum,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          textAlign: .center,
                        ),
                        const Gap(8),
                        BullText(
                          context.loc.receivePayjoinBelowMinimumSubtext,
                          style: context.bullType.body,
                          color: context.appColors.secondary,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ] else if (isFallbackCompleted) ...[
                        BullText(
                          context.loc.receivePayjoinFallbackCompleted,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          textAlign: .center,
                        ),
                        const Gap(8),
                        BullText(
                          context.loc.receivePayjoinFallbackCompletedSubtext,
                          style: context.bullType.body,
                          color: context.appColors.secondary,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ] else if (isRealPayjoin) ...[
                        BullText(
                          confirmed
                              ? context.loc.receivePaymentReceived
                              : context.loc.receivePaymentInProgress,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          textAlign: .center,
                        ),
                        if (!confirmed) ...[
                          const Gap(8),
                          BullText(
                            context.loc.receiveBitcoinConfirmationMessage,
                            style: context.bullType.body,
                            color: context.appColors.secondary,
                            maxLines: 4,
                            textAlign: .center,
                          ),
                        ],
                      ] else if (isExpired) ...[
                        BullText(
                          context.loc.receivePayjoinExpired,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          textAlign: .center,
                        ),
                        const Gap(8),
                        BullText(
                          context.loc.receivePayjoinExpiredSubtext,
                          style: context.bullType.body,
                          color: context.appColors.secondary,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                      ] else ...[
                        BullText(
                          context.loc.receivePayjoinInProgress,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          textAlign: .center,
                        ),
                        const Gap(8),
                        BullText(
                          context.loc.receiveWaitForPayjoin,
                          style: context.bullType.body,
                          color: context.appColors.secondary,
                          maxLines: 4,
                          textAlign: .center,
                        ),
                        // Gated on the same canManuallyBroadcastOriginal as the
                        // fallback button below — a single source of truth so the
                        // countdown never outlives the action it is counting down
                        // to (see ReceiveState.canOfferPayjoinFallback).
                        if (canManuallyBroadcastOriginal &&
                            payjoinExpiresAt != null &&
                            isFallbackImminent) ...[
                          const Gap(8),
                          Row(
                            mainAxisAlignment: .center,
                            children: [
                              BullText(
                                context.loc.receivePayjoinFallbackCountdown,
                                style: context.bullType.body,
                                color: context.appColors.secondary,
                              ),
                              const Gap(4),
                              BullCountdown(until: payjoinExpiresAt),
                            ],
                          ),
                        ],
                      ],
                      if (amountSat != null) ...[
                        const Gap(16),
                        BullAmount.signedSats(
                          amountSat,
                          interactive: true,
                          style: context.bullType.headline,
                          textAlign: .center,
                        ),
                        if (amountFiat != null) ...[
                          const Gap(4),
                          BullText(
                            '~${FormatAmount.fiat(amountFiat, fiatCurrencyCode)}',
                            style: context.bullType.body,
                            color: context.appColors.secondary,
                            maxLines: 4,
                            textAlign: .center,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const Gap(64),
                if ((isFallbackCompleted || isRealPayjoin) && payjoinId != null)
                  BullButton.secondary(
                    label: context.loc.receiveViewDetails,
                    onPressed: () => TransactionsNavigation.goToDetails(
                      context,
                      TransactionDetailsTarget.payjoin(payjoinId),
                      returnHome: true,
                      view: TransactionDetailsView.details,
                    ),
                  )
                else if (canManuallyBroadcastOriginal)
                  const ReceiveBroadcastPayjoinButton(),
                const Gap(32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiveBroadcastPayjoinButton extends StatelessWidget {
  const ReceiveBroadcastPayjoinButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isBroadcasting = context.select(
      (ReceiveBloc bloc) => bloc.state.isBroadcastingOriginalTransaction,
    );
    final broadcastFailure = context.select(
      (ReceiveBloc bloc) => switch (bloc.state.failure) {
        final ReceiveBroadcastOriginalTxFailure failure => failure,
        final ReceiveBroadcastOriginalTxVerificationFailure failure => failure,
        _ => null,
      },
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            context.loc.receivePayjoinFailQuestion,
            style: context.bullType.label,
            textAlign: .center,
            maxLines: 2,
          ),
          const Gap(16),
          BullButton.secondary(
            label: context.loc.receivePaymentNormally,
            onPressed: (isBroadcasting)
                ? null
                : () {
                    log.info('Receive payment normally');
                    context.read<ReceiveBloc>().add(
                      const ReceivePayjoinOriginalTxBroadcasted(),
                    );
                  },
          ),
          const Gap(16),
          if (broadcastFailure != null) ...[
            Text(
              broadcastFailure.toTranslated(context),
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
              textAlign: .center,
            ),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}
