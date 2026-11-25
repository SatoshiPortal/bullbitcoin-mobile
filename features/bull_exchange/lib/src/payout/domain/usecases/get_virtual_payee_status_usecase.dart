import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the SEPA virtual payee status of a recipient; a recipient the
/// exchange has no status for is [ReadMissing].
class GetVirtualPayeeStatusUsecase {
  final Exchange _exchange;

  const GetVirtualPayeeStatusUsecase(this._exchange);

  Future<ExchangeRead<SepaVirtualPayeeStatus>> execute(
    ExchangeSession session,
    String recipientId,
  ) async => switch (await _exchange.recipients.findStatus(
    recipientId: recipientId,
    isTestnet: session.environment == ExchangeEnvironment.testnet,
  )) {
    Ok(value: final SepaVirtualPayeeStatus status) => ReadGot(status),
    Ok(value: null) => const ReadMissing(),
    Err(:final failure) => readOfExchangeFailure(failure),
  };
}
