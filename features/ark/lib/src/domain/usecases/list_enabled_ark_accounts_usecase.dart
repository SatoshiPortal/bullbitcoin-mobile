import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_account_registry_repository.dart';
import '../repositories/ark_preferences_repository.dart';

/// Local inventory and routing preference only. Pasting an address never opens
/// bark or a source wallet, and never treats an unreadable inventory as empty.
final class ListEnabledArkAccountsUsecase {
  final ArkAccountRegistryRepository _registry;
  final ArkPreferencesRepository _preferences;
  const ListEnabledArkAccountsUsecase(this._registry, this._preferences);
  Future<Result<List<ArkAccountId>, ArkFailure>> execute(
    BitcoinNetwork network,
  ) async {
    if (!NetworkCapabilities.supports(network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    switch (await _registry.list()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final accounts = <ArkAccountId>[];
        for (final config in value.where(
          (config) => config.id.network == network,
        )) {
          switch (await _preferences.isEnabled(config.id)) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: true):
              accounts.add(config.id);
            case Ok():
              break;
          }
        }
        return Ok(List.unmodifiable(accounts));
    }
  }
}
