import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/experimental/scan_signed_tx/scan_signed_tx_cubit.dart';
import 'package:bb_mobile/features/experimental/scan_signed_tx/scan_signed_tx_state.dart';
import 'package:bb_mobile/features/experimental/scanner/scanner_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/paste_input.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ScanSignedTxScreen extends StatelessWidget {
  const ScanSignedTxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => ScanSignedTxCubit(
            broadcastBitcoinTransactionUsecase:
                locator<BroadcastBitcoinTransactionUsecase>(),
          ),
      child: const _ScanSignedTxView(),
    );
  }
}

class _ScanSignedTxView extends StatelessWidget {
  const _ScanSignedTxView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.surface,
      appBar: AppBar(
        title: const Text('Scan / paste a transaction'),
        backgroundColor: context.colour.surface,
      ),
      body: BlocListener<ScanSignedTxCubit, ScanSignedTxState>(
        listener: (context, state) {
          if (state.txid.isNotEmpty) {
            context.goNamed(WalletRoute.walletHome.name);
          }
        },
        child: BlocBuilder<ScanSignedTxCubit, ScanSignedTxState>(
          builder: (context, state) {
            final cubit = context.read<ScanSignedTxCubit>();

            return Stack(
              children: [
                // Full page scanner
                if (state.transaction == null)
                  ScannerWidget(onScanned: cubit.tryCollectTx),

                // Overlay with status, paste input, and broadcast button
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.colour.surface.withAlpha(230),
                          context.colour.surface,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status section
                          if (state.parts.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: context.colour.secondary.withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Parts collected: ${state.parts.length}',
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.colour.secondary,
                                ),
                              ),
                            ),
                          if (state.error != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 8.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: context.colour.error.withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                state.error!,
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.colour.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Paste input
                          PasteInput(
                            text: state.transaction?.data ?? '',
                            hint: 'Paste a PSBT or transaction HEX',
                            onChanged: cubit.tryParseTransaction,
                          ),

                          // Broadcast button
                          if (state.transaction != null) ...[
                            const SizedBox(height: 16),
                            BBButton.big(
                              label: 'Broadcast',
                              bgColor: context.colour.secondary,
                              textColor: context.colour.onPrimary,
                              onPressed: cubit.broadcastTransaction,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
