import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

/// Signs the unsigned sweep PSBT with the wallet's own key.
///
/// Deliberately does not reuse `send`'s equivalent use-case: that would import
/// another feature's internals. The overlap is one repository call.
class SignSweepPsbtUsecase {
  final BitcoinSendPort _bitcoinSend;

  SignSweepPsbtUsecase({required BitcoinSendPort bitcoinSendPort})
    : _bitcoinSend = bitcoinSendPort;

  @useResult
  Future<Result<String, SweepFailure>> execute({
    required String walletId,
    required String unsignedPsbt,
    int? floorSatPerKwu,
  }) async {
    try {
      final signed = await _bitcoinSend.signPsbt(
        unsignedPsbt,
        walletId: walletId,
      );
      if (floorSatPerKwu != null) {
        final txSize = await _bitcoinSend.getTxSize(psbt: signed);
        final feeSat = await _bitcoinSend.getTxFeeAmount(psbt: signed);
        if (!NetworkFee.absolute(
          feeSat,
        ).aboveMinRelay(txSize: txSize, floorSatPerKwu: floorSatPerKwu)) {
          log.warning(
            'Refusing signed sweep below relay floor: $feeSat sats at '
            '$txSize vbytes',
          );
          return const Err(SweepFeeTooLowFailure());
        }
      }
      return Ok(signed);
    } on Exception catch (e, st) {
      // Never log the PSBT itself — it carries the spending policy and, once
      // signed, the signatures.
      log.severe(message: 'Failed to sign sweep psbt', error: e, trace: st);
      return Err(SweepSignFailure(e.toString()));
    }
  }
}
