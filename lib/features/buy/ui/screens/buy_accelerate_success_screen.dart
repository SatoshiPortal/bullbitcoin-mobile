import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class BuyAccelerateSuccessScreen extends StatelessWidget {
  const BuyAccelerateSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        // Navigate to the wallet home screen when the user wants to exit the
        // buy success screen.
        context.goNamed(WalletRoute.walletHome.name);
      },
      child: BullPage(
        topBar: BullTopBar(
          title: context.loc.buyConfirmTitle,
          actionIcon: BullIcons.close,
          onAction: () => context.goNamed(WalletRoute.walletHome.name),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: .center,
            children: [
              BullIcon(
                BullIcons.checkCircle,
                size: 100,
                color: context.bull.success,
              ),
              const Gap(BullSpacing.lg),
              BullText(
                context.loc.buyBitcoinSent,
                style: context.bullText.titleLarge,
              ),
              const Gap(BullSpacing.xs),
              BullText(
                context.loc.buyThatWasFast,
                style: context.bullText.bodyMedium,
                textAlign: .center,
              ),
            ],
          ),
        ),
        bottomBar: buyOrder == null
            ? null
            : BullBottomActionBar(
                actions: [
                  BullButton.primary(
                    label: context.loc.buyViewDetails,
                    onPressed: () {
                      context.pushNamed(
                        TransactionsRoute.orderTransactionDetails.name,
                        pathParameters: {'orderId': buyOrder.orderId},
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
