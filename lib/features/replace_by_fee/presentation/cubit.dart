import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:bb_mobile/features/replace_by_fee/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReplaceByFeeCubit extends Cubit<ReplaceByFeeState> {
  final WalletTransaction originalTransaction;
  final BumpFeeUsecase bumpFeeUsecase;

  ReplaceByFeeCubit({
    required this.originalTransaction,
    required this.bumpFeeUsecase,
  }) : super(const ReplaceByFeeState()) {
    init();
  }

  Future<void> init() async {
    switch (await bumpFeeUsecase.getNetworkFees()) {
      case Ok(:final value):
        // Mempool fees are already RelativeFee (sat/kwu) by construction;
        // the AbsoluteFee branch is unreachable today but kept for exhaustiveness.
        final fastestRate = switch (value.fastest) {
          final RelativeFee r => r,
          AbsoluteFee(:final sats) => NetworkFee.relativeFromAbsoluteAndVsize(
            absoluteSats: sats,
            vsize: originalTransaction.vsize,
          ),
        };
        final originalSatPerVbyte =
            originalTransaction.feeSat / originalTransaction.vsize;
        emit(
          state.copyWith(
            fastestFeeRate: FeeEntity(type: FeeType.fastest, feeRate: fastestRate),
            newFeeRate: FeeEntity(
              type: FeeType.custom,
              feeRate: NetworkFee.relativeFromSatPerVbyte(originalSatPerVbyte + 1),
            ),
            minRelay: value.minRelay,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> broadcast() async {
    emit(state.copyWith(failure: null));

    if (state.newFeeRate == null) {
      emit(state.copyWith(failure: const ReplaceByFeeNoFeeRateSelectedFailure()));
      return;
    }

    // The custom field currently shows a below-floor/empty rate. newFeeRate
    // still holds the last valid value, so without this guard broadcast
    // would fire the stale rate the user no longer sees.
    if (state.customFeeBelowFloor) {
      emit(state.copyWith(failure: const ReplaceByFeeFeeRateTooLowFailure()));
      return;
    }

    switch (await bumpFeeUsecase.execute(
      walletId: originalTransaction.walletId,
      txid: originalTransaction.txId,
      newFeeRate: state.newFeeRate!.feeRate,
    )) {
      case Ok(:final value):
        emit(state.copyWith(txid: value));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  /// A valid (above-floor) selection — from a custom keystroke or the Fastest
  /// tile. Clears any prior below-floor flag and any broadcast failure.
  void onChangeFee(FeeEntity fee) =>
      emit(state.copyWith(newFeeRate: fee, customFeeBelowFloor: false, failure: null));

  /// The custom field went below the relay floor or was emptied. Keep
  /// [newFeeRate] (the last valid value / init sentinel) but flag the field so
  /// [broadcast] refuses the stale rate.
  void markCustomFeeBelowFloor() =>
      emit(state.copyWith(customFeeBelowFloor: true));
}
