import 'package:bb_mobile/core/bbqr/bbqr_service.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/experimental/psbt_flow/scan_signed_psbt/scan_signed_psbt_state.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:convert/convert.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScanSignedPsbtCubit extends Cubit<ScanSignedPsbtState> {
  final BbqrService bbqrService;

  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;

  ScanSignedPsbtCubit({
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
  }) : bbqrService = BbqrService(),
       _broadcastBitcoinTransactionUsecase = broadcastBitcoinTransactionUsecase,
       super(const ScanSignedPsbtState());

  Future<void> tryCollectPsbt(String payload) async {
    try {
      emit(state.copyWith(error: null));

      final tx = await bbqrService.scanTransaction(payload);

      if (tx != null) emit(state.copyWith(transaction: tx));

      if (bbqrService.parts.isNotEmpty) {
        emit(state.copyWith(parts: Map.from(bbqrService.parts)));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> tryParseTransaction(String input) async {
    emit(state.copyWith(error: null));
    try {
      final parsedPsbt = await PartiallySignedTransaction.fromString(input);
      emit(
        state.copyWith(
          transaction: (format: TxFormat.psbt, data: parsedPsbt.toString()),
        ),
      );
    } catch (e) {
      try {
        final parsedTx = await Transaction.fromBytes(
          transactionBytes: hex.decode(input),
        );
        emit(
          state.copyWith(
            transaction: (format: TxFormat.hex, data: parsedTx.toString()),
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(error: 'input is not a valid PSBT or transaction hex'),
        );
      }
    }
  }

  Future<void> broadcastTransaction() async {
    try {
      if (state.transaction == null) return;

      final txid = await _broadcastBitcoinTransactionUsecase.execute(
        state.transaction!.data,
        isPsbt: state.transaction!.format == TxFormat.psbt,
      );
      emit(state.copyWith(txid: txid));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
