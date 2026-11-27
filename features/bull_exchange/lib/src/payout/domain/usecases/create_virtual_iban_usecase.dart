import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Asks the exchange to create the account's virtual IBAN.
class CreateVirtualIbanUsecase {
  final Exchange _exchange;

  const CreateVirtualIbanUsecase(this._exchange);

  Future<Result<VirtualIban, ExchangeWriteFailure>> execute(
    ExchangeSession session,
  ) async =>
      writeOfResult(await _exchange.virtualIbans.create(session.environment));
}
