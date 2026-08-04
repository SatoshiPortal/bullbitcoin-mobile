import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:meta/meta.dart';

/// Recomputes the absolute network fee of an already-created sell payin when the
/// user changes coin selection or RBF, by building a throwaway transaction to a
/// wallet-owned address.
class RecalculateSellPayinFeesUsecase {
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  RecalculateSellPayinFeesUsecase({
    required this._getAddressAtIndexUsecase,
    required this._getNetworkFeesUsecase,
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
  });

  @useResult
  Future<Result<int, SellFailure>> execute({
    required Wallet wallet,
    required int amountSat,
    List<WalletUtxo> selectedInputs = const [],
    bool replaceByFee = false,
  }) async {
    try {
      final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
          .execute(walletId: wallet.id, index: 0);

      final int absoluteFees;
      if (wallet.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: amountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: amountSat,
          networkFee: bitcoinFees.fastest,
          selectedInputs: selectedInputs.isNotEmpty ? selectedInputs : null,
          replaceByFee: replaceByFee,
        );
        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
        );
      }

      return Ok(absoluteFees);
    } catch (e, st) {
      log.severe(message: 'sell recalculate fees failed', error: e, trace: st);
      return Err(SellPrepareTransactionFailure(e.toString()));
    }
  }
}
