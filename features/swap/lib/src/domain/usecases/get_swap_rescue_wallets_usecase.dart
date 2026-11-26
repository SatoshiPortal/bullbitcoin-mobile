import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart' show SwapsFailure, SwapsUnexpectedFailure;

/// The admitted accounts a rescued swap can pay into on its destination chain.
class GetSwapRescueWalletsUsecase {
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _environment;

  const GetSwapRescueWalletsUsecase({
    required this._inventory,
    required this._environment,
  });

  @useResult
  Future<Result<List<WalletRegistration>, SwapsFailure>> execute({
    required bool actsOnLiquid,
  }) async {
    final settings = await _environment.readActiveEnvironment();
    if (settings case Err(:final failure)) {
      return Err(SwapsUnexpectedFailure('Environment: ${failure.runtimeType}'));
    }
    final environment = (settings as Ok<Environment, PreferencesFailure>).value;
    final Network network = actsOnLiquid
        ? LiquidNetwork.fromName(environment.name)
        : BitcoinNetwork.fromName(environment.name);
    return switch (await _inventory.walletsForNetwork(network)) {
      // An unreadable account may be the one the swap should pay into:
      // offer no destination rather than a silently shorter list.
      Ok(value: WalletSelection(isComplete: false)) => const Err(
        SwapsUnexpectedFailure('Inventory: incomplete'),
      ),
      Ok(:final value) => Ok(value.wallets),
      Err(:final failure) => Err(
        SwapsUnexpectedFailure('Inventory: ${failure.runtimeType}'),
      ),
    };
  }
}
