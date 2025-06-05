import 'package:bb_mobile/core/bbqr/bbqr_service.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/experimental/psbt_flow/scan_signed_psbt/scan_signed_psbt_state.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
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
      final psbt = await bbqrService.collectPsbt(payload);

      if (psbt != null) {
        emit(state.copyWith(psbt: psbt, error: null));
      }

      if (bbqrService.parts.isNotEmpty) {
        emit(state.copyWith(parts: Map.from(bbqrService.parts)));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> tryParsePsbt(String psbt) async {
    try {
      emit(state.copyWith(error: null));
      final parsedPsbt = await PartiallySignedTransaction.fromString(psbt);
      emit(state.copyWith(psbt: parsedPsbt.toString(), error: null));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> broadcastTransaction() async {
    try {
      final txid = await _broadcastBitcoinTransactionUsecase.execute(
        state.psbt,
      );
      emit(state.copyWith(txid: txid));
      debugPrint('txid: $txid');
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
