import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_portable_backups_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/publish_portable_vault_usecase.dart';
import 'package:meta/meta.dart';

final class PrepareAndPublishPortableVaultUsecase {
  final PreparePortableBackupsUsecase _prepare;
  final PublishPortableVaultUsecase _publish;

  const PrepareAndPublishPortableVaultUsecase(this._prepare, this._publish);

  @useResult
  Future<Result<PortableBackupPublication, PortableBackupFailure>> execute({
    required String words,
    required String metadataJson,
    required String descriptor,
    required String network,
    required String relay,
    required NostrSession session,
  }) async {
    if (session.isCancelled) return const Err(PortableBackupCancelledFailure());
    final prepared = await _prepare.execute(
      words: words,
      metadataJson: metadataJson,
      descriptor: descriptor,
      network: network,
    );
    if (session.isCancelled) return const Err(PortableBackupCancelledFailure());
    switch (prepared) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final uri = Uri.tryParse(relay.trim());
        if (uri == null) {
          return Ok(
            PortableBackupPublication(
              files: value,
              publication: const Err(PortableBackupNetworkFailure()),
            ),
          );
        }
        final publication = await _publish.execute(
          words: words,
          encryptedFile: value.vault,
          relay: uri,
          session: session,
        );
        if (session.isCancelled) {
          return const Err(PortableBackupCancelledFailure());
        }
        return Ok(
          PortableBackupPublication(files: value, publication: publication),
        );
    }
  }
}
