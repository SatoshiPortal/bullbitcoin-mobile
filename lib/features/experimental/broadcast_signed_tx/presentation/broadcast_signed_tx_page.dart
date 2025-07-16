import 'package:bb_mobile/core/widgets/transaction_details_widget.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/broadcast_signed_tx_router.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/paste_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
                  PasteInput(
                    text: state.transaction?.data ?? '',
                    hint: 'Paste a PSBT or transaction HEX',
                    onChanged: cubit.tryParseTransaction,
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
                    state.error!,
                    style: context.font.bodyMedium,
                    color: context.colour.error,
                  ),

                // Broadcast button
                if (state.transaction != null) ...[
                  TransactionDetailsWidget(tx: state.transaction!.tx),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 100, right: 100),
                    child: BBButton.big(
                      label: 'Broadcast',
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onPrimary,
                      onPressed: cubit.broadcastTransaction,
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
