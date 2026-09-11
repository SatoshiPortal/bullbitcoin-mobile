import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

typedef FetchWalletBackupRemoteHead =
    Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> Function();
typedef FetchWalletBackupImport =
    Future<Result<WalletBackupSnapshot?, WalletBackupFailure>> Function(
      WalletBackupRemoteHead remote,
    );

/// Reads what the server holds for this seed without applying any of it.
///
/// Uses this app's backup identity to fetch, decrypt and show the inventory.
/// Nothing is written, the recovery fence is untouched, and a null result
/// means the server has no backup for this seed.
final class GetRemoteWalletBackupContentsUsecase {
  final FetchWalletBackupRemoteHead _fetchRemote;
  final FetchWalletBackupImport _fetchImport;
  final InspectVaultRecoveryPackage _inspectVault;

  const GetRemoteWalletBackupContentsUsecase({
    required this._fetchRemote,
    required this._fetchImport,
    required this._inspectVault,
  });

  @useResult
  Future<Result<WalletBackupContents?, WalletBackupFailure>> execute() async {
    final WalletBackupRemoteHead remote;
    switch (await _fetchRemote()) {
      case Ok(:final value):
        remote = value;
      case Err(:final failure):
        return Err(failure);
    }
    switch (await _fetchImport(remote)) {
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final snapshot?):
        try {
          return Ok(
            buildWalletBackupContents(
              manifest: snapshot.recoveryManifest,
              definitions: snapshot.externalWalletDefinitions,
              locallyKeyedWalletIds: const {},
              metadata: snapshot.metadata,
              vaults: snapshot.vaults,
              inspectVault: _inspectVault,
            ),
          );
        } on StateError catch (error) {
          return Err(WalletBackupInvalidEnvelopeFailure(error.message));
        }
      case Err(:final failure):
        return Err(failure);
    }
  }
}
