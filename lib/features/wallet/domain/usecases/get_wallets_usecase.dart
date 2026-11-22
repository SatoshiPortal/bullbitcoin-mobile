import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetWalletsUsecase {
  final WalletRepository _wallet;
  final ActiveEnvironmentReader _settingsRepository;

  GetWalletsUsecase({
    required WalletRepository walletRepository,
    required this._settingsRepository,
  }) : _wallet = walletRepository;

  /// Returns the wallets for the active environment.
  ///
  /// An empty result is [NoWalletsFoundFailure] rather than an empty list:
  /// callers treat "no wallets yet" as a routing decision (send the user to
  /// onboarding), not as data.
  @useResult
  Future<Result<List<Wallet>, WalletFailure>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    final Environment environment;
    try {
      environment = (await _settingsRepository.readActiveEnvironment()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
    } catch (e, st) {
      log.severe(message: 'GetWalletsUsecase: settings', error: e, trace: st);
      return Err(WalletStorageFailure('settings fetch: ${e.runtimeType}'));
    }

    final result = await _wallet.getWallets(
      environment: environment,
      onlyDefaults: onlyDefaults,
      onlyBitcoin: onlyBitcoin,
      onlyLiquid: onlyLiquid,
      sync: sync,
    );

    return switch (result) {
      Ok(value: final wallets) when wallets.isEmpty => const Err(
        NoWalletsFoundFailure('no wallets for the active environment'),
      ),
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(failure),
    };
  }
}
