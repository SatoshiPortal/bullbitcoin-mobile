import 'package:bb_mobile/core_deprecated/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core_deprecated/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/errors.dart';
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

  void clearError() => emit(state.copyWith(error: null));

  void reset() => emit(const ReplaceByFeeState());

  Future<void> broadcast() async {
    try {
      emit(state.copyWith(error: null));

      if (state.newFeeRate == null) {
        emit(state.copyWith(error: NoFeeRateSelectedError()));
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
      emit(state.copyWith(error: TransactionConfirmedError()));
    } on FeeRateTooLowException catch (_) {
      emit(state.copyWith(error: FeeRateTooLowError()));
    } catch (e) {
      emit(state.copyWith(error: GenericError()));
    }
  }

  void onChangeFee(FeeEntity fee) => emit(state.copyWith(newFeeRate: fee));
}
