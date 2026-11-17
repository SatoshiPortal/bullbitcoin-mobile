import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

/// Binds an already parsed scanner result before it can be reviewed/imported.
class CaptureWatchOnlyNetworkUsecase {
  const CaptureWatchOnlyNetworkUsecase();

  @useResult
  Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure> execute(
    WatchOnlyWalletEntity wallet, {
    required NetworkEnv environment,
  }) {
    try {
      return Ok(wallet.captureEnvironment(environment));
    } on WatchOnlyNetworkMismatchException {
      return const Err(NetworkMismatchFailure());
    } on FormatException {
      return const Err(InvalidFormatFailure());
    }
  }
}
