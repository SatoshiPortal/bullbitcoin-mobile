import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/paste_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/transaction_details_widget.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BroadcastSignedTxPage extends StatelessWidget {
  const BroadcastSignedTxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Broadcast Signed Transaction',
          onBack: () => context.pop(),
        ),
      ),
      body: BlocBuilder<BroadcastSignedTxCubit, BroadcastSignedTxState>(
        builder: (context, state) {
          final cubit = context.read<BroadcastSignedTxCubit>();

          return SingleChildScrollView(
            child: Column(
              children: [
                if (state.transaction == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: PasteInput(
                      text: state.transaction?.data ?? '',
                      hint: 'Paste a PSBT or transaction HEX',
                      onChanged: cubit.tryParseTransaction,
                    ),
                  ),
                  const Gap(32),
                  Padding(
                    padding: const EdgeInsets.only(left: 100, right: 100),
                    child: BBButton.big(
                      label: 'QR (BBQR / Hex)',
                      onPressed:
                          () => context.pushNamed(
                            BroadcastSignedTxRoute.broadcastScanQr.name,
                          ),
                      bgColor: context.colour.onPrimary,
                      textColor: context.colour.secondary,
                      iconData: Icons.qr_code_scanner,
                    ),
                  ),
                  const Gap(32),

                  Padding(
                    padding: const EdgeInsets.only(left: 100, right: 100),
                    child: BBButton.big(
                      label: 'NFC (PushTx)',
                      onPressed:
                          () => context.pushNamed(
                            BroadcastSignedTxRoute.broadcastScanNfc.name,
                          ),
                      bgColor: context.colour.onPrimary,
                      textColor: context.colour.secondary,
                      iconData: Icons.nfc,
                    ),
                  ),
                ],

                if (state.error != null)
                  BBText(
                    state.error.toString(),
                    style: context.font.bodyMedium,
                    color: context.colour.error,
                  ),

                // Broadcast button
                if (state.transaction != null) ...[
                  TransactionDetailsWidget(tx: state.transaction!.tx),
                ],

                if (state.transaction != null)
                  Row(
                    children: [
                      if (state.pushTxUri != null &&
                          state.isBroadcasted == false)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: BBButton.big(
                              label: 'PushTx',
                              bgColor: context.colour.secondary,
                              textColor: context.colour.onPrimary,
                              onPressed: cubit.pushTxUri,
                            ),
                          ),
                        ),

                      if (state.isBroadcasted == false)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: BBButton.big(
                              label: 'Broadcast',
                              bgColor: context.colour.secondary,
                              textColor: context.colour.onPrimary,
                              onPressed: cubit.broadcastTransaction,
                            ),
                          ),
                        ),
                    ],
                  ),

                if (state.isBroadcasted == true) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 100, right: 100),
                    child: BBButton.big(
                      label: 'Done',
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onPrimary,
                      onPressed:
                          () => context.goNamed(WalletRoute.walletHome.name),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
