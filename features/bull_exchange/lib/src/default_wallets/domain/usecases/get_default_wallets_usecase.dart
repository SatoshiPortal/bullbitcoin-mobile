import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Reads the account's exchange default wallets. The exchange serves them
/// for its current session.
class GetDefaultWalletsUsecase {
  final Exchange _exchange;

  const GetDefaultWalletsUsecase(this._exchange);

  Future<ExchangeRead<DefaultWallets>> execute() async =>
      readOfResult(await _exchange.getDefaultWallets());
}
