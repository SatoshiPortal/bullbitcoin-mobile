import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
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
    return wallet
        .validatedInput(environment)
        .map(
          (input) => WatchOnlyWalletEntity.fromInput(input).copyWith(
            label: wallet.label,
            signer: environment == NetworkEnv.regtest
                ? SignerEntity.none
                : wallet.signer,
          ),
        );
  }
}
