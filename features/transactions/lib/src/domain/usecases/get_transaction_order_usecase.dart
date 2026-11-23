import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/src/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads the exchange order behind a transaction.
class GetTransactionOrderUsecase {
  final Exchange _exchange;
  final Preferences _preferences;

  const GetTransactionOrderUsecase(this._exchange, this._preferences);

  @useResult
  Future<Result<Order, TransactionFailure>> execute(String orderId) async {
    final settings = await _preferences.fetch();
    final environment = switch (settings) {
      Ok(value: SettingsEntity(environment: Environment.mainnet)) =>
        ExchangeEnvironment.mainnet,
      Ok(value: SettingsEntity(environment: Environment.testnet)) =>
        ExchangeEnvironment.testnet,
      _ => null,
    };
    if (environment == null) {
      return const Err(
        TransactionUnexpectedFailure('Order environment unavailable'),
      );
    }
    switch (await _exchange.orders(environment).getOrder(orderId)) {
      case Ok(:final value):
        return Ok(value);
      case Err(failure: final e):
        log.severe(
          message: 'Failed to load the order of a transaction',
          error: e.runtimeType,
          trace: StackTrace.current,
        );
        return Err(
          TransactionUnexpectedFailure('getOrder failed: ${e.runtimeType}'),
        );
    }
  }
}
