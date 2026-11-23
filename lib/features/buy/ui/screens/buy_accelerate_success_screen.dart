import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/presentation/buy_failure_l10n.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullSuccessScreen, Gap, BullTypographyX;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class BuyAccelerateSuccessScreen extends StatelessWidget {
  const BuyAccelerateSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder);
    // This route builds its own bloc and refreshes the order on entry, so a
    // failed refresh is the reason "View details" is missing — say so instead
    // of leaving an empty slot.
    final BuyFailure? accelerateFailure = context.select(
      (BuyBloc bloc) => bloc.state.accelerateFailure,
    );

    return BullSuccessScreen(
      title: context.loc.buyConfirmTitle,
      headline: context.loc.buyBitcoinSent,
      message: Text(context.loc.buyThatWasFast),
      onClose: () => context.goNamed(WalletRoute.walletHome.name),
      actions: [
        if (accelerateFailure != null) ...[
          Text(
            accelerateFailure.toTranslated(context),
            style: context.bullType.body.copyWith(
              color: context.appColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
        ],
        if (buyOrder != null)
          BullButton.secondary(
            label: context.loc.buyViewDetails,
            onPressed: () {
              context.pushNamed(
                TransactionsRoute.orderTransactionDetails.name,
                pathParameters: {'orderId': buyOrder.orderId},
              );
            },
          ),
      ],
    );
  }
}
