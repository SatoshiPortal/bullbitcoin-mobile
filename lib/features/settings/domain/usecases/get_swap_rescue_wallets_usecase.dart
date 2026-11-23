import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The wallets a rescued swap can pay into: those on the chain the swap acts
/// on, in the active environment.
class GetSwapRescueWalletsUsecase {
  final WalletRepository _walletRepository;
  final Preferences _settingsRepository;

  const GetSwapRescueWalletsUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<List<Wallet>, WalletFailure>> execute({
    required bool actsOnLiquid,
  }) async {
    final Environment environment;
    try {
      environment = ((await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment;
    } catch (e) {
      return Err(WalletStorageFailure('settings fetch: ${e.runtimeType}'));
    }
    return _walletRepository.getWallets(
      environment: environment,
      onlyBitcoin: !actsOnLiquid,
      onlyLiquid: actsOnLiquid,
    );
  }
}
