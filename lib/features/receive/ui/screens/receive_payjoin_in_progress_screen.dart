import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart'
    show PayjoinStatus;
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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
        context.goNamed(
          TransactionsRoute.payjoinTransactionDetails.name,
          pathParameters: {'payjoinId': state.payjoin!.id},
          queryParameters: {'returnHome': 'true'},
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
            flexibleSpace: TopBar(
              title: context.loc.receiveTitle,
              actionIcon: Icons.close,
              onAction: () => context.go(WalletRoute.walletHome.path),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3.0),
              child: FadingLinearProgress(
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
    // Payjoin.canManuallyBroadcastOriginal's doc comment. Deriving the
    // button's visibility from the exact same getter as the action means
    // they can never disagree.
    final canManuallyBroadcastOriginal = context.select(
      (ReceiveBloc bloc) =>
          bloc.state.payjoin?.canManuallyBroadcastOriginal ?? false,
    );
    final payjoinExpiresAt = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.expiresAt,
    );
    // The default session expiry is 24h; the Countdown widget renders
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
                  BBText(
                    context.loc.receivePayjoinBelowMinimum,
                    style: context.font.headlineLarge,
                    maxLines: 2,
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BBText(
                    context.loc.receivePayjoinBelowMinimumSubtext,
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                ] else if (isFallbackCompleted) ...[
                  BBText(
                    context.loc.receivePayjoinFallbackCompleted,
                    style: context.font.headlineLarge,
                    maxLines: 2,
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BBText(
                    context.loc.receivePayjoinFallbackCompletedSubtext,
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                ] else if (isRealPayjoin) ...[
                  BBText(
                    context.loc.receivePaymentInProgress,
                    style: context.font.headlineLarge,
                    maxLines: 2,
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BBText(
                    context.loc.receiveBitcoinConfirmationMessage,
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                ] else if (isExpired) ...[
                  BBText(
                    context.loc.receivePayjoinExpired,
                    style: context.font.headlineLarge,
                    maxLines: 2,
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BBText(
                    context.loc.receivePayjoinExpiredSubtext,
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                ] else ...[
                  BBText(
                    context.loc.receivePayjoinInProgress,
                    style: context.font.headlineLarge,
                    maxLines: 2,
                    textAlign: .center,
                  ),
                  const Gap(8),
                  BBText(
                    context.loc.receiveWaitForPayjoin,
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                  // Gated on the same canManuallyBroadcastOriginal as the
                  // fallback button below — a single source of truth so the
                  // countdown never outlives the action it is counting down
                  // to (see Payjoin.canManuallyBroadcastOriginal).
                  if (canManuallyBroadcastOriginal &&
                      payjoinExpiresAt != null &&
                      isFallbackImminent) ...[
                    const Gap(8),
                    Row(
                      mainAxisAlignment: .center,
                      children: [
                        BBText(
                          context.loc.receivePayjoinFallbackCountdown,
                          style: context.font.bodyMedium,
                          color: context.appColors.secondary,
                        ),
                        const Gap(4),
                        Countdown(
                          until: payjoinExpiresAt.add(
                            const Duration(
                              seconds:
                                  PayjoinConstants.directoryPollingInterval,
                            ),
                          ),
                          onTimeout: () {},
                        ),
                      ],
                    ),
                  ],
                ],
                if (amountSat != null) ...[
                  const Gap(16),
                  CurrencyText(
                    amountSat,
                    showFiat: false,
                    style: context.font.displaySmall,
                    textAlign: .center,
                  ),
                  const Gap(4),
                  BBText(
                    '~${FormatAmount.fiat(amountFiat, fiatCurrencyCode)}',
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(flex: 2),
          if (isFallbackCompleted && payjoinId != null)
            BBButton.big(
              label: context.loc.receiveViewDetails,
              onPressed: () => context.goNamed(
                TransactionsRoute.payjoinTransactionDetails.name,
                pathParameters: {'payjoinId': payjoinId},
                queryParameters: {'returnHome': 'true'},
              ),
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
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
    final broadcastOriginalTransactionException = context.select(
      (ReceiveBloc bloc) =>
          bloc.state.error is BroadcastOriginalTransactionException
          ? bloc.state.error! as BroadcastOriginalTransactionException
          : null,
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            context.loc.receivePayjoinFailQuestion,
            style: context.font.titleSmall,
            textAlign: .center,
            maxLines: 2,
          ),
          const Gap(16),
          BBButton.big(
            label: context.loc.receivePaymentNormally,
            disabled: isBroadcasting,
            onPressed: () {
              log.info('Receive payment normally');
              context.read<ReceiveBloc>().add(
                const ReceivePayjoinOriginalTxBroadcasted(),
              );
            },
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
          const Gap(16),
          if (broadcastOriginalTransactionException != null) ...[
            Text(
              context.loc.receiveError(
                broadcastOriginalTransactionException.message,
              ),
              style: context.font.bodyMedium?.copyWith(
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
