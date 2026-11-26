import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Settles a journaled save by re-reading (never by sending it again), then
/// reads what the exchange has for [ExchangeSession]'s account. A journal
/// that can't be reconciled is logged; the read still runs.
class VerifyDefaultWalletsUsecase {
  final Exchange _exchange;

  const VerifyDefaultWalletsUsecase(this._exchange);

  Future<ExchangeRead<DefaultWallets>> execute(ExchangeSession session) async {
    if (await _exchange.reconcileUnknownWrites() case Err(:final failure)) {
      log.warning('Default wallets: journal not reconciled ($failure)');
    }
    return _exchange.readDefaultWallets(session);
  }
}
