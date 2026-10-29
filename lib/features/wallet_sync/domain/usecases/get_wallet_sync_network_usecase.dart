import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetWalletSyncNetworkUsecase {
  final SettingsRepository _settings;

  GetWalletSyncNetworkUsecase({required this._settings});

  @useResult
  Future<Result<BitcoinNetwork, WalletSyncOptionsFailure>> execute() async {
    try {
      final settings = await _settings.fetch();
      return Ok(
        settings.environment.isMainnet
            ? BitcoinNetwork.mainnet
            : BitcoinNetwork.testnet,
      );
    } on Exception {
      return const Err(WalletSyncOptionsStorageFailure());
    }
  }
}
