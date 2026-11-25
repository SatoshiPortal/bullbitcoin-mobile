import 'package:receive/src/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/ui/widgets/receive_polling.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:receive/src/ui/receive_localizations.dart';
import 'package:receive/src/domain/receive_wallet.dart';
import 'package:receive/src/ui/widgets/receive_network_selection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullTopBar, BullPaymentNetwork;
import 'package:go_router/go_router.dart';
import 'package:receive/src/ui/widgets/receive_onchain_transition.dart';
import 'package:transactions/routes.dart';

class ReceiveScaffold extends StatelessWidget {
  const ReceiveScaffold({
    super.key,
    required this.child,
    required this.poll,
    required this.openHome,
    this.wallet,
  });

  final Widget child;
  final void Function(BuildContext) openHome;
  final ReceiveWallet? wallet;
  final PollReceiveWalletUsecase poll;

  @override
  Widget build(BuildContext context) {
    final target = context.select((ReceiveBloc bloc) {
      final state = bloc.state;
      if (state.type == ReceiveType.lightning) {
        // The receiving wallet is the swap's own; sync it while the invoice
        // awaits payment. No address reveal gates this, so a constant stands in.
        final swapWalletId =
            state.lightningSwap?.receiveWalletId ??
            state.orderSwap?.destinationWalletId;
        final hasSwap = state.lightningSwap != null || state.orderSwap != null;
        return (
          swapWalletId ?? state.wallet?.id,
          state.wallet?.isLiquid ?? false,
          hasSwap ? 0 : null,
        );
      }
      return (
        state.wallet?.id,
        state.wallet?.isLiquid ?? false,
        state.revealedAddressGeneration,
      );
    });
    return ReceivePolling(
      walletId: target.$1,
      isLiquid: target.$2,
      revealGeneration: target.$3,
      poll: poll,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    void onBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        openHome(context);
      }
    }

    final selectedWallet = context.select(
      (ReceiveBloc bloc) => bloc.state.wallet,
    );
    // Lightning uses a Liquid settlement wallet; retain the entry's chain choices.
    final entryWallet = wallet;
    final selectionWallet = entryWallet == null
        ? null
        : selectedWallet != null &&
              selectedWallet.isLiquid == entryWallet.isLiquid
        ? selectedWallet
        : entryWallet;
    final transaction = context.select((ReceiveBloc bloc) => bloc.state.tx);
    // Reduced motion keeps develop's behaviour: no transition, the details
    // open as soon as the payment is detected (see the listener below).
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final showTransition = context.select(
      (ReceiveBloc bloc) =>
          !reduced &&
          bloc.state.tx != null &&
          (bloc.state.type == ReceiveType.bitcoin ||
              bloc.state.type == ReceiveType.liquid) &&
          !bloc.state.isPayjoinFlowOwningNavigation,
    );
    final confirmed = context.select(
      (ReceiveBloc bloc) => bloc.state.settlementConfirmed,
    );
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          reduced &&
          previous.isPaymentReceived != true &&
          current.isPaymentReceived == true &&
          (current.type == ReceiveType.bitcoin ||
              current.type == ReceiveType.liquid) &&
          !current.isPayjoinFlowOwningNavigation,
      listener: (context, state) {
        final walletId = state.wallet?.id;
        if (walletId == null) return;
        TransactionsNavigation.goToDetails(
          context,
          TransactionDetailsTarget.wallet(state.txId, walletId: walletId),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: showTransition,
            child: IgnorePointer(
              ignoring: showTransition,
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                behavior: .translucent,
                child: Scaffold(
                  resizeToAvoidBottomInset: true,
                  appBar: AppBar(
                    forceMaterialTransparency: true,
                    automaticallyImplyLeading: false,
                    flexibleSpace: BullTopBar(
                      title: context.loc.receiveTitle,
                      onBack: onBack,
                    ),
                  ),
                  body: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      ReceiveNetworkSelection(
                        wallet: selectionWallet,
                        network: selectedWallet?.network,
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showTransition && transaction != null)
            ReceiveOnchainTransition(
              key: ValueKey(transaction.txId),
              network: transaction.isBitcoin
                  ? BullPaymentNetwork.bitcoin
                  : BullPaymentNetwork.liquid,
              confirmed: confirmed,
              steps: [
                context.loc.receiveStepPaymentDetected,
                context.loc.receiveStepConfirmed,
              ],
              viewDetails: context.loc.receiveViewDetails,
              networkLabel: transaction.isBitcoin
                  ? context.loc.transactionNetworkBitcoin
                  : context.loc.transactionNetworkLiquid,
              onBack: onBack,
              onViewDetails: () => TransactionsNavigation.goToDetails(
                context,
                TransactionDetailsTarget.wallet(
                  transaction.txId,
                  walletId: transaction.walletId,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
