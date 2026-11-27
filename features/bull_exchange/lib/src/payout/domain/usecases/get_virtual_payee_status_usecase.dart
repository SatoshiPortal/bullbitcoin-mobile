import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the SEPA virtual payee status of a recipient; a recipient the
/// exchange has no status for is [ExchangeMissingFailure].
class GetVirtualPayeeStatusUsecase {
  final Exchange _exchange;

  const GetVirtualPayeeStatusUsecase(this._exchange);

  Future<Result<SepaVirtualPayeeStatus, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String recipientId,
  ) async => switch (await _exchange.recipients.findStatus(
    recipientId: recipientId,
    isTestnet: session.environment == ExchangeEnvironment.testnet,
  )) {
    Ok(value: final SepaVirtualPayeeStatus status) => Ok(status),
    Ok(value: null) => const Err(ExchangeMissingFailure()),
    Err(:final failure) => readOfExchangeFailure(failure),
  };
}
