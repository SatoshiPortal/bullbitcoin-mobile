import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmount, BullTopBar, Gap, BullTypographyX;
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
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            title: context.loc.receiveTitle,
            onAction: () => context.go(WalletRoute.walletHome.path),
          ),
        ),
        body: const PaymentInProgressPage(),
        // child: AmountPage(),
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
          BBText(
            context.loc.receivePaymentInProgress,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isBitcoin) ...[
            BBText(
              context.loc.receiveBitcoinConfirmationMessage,
              style: context.bullType.subtitle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            BBText(
              context.loc.receiveLiquidConfirmationMessage,
              style: context.bullType.subtitle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Gap(16),
          BullAmount.signedSats(
            amountSat ?? 0,
            interactive: true,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          BBText(
            '~$amountFiat',
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
            color: context.appColors.surface,
          ),
        ],
      ),
    );
  }
}
