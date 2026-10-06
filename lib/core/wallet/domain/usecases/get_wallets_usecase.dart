import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetWalletsUsecase {
  final WalletRepository _wallet;
  final SettingsRepository _settingsRepository;

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
      environment = (await _settingsRepository.fetch()).environment;
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
