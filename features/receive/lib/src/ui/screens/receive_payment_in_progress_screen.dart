import 'package:bull_ui/app_theme.dart';
import 'package:receive/src/ui/receive_localizations.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullText, BullAmount, BullTopBar, Gap, BullTypographyX;
import 'package:receive/src/ui/widgets/receive_lightning_transition.dart';

class ReceivePaymentInProgressScreen extends StatelessWidget {
  final void Function(BuildContext) openHome;

  const ReceivePaymentInProgressScreen({super.key, required this.openHome});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        openHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            title: context.loc.receiveTitle,
            onAction: () => openHome(context),
          ),
        ),
        body:
            context.select(
              (ReceiveBloc bloc) =>
                  bloc.state.orderSwap == null &&
                  bloc.state.lightningSwap != null,
            )
            ? const ReceiveLightningTransition()
            : const PaymentInProgressPage(),
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
          BullText(
            context.loc.receivePaymentInProgress,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isBitcoin) ...[
            BullText(
              context.loc.receiveBitcoinConfirmationMessage,
              style: context.bullType.subtitle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            BullText(
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
          BullText(
            '~$amountFiat',
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
            color: context.appColors.surface,
          ),
        ],
      ),
    );
  }
}
