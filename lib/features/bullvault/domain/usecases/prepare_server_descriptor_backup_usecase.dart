import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/vault_descriptor_publication_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_private_descriptor_backup_usecase.dart';
import 'package:meta/meta.dart';

/// The exact BIP138 artifact this vault owes the descriptor server.
///
/// Sealing draws a fresh nonce and fresh decoys, so a second sealing is a
/// second immutable record on the server. The bytes are therefore written down
/// the first time and handed back unchanged afterwards; only the recipients and
/// their lookup aliases, which are deterministic, are re-derived from the vault
/// that is in force. Nothing here talks to the server: that is the caller's.
final class PrepareServerDescriptorBackupUsecase {
  final EncodePrivateDescriptorBackupUsecase _encode;
  final VaultDescriptorPublicationRepository _publications;

  const PrepareServerDescriptorBackupUsecase(this._encode, this._publications);

  @useResult
  Future<Result<BullVaultDescriptorBackup, BullVaultFailure>> execute(
    String walletId,
  ) async {
    final BullVaultDescriptorBackup fresh;
    switch (await _encode.execute(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        fresh = value;
    }
    switch (await _publications.load(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final stored = value
            .where((row) => row.destination == VaultBackupDestination.server)
            .map((row) => row.artifact)
            .firstOrNull;
        if (stored != null) {
          return Ok(
            BullVaultDescriptorBackup(
              descriptor: fresh.descriptor,
              network: fresh.network,
              bytes: stored,
              recipients: fresh.recipients,
              lookupTokens: fresh.lookupTokens,
            ),
          );
        }
    }
    final prepared = await _publications.prepare(
      walletId: walletId,
      destination: VaultBackupDestination.server,
      artifact: fresh.bytes,
    );
    // Nothing is sent until the bytes survive a restart.
    return switch (prepared) {
      Err(:final failure) => Err(failure),
      Ok() => Ok(fresh),
    };
  }
}
