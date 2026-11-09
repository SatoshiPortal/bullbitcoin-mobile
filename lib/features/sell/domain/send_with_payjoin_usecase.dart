import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  const SendWithPayjoinUsecase(this._sender);

  /// Starts the payjoin payin for a sell order.
  @useResult
  Future<Result<PayjoinSenderSession, SellFailure>> execute({
    required String walletId,
    required BitcoinNetwork network,
    required String bip21,
    required String unsignedOriginalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    if (!NetworkCapabilities.supports(network, NetworkCapability.payjoin)) {
      return const Err(SellUnexpectedFailure('unsupported network'));
    }
    final result = await _sender.start(
      StartPayjoinSender(
        walletId: walletId,
        network: network,
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
        return Ok(value);
      case Err(failure: PayjoinSpendBlockedFailure()):
        return const Err(SellSpendBlockedFailure());
      case Err(:final failure):
        // Both parts: Failure has no toString() override, so the value alone
        // would log "Instance of 'PayjoinX'" and the message alone drops the
        // type.
        log.warning(
          'Failed to start the Payjoin sale',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return Err(
          SellUnexpectedFailure(
            failure.logMessage ?? 'Failed to start Payjoin sale',
          ),
        );
    }
  }
}
