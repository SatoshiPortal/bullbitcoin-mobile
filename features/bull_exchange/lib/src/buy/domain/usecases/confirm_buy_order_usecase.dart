import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Confirms the quoted buy order through the account's write gate, keeping
/// the payjoin URI its create attached.
class ConfirmBuyOrderUsecase {
  final Exchange _exchange;
  final BuyPayjoinUris _uris;

  const ConfirmBuyOrderUsecase(this._exchange, this._uris);

  Future<ConfirmAnswered<BuyConfirmTarget, BuyOrder>> execute(
    ExchangeSession session,
    ConfirmSend<BuyConfirmTarget> effect,
  ) => runServerConfirm(
    gate: _exchange.writeGate,
    session: session,
    policy: buyConfirmPolicy,
    effect: effect,
    confirm: (target) async => switch (await _exchange
        .orders(session.environment)
        .confirmBuyOrder(target.order.orderId)) {
      Ok(:final value) => Ok(_uris.withBip21(value)),
      Err(:final failure) => Err(failure),
    },
  );
}
