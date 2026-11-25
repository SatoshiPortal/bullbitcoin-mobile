import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Reads the account's virtual IBAN; `ReadGot(null)` means none exists yet.
class FindVirtualIbanUsecase {
  final Exchange _exchange;

  const FindVirtualIbanUsecase(this._exchange);

  Future<ExchangeRead<VirtualIban?>> execute(ExchangeSession session) async =>
      readOfResult(await _exchange.virtualIbans.find(session.environment));
}
