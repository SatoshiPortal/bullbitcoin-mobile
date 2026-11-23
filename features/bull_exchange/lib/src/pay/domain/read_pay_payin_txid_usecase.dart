import 'package:sync/sync.dart' show BitcoinTx;
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show decodeLiquidPset;

/// Reads the txid of a payin from the transaction that was broadcast, for a
/// broadcast whose outcome is unknown.
class ReadPayPayinTxidUsecase {
  const ReadPayPayinTxidUsecase();

  @useResult
  Future<Result<String, PayFailure>> fromPsbt(String unsignedPsbt) async {
    try {
      final tx = await BitcoinTx.fromPsbt(unsignedPsbt);
      return Ok(tx.txid);
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the txid of the Bitcoin pay payin',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<String, PayFailure>> fromPset(String signedPset) async {
    switch (decodeLiquidPset(signedPset)) {
      case Ok(:final value):
        return Ok(value.txid);
      case Err(:final failure):
        log.severe(
          message: 'Failed to read the txid of the Liquid pay payin',
          error: failure.logCode,
          trace: StackTrace.current,
        );
        return Err(PayUnexpectedFailure(failure.logCode));
    }
  }
}
