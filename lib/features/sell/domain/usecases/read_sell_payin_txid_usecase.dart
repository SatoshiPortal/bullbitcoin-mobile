import 'package:sync/sync.dart' show BitcoinTx;
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show decodeLiquidPset;

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
    switch (decodeLiquidPset(signedPset)) {
      case Ok(:final value):
        return Ok(value.txid);
      case Err(:final failure):
        log.severe(
          message: 'Failed to read the txid of the Liquid sell payin',
          error: failure.logCode,
          trace: StackTrace.current,
        );
        return Err(SellUnexpectedFailure(failure.logCode));
    }
  }
}
