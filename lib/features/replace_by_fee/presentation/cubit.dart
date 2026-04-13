import 'package:bb_mobile/core/bloc/safe_cubit.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/errors.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/state.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter_bloc/flutter_bloc.dart';

class ReplaceByFeeCubit extends SafeCubit<ReplaceByFeeState> {
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
      // Just replacing with a similar bdk_dart error here for migration from bdk_flutter,
      //  but no library errors should leak into the presentation layer,
      //  we should catch them in the usecase and throw application errors instead
    } on bdk.FeeRateTooLowCreateTxException catch (_) {
      emit(state.copyWith(error: FeeRateTooLowError()));
    } catch (e) {
      emit(state.copyWith(error: GenericError()));
    }
  }

  void onChangeFee(FeeEntity fee) => emit(state.copyWith(newFeeRate: fee));
}
