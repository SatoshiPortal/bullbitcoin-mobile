import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:receive/receive.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/presentation/receive_failure_l10n.dart';
import 'package:transactions/routes.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullAmount,
        BullButton,
        BullCountdown,
        BullFadingLinearProgress,
        BullTopBar,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class ReceivePayjoinInProgressScreen extends StatelessWidget {
  const ReceivePayjoinInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isBroadcasting = context.select(
      (ReceiveBloc bloc) => bloc.state.isBroadcastingOriginalTransaction,
    );
    // This screen lives on the root navigator, so the receive ShellRoute's
    // navigation BlocListeners are unmounted while it is shown — it has to
    // move itself out once the session reaches its happy terminal state.
    // Without this the user stayed on "payjoin in progress" indefinitely
    // after the payjoin completed, with the top-bar close button as the only
    // way out.
    //
    // Gated on a REAL payjoin completion (isCompleted == status completed
    // only, in this codebase), NOT the aborted fallback: a session that
    // completed via the plain-broadcast fallback (declined below the
    // anti-probing minimum, a failed negotiation, or an expiry with no
    // proposal ever exchanged) is deliberately NOT auto-navigated away from —
    // PayjoinInProgressPage instead settles on an explanatory message (why
    // there was no payjoin) that the user would otherwise never get to read
    // if this immediately jumped to transaction details. Same reasoning for
    // `expired`: it still offers the manual "receive payment normally"
    // fallback below.
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          previous.payjoin?.isCompleted != true &&
          current.payjoin?.isCompleted == true,
      listener: (context, state) {
        final payjoin = state.payjoin;
        if (payjoin == null) return;
        TransactionsNavigation.goToDetails(
          context,
          TransactionDetailsTarget.payjoin(payjoin.id),
          returnHome: true,
        );
      },
      // TODO: PopScope can be removed since we can do pop here now
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return; // Don't allow back navigation

          context.go(WalletRoute.walletHome.path);
        },
        child: Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: BullTopBar(
              title: context.loc.receiveTitle,
              onAction: () => context.go(WalletRoute.walletHome.path),
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
  const PayjoinInProgressPage();

  @override
  Widget build(BuildContext context) {
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
    // A real payjoin: the counterparty actually completed the negotiation
    // and its own transaction was broadcast. This screen auto-navigates
    // away as soon as this becomes true (see the BlocListener above), so in
    // practice this branch is only ever on screen for a brief instant.
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

    // Mirrors SendSucessScreen's layout so both terminal payment screens read
    // the same: centered copy with horizontal margins, the amount block, and
    // a single bottom-anchored action button.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisAlignment: .center,
        children: [
          const Spacer(),
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
                    context.loc.receivePaymentInProgress,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BullText(
                    context.loc.receiveBitcoinConfirmationMessage,
                    style: context.bullType.body,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
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
          const Spacer(flex: 2),
          if (isFallbackCompleted && payjoinId != null)
            BullButton.secondary(
              label: context.loc.receiveViewDetails,
              onPressed: () => TransactionsNavigation.goToDetails(
                context,
                TransactionDetailsTarget.payjoin(payjoinId),
                returnHome: true,
              ),
            )
          else if (canManuallyBroadcastOriginal)
            const ReceiveBroadcastPayjoinButton(),
          const Gap(32),
        ],
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
