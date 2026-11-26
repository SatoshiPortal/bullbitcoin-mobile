import 'package:bull_exchange/src/buy/domain/buy_payjoin.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';

/// Cancels the payjoin receiver of an abandoned quote, with the URI its
/// create attached; only one whose payin never started
/// ([releaseBuyPayjoin]).
class ReleaseBuyPayjoinUsecase {
  final PayjoinSessions _payjoinSessions;
  final PayjoinReceiver _payjoinReceiver;
  final BuyPayjoinUris _uris;

  const ReleaseBuyPayjoinUsecase(
    this._payjoinSessions,
    this._payjoinReceiver,
    this._uris,
  );

  Future<void> execute(BuyOrder order) => releaseBuyPayjoin(
    _payjoinSessions,
    _payjoinReceiver,
    _uris.withBip21(order),
  );
}
