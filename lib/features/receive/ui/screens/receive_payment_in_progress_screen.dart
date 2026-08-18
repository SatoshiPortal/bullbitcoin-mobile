import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ReceivePaymentInProgressScreen extends StatelessWidget {
  const ReceivePaymentInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        context.go(WalletRoute.walletHome.path);
      },
      child: BullPage(
        padding: EdgeInsets.zero,
        topBar: BullTopBar(
          title: context.loc.receiveTitle,
          actionIcon: BullIcons.close,
          onAction: () => context.go(WalletRoute.walletHome.path),
        ),
        child: const PaymentInProgressPage(),
      ),
    );
  }
}

class PaymentInProgressPage extends StatelessWidget {
  const PaymentInProgressPage();

  @override
  Widget build(BuildContext context) {
    // Using read instead of select or watch is ok here,
    //  since the amounts can not be changed at this point anymore.
    final amountSat = context.read<ReceiveBloc>().state.confirmedAmountSat;
    final amountFiat = context
        .read<ReceiveBloc>()
        .state
        .formattedConfirmedAmountFiat;

    final isBitcoin = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state.isBitcoin,
    );

    return Center(
      child: Column(
        mainAxisAlignment: .center,
        children: [
          BullText(
            context.loc.receivePaymentInProgress,
            style: context.bullText.headlineLarge,
          ),
          if (isBitcoin) ...[
            BullText(
              context.loc.receiveBitcoinConfirmationMessage,
              style: context.bullText.headlineMedium,
            ),
          ] else ...[
            BullText(
              context.loc.receiveLiquidConfirmationMessage,
              style: context.bullText.headlineMedium,
            ),
          ],
          const Gap(16),
          CurrencyText(
            amountSat ?? 0,
            showFiat: false,
            style: context.bullText.headlineLarge,
          ),
          const Gap(4),
          BullText(
            '~$amountFiat',
            style: context.bullText.bodyLarge,
            color: context.bull.textMuted,
          ),
        ],
      ),
    );
  }
}
