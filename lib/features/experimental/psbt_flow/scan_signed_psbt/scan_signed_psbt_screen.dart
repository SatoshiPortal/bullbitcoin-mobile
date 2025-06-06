import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/experimental/psbt_flow/scan_signed_psbt/scan_signed_psbt_cubit.dart';
import 'package:bb_mobile/features/experimental/psbt_flow/scan_signed_psbt/scan_signed_psbt_state.dart';
import 'package:bb_mobile/features/experimental/scanner/scanner_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/paste_input.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ScanSignedPsbtScreen extends StatelessWidget {
  const ScanSignedPsbtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => ScanSignedPsbtCubit(
            broadcastBitcoinTransactionUsecase:
                locator<BroadcastBitcoinTransactionUsecase>(),
          ),
      child: const _ScanSignedPsbtView(),
    );
  }
}

class _ScanSignedPsbtView extends StatelessWidget {
  const _ScanSignedPsbtView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.surface,
      appBar: AppBar(
        title: const Text('PSBT'),
        backgroundColor: context.colour.surface,
      ),
      body: BlocListener<ScanSignedPsbtCubit, ScanSignedPsbtState>(
        listener: (context, state) {
          if (state.txid.isNotEmpty) {
            context.goNamed(WalletRoute.walletHome.name);
          }
        },
        child: BlocBuilder<ScanSignedPsbtCubit, ScanSignedPsbtState>(
          builder: (context, state) {
            final cubit = context.read<ScanSignedPsbtCubit>();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.parts.isNotEmpty)
                    Text(
                      'Parts collected: ${state.parts.length}',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.secondary,
                      ),
                    ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        state.error!,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.error,
                        ),
                      ),
                    ),
                  if (state.transaction == null)
                    Expanded(
                      child: Center(
                        child: ScannerWidget(onScanned: cubit.tryCollectPsbt),
                      ),
                    ),
                  PasteInput(
                    text: state.transaction?.data ?? '',
                    hint: 'Paste a PSBT',
                    onChanged: cubit.tryParseTransaction,
                  ),
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
            );
          },
        ),
      ),
    );
  }
}
