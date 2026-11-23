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
  final ExchangeEnvironment environment;
  switch (await readLegacyExchangeEnvironment(preferences)) {
    case Ok(:final value):
      environment = value;
    case Err(:final failure):
      return Err(failure);
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

Future<Result<ExchangeEnvironment, ExchangeFailure>>
readLegacyExchangeEnvironment(Preferences preferences) async =>
    switch (await preferences.fetch()) {
      Err() => const Err(ExchangeAccountUnavailableFailure()),
      Ok(value: SettingsEntity(environment: Environment.mainnet)) => const Ok(
        ExchangeEnvironment.mainnet,
      ),
      Ok(value: SettingsEntity(environment: Environment.testnet)) => const Ok(
        ExchangeEnvironment.testnet,
      ),
      Ok() => const Err(ExchangeUnsupportedNetworkFailure()),
    };
