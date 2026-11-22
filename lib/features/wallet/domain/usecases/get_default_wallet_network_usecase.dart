import 'package:meta/meta.dart';
import 'package:primitives/generic_extensions.dart';
import 'package:primitives/primitives.dart';

import '../wallet_failure.dart';
import 'get_wallets_usecase.dart';

/// The environment whose services the default wallet uses.
class GetDefaultWalletNetworkUsecase {
  final GetWalletsUsecase _getWallets;

  const GetDefaultWalletNetworkUsecase(this._getWallets);

  @useResult
  Future<Result<NetworkEnv?, WalletFailure>> execute() async =>
      switch (await _getWallets.execute()) {
        Ok(:final value) => Ok(
          value
              .firstWhereOrNull((wallet) => wallet.isDefault)
              ?.network
              .environment,
        ),
        Err(failure: NoWalletsFoundFailure()) => const Ok(null),
        Err(:final failure) => Err(failure),
      };
}
