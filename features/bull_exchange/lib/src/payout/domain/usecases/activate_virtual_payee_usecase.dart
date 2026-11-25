import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Asks the exchange to activate a recipient as a SEPA virtual payee.
class ActivateVirtualPayeeUsecase {
  final Exchange _exchange;

  const ActivateVirtualPayeeUsecase(this._exchange);

  Future<ExchangeWrite<SepaVirtualPayeeStatus>> execute(
    ExchangeSession session,
    String recipientId,
  ) async => writeOfResult(
    await _exchange.recipients.activate(
      recipientId: recipientId,
      isTestnet: session.environment == ExchangeEnvironment.testnet,
    ),
  );
}
