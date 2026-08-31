import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  const SendWithPayjoinUsecase(this._sender);

  @useResult
  Future<core.Result<PayjoinSenderSession, SendFailure>> execute({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String unsignedOriginalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    final result = await _sender.start(
      StartPayjoinSender(
        walletId: walletId,
        network: isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet,
        bip21Uri: bip21,
        unsignedOriginalPsbt: unsignedOriginalPsbt,
        amount: Sats.fromInt(amountSat),
        feeRate: FeeRate(networkFeesSatPerVb),
        expiresAt: expireAfterSec == null
            ? null
            : DateTime.now().add(Duration(seconds: expireAfterSec)),
      ),
    );
    switch (result) {
      case Ok(:final value):
        return core.Ok(value);
      case Err(:final failure):
        log.warning(
          'Failed to start Payjoin send',
          error: failure.logMessage ?? failure.runtimeType.toString(),
        );
        return core.Err(
          SendTransactionConfirmationFailure(
            logMessage: failure.logMessage ?? 'Failed to start Payjoin send',
          ),
        );
    }
  }
}
