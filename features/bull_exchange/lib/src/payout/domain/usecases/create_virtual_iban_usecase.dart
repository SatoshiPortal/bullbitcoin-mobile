import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Asks the exchange to create the account's virtual IBAN.
class CreateVirtualIbanUsecase {
  final Exchange _exchange;

  const CreateVirtualIbanUsecase(this._exchange);

  Future<ExchangeWrite<VirtualIban>> execute(ExchangeSession session) async =>
      writeOfResult(await _exchange.virtualIbans.create(session.environment));
}
