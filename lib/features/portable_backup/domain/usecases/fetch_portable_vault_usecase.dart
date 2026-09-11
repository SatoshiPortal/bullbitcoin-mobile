import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';

final class FetchPortableVaultUsecase {
  final PortableBackupRepository _repository;
  const FetchPortableVaultUsecase(this._repository);
  @useResult
  Future<Result<PortableBackupFetch, PortableBackupFailure>> execute({
    required String words,
    required String network,
    required Uri relay,
    required NostrSession session,
  }) => _repository.fetch(
    words: words,
    network: network,
    relay: relay,
    session: session,
  );
}
