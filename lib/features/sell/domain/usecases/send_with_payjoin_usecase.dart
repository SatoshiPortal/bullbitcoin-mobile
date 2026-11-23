import 'package:bb_mobile/features/transactions/public/prepare_payjoin_original.dart';
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SendWithPayjoinUsecase {
  final PayjoinSender _sender;

  final Spend _spend;

  const SendWithPayjoinUsecase(this._sender, this._spend);

  /// Starts the payjoin payin for a sell order.
  @useResult
  Future<Result<PayjoinSenderSession, SellFailure>> execute({
    required String walletId,
    required BitcoinNetwork network,
    required String bip21,
    required PreparedBitcoinSpend prepared,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    if (!NetworkCapabilities.supports(network, NetworkCapability.payjoin)) {
      return const Err(SellUnexpectedFailure('unsupported network'));
    }
    final PreparedPayjoinOriginal original;
    switch (await preparePayjoinOriginal(
      spend: _spend,
      prepared: prepared,
      walletId: walletId,
      network: network,
    )) {
      case Ok(:final value):
        original = value;
      case Err(failure: SpendUnavailableFailure(:final busy)):
        return Err(SellSpendBlockedFailure(busy: busy));
      case Err():
        return const Err(SellUnexpectedFailure());
    }
    final result = await _sender.start(
      StartPayjoinSender(
        walletId: walletId,
        network: network,
        bip21Uri: bip21,
        unsignedOriginalPsbt: prepared.unsignedPsbt,
        preparedOriginal: original,
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
      case Err(failure: PayjoinSpendBlockedFailure(:final busy)):
        return Err(SellSpendBlockedFailure(busy: busy));
      case Err(failure: PayjoinPublicationUnknownFailure(:final originalTxId)):
        return Err(SellPayinOutcomeUnknownFailure(originalTxId: originalTxId));
      case Err(failure: PayjoinSenderKeptFailure(:final logMessage)):
        log.warning(
          'Sell Payjoin post failed; the session is kept',
          error: logMessage ?? '-',
        );
        return Err(SellPayjoinSessionKeptFailure(logMessage));
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
