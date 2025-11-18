import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/state.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReplaceByFeeCubit extends Cubit<ReplaceByFeeState> {
  final WalletTransaction originalTransaction;
  final BumpFeeUsecase bumpFeeUsecase;
  final BroadcastBitcoinTransactionUsecase broadcastBitcoinTransactionUsecase;
  final GetNetworkFeesUsecase getNetworkFeesUsecase;

  ReplaceByFeeCubit({
    required this.originalTransaction,
    required this.bumpFeeUsecase,
    required this.broadcastBitcoinTransactionUsecase,
    required this.getNetworkFeesUsecase,
  }) : super(const ReplaceByFeeState()) {
    init();
  }

  Future<void> init() async {
    final fees = await getNetworkFeesUsecase.execute(isLiquid: false);
    final fastestFeeRate = FeeEntity(
      type: FeeType.fastest,
      feeRate: fees.fastest.value.toDouble(),
    );
    final recommendedBumpRate = FeeEntity(
      type: FeeType.custom,
      feeRate: (originalTransaction.feeSat / originalTransaction.vsize) + 1,
    );
    emit(
      state.copyWith(
        fastestFeeRate: fastestFeeRate,
        newFeeRate: recommendedBumpRate,
      ),
    );
  }

  void clearError() => emit(state.copyWith(errorKey: null));

  void reset() => emit(const ReplaceByFeeState());

  Future<void> broadcast() async {
    try {
      emit(state.copyWith(errorKey: null));

      if (state.newFeeRate == null) {
        emit(state.copyWith(errorKey: 'replaceByFeeErrorNoFeeRateSelected'));
        return;
      }

      final psbt = await bumpFeeUsecase.execute(
        walletId: originalTransaction.walletId,
        txid: originalTransaction.txId,
        newFeeRate: state.newFeeRate!.feeRate,
      );

      final txid = await broadcastBitcoinTransactionUsecase.execute(
        psbt,
        isPsbt: true,
      );

      emit(state.copyWith(txid: txid));
    } on TransactionConfirmedException catch (_) {
      emit(state.copyWith(errorKey: 'replaceByFeeErrorTransactionConfirmed'));
    } on FeeRateTooLowException catch (_) {
      emit(state.copyWith(errorKey: 'replaceByFeeErrorFeeRateTooLow'));
    } catch (e) {
      // For any other errors, use a generic error key or the error message
      emit(state.copyWith(errorKey: 'replaceByFeeErrorGeneric'));
    }
  }

  void onChangeFee(FeeEntity fee) => emit(state.copyWith(newFeeRate: fee));
}
