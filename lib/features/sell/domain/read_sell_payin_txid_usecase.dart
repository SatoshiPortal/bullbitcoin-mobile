import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/liquid_tx.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Reads the txid of a payin before it is broadcast.
class ReadSellPayinTxidUsecase {
  const ReadSellPayinTxidUsecase();

  @useResult
  Future<Result<String, SellFailure>> fromPsbt(String unsignedPsbt) async {
    try {
      final tx = await BitcoinTx.fromPsbt(unsignedPsbt);
      return Ok(tx.txid);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the txid of the Bitcoin sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, SellFailure>> fromPset(String signedPset) async {
    try {
      final tx = await LiquidTx.fromPset(signedPset);
      return Ok(tx.txid);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the txid of the Liquid sell payin',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
