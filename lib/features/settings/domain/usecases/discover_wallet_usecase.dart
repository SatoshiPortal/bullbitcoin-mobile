import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:meta/meta.dart';

class DiscoverWalletUsecase {
  final WalletFacade _wallet;

  const DiscoverWalletUsecase(this._wallet);

  @useResult
  Future<Result<void, SettingsFailure>> execute(String walletId) async =>
      switch (await _wallet.discoverWallet(walletId)) {
        Ok() => const Ok(null),
        Err() => const Err(SettingsWalletSyncFailure()),
      };
}
