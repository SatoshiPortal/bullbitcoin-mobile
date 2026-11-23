import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';

/// Captures the environment and credential under the same access epoch.
Future<
  Result<
    ({ExchangeEnvironment environment, int epoch, String? apiKey}),
    ExchangeFailure
  >
>
readLegacyExchangeSession({
  required Preferences preferences,
  required int Function() readEpoch,
  required Future<Result<String?, Failure>> Function({required bool isTestnet})
  readKey,
}) async {
  final epoch = readEpoch();
  final settings = await preferences.fetch();
  if (settings case Err()) {
    return const Err(ExchangeAccountUnavailableFailure());
  }
  final environment = switch (settings) {
    Ok(value: SettingsEntity(environment: Environment.mainnet)) =>
      ExchangeEnvironment.mainnet,
    Ok(value: SettingsEntity(environment: Environment.testnet)) =>
      ExchangeEnvironment.testnet,
    _ => null,
  };
  if (environment == null) {
    return const Err(ExchangeUnsupportedNetworkFailure());
  }
  final key = await readKey(
    isTestnet: environment == ExchangeEnvironment.testnet,
  );
  if (readEpoch() != epoch) {
    return const Err(ExchangeOperationStaleFailure());
  }
  return switch (key) {
    Ok(value: final apiKey) => Ok((
      environment: environment,
      epoch: epoch,
      apiKey: apiKey,
    )),
    Err() => const Err(ExchangeCredentialReadFailure()),
  };
}
