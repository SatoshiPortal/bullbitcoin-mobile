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
    return (await _inventory.walletsForNetwork(network))
        .map((selection) => selection.wallets)
        .mapErr(
          (failure) =>
              SwapsUnexpectedFailure('Inventory: ${failure.runtimeType}'),
        );
  }
}
