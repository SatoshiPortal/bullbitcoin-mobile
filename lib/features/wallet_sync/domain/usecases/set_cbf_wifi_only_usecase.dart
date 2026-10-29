import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../wallet_sync_options_failure.dart';

final class SetCbfWifiOnlyUsecase {
  final CbfNetworkPolicyPort _policy;

  const SetCbfWifiOnlyUsecase({required this._policy});

  @useResult
  Future<Result<void, WalletSyncOptionsFailure>> execute(bool enabled) async =>
      (await _policy.setWifiOnly(
        enabled,
      )).mapErr((_) => const WalletSyncOptionsStorageFailure());
}
