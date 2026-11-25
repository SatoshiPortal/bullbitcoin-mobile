import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'wallet_details_failure.dart';

class DiscoverWalletUsecase {
  final Future<Result<void, Failure>> Function(String walletId) _discover;

  const DiscoverWalletUsecase(this._discover);

  @useResult
  Future<Result<void, WalletDetailsFailure>> execute(String walletId) async =>
      switch (await _discover(walletId)) {
        Ok() => const Ok(null),
        Err() => const Err(WalletDetailsDiscoveryFailure()),
      };
}
