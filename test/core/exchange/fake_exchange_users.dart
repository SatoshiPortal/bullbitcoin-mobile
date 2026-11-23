import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';

abstract interface class ExchangeUserOperations {
  Future<Result<UserSummary, ExchangeFailure>> getUserSummary();

  Future<Result<List<Announcement>, ExchangeFailure>> listAnnouncements();

  Future<Result<void, ExchangeFailure>> saveUserPreference({
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  });
}

Exchange fakeExchangeUsers(
  ExchangeUserOperations mainnet,
  ExchangeUserOperations testnet, {
  ExchangeOrders Function(ExchangeEnvironment)? orders,
  Future<Result<DefaultWallets, ExchangeFailure>> Function()? getDefaultWallets,
}) {
  ExchangeUserOperations select(ExchangeEnvironment? environment) =>
      environment == ExchangeEnvironment.mainnet ? mainnet : testnet;
  return exchangeForTesting(
    orders: orders,
    getDefaultWallets: getDefaultWallets,
    getUserSummary: (environment) => select(environment).getUserSummary(),
    listAnnouncements: (environment) => select(environment).listAnnouncements(),
    saveUserPreference:
        (
          environment, {
          language,
          currency,
          dcaEnabled,
          autoBuyEnabled,
          emailNotificationsEnabled,
        }) => select(environment).saveUserPreference(
          language: language,
          currency: currency,
          dcaEnabled: dcaEnabled,
          autoBuyEnabled: autoBuyEnabled,
          emailNotificationsEnabled: emailNotificationsEnabled,
        ),
  );
}
