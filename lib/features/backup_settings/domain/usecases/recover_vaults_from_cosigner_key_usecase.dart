import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Finds and imports every vault a cosigner's public key can recover.
///
/// The server files records under an opaque alias it cannot check, so what
/// comes back is a pile of candidates: most may belong to other people, and one
/// that will not open is the ordinary case rather than a failure. Each is tried
/// on its own, so a damaged or foreign record never hides the good ones.
final class RecoverVaultsFromCosignerKeyUsecase {
  final WalletBackupFacade _metadata;
  final RecoverVaultFromBip138FileUsecase _openArtifact;

  const RecoverVaultsFromCosignerKeyUsecase(this._metadata, this._openArtifact);

  Future<Result<VaultRecoveryResult, BackupSettingsFailure>> execute(
    String accountKeyInput,
  ) async {
    final found = await _metadata.lookupPrivateDescriptors(accountKeyInput);
    if (found case Err(:final failure)) {
      return Err(mapWalletBackupFailure(failure));
    }
    final page =
        (found as Ok<PrivateDescriptorLookup, WalletBackupFailure>).value;
    final outcomes = <VaultRecoveryOutcome>[];
    for (final record in page.records) {
      outcomes.add(
        await _openArtifact.execute(
          fileBytes: Uint8List.fromList(record.ciphertext),
          accountKeyInput: accountKeyInput,
        ),
      );
    }
    return Ok(
      VaultRecoveryResult(outcomes: outcomes, incomplete: page.incomplete),
    );
  }
}
