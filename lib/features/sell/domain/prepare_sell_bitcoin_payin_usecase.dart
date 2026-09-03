import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What a built Bitcoin sell payin is worth knowing about.
typedef PreparedSellBitcoinPayin = ({
  String unsignedPsbt,
  int txSize,
  bool isToSelf,
  int absoluteFees,
});

/// Builds the unsigned PSBT for a Bitcoin sell payin and reports its real fee.
class PrepareSellBitcoinPayinUsecase {
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;

  const PrepareSellBitcoinPayinUsecase({
    required this._prepareBitcoinSendUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
  });

  @useResult
  Future<Result<PreparedSellBitcoinPayin, SellFailure>> execute({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    bool drain = false,
    List<WalletUtxo>? selectedInputs,
    bool replaceByFee = true,
  }) async {
    try {
      final prepared = await _prepareBitcoinSendUsecase.execute(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        amountSat: amountSat,
        drain: drain,
        selectedInputs: selectedInputs,
        replaceByFee: replaceByFee,
      );
      final absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
        psbt: prepared.unsignedPsbt,
      );
      return Ok((
        unsignedPsbt: prepared.unsignedPsbt,
        txSize: prepared.txSize,
        isToSelf: prepared.isToSelf,
        absoluteFees: absoluteFees,
      ));
    } catch (e, st) {
      log.severe(
        message: 'Failed to build the Bitcoin sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
