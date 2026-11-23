import 'package:primitives/primitives.dart' show Ok, Err, Result;
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:overview/overview.dart' show WalletDiscoveryFailure;
import 'package:meta/meta.dart';

class DiscoverWalletUsecase {
  final Future<Result<void, WalletDiscoveryFailure>> Function(String)
  _discoverWallet;

  const DiscoverWalletUsecase(this._discoverWallet);

  @useResult
  Future<Result<void, SettingsFailure>> execute(String walletId) async =>
      switch (await _discoverWallet(walletId)) {
        Ok() => const Ok(null),
        Err() => const Err(SettingsWalletSyncFailure()),
      };
}
