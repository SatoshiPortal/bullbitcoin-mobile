import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/repositories/portable_backup_repository.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/fetch_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/open_portable_backup_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_and_publish_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_portable_backups_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/publish_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/presentation/portable_backup_cubit.dart';

const testWords =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const privateMetadata = '{"private-label":"never show or publish"}';

final class PortableBackupFake implements PortableBackupRepository {
  final files = PortableBackupFiles(
    metadata: Uint8List.fromList([1, 2, 3]),
    vault: Uint8List.fromList([4, 5, 6]),
  );
  Completer<Result<PortableBackupFiles, PortableBackupFailure>>? preparePending;
  Completer<Result<PortableBackupFetch, PortableBackupFailure>>? fetchPending;
  NostrSession? fetchSession;
  int publishCalls = 0;
  Uint8List? publishedFile;
  Result<String, PortableBackupFailure> publication = const Ok('event-id');

  PortableBackupFetch get recovered => PortableBackupFetch(
    candidates: [
      PortableBackupCandidate(
        artifact: PortableBackupArtifact(
          kind: PortableBackupKind.vault,
          network: 'testnet4',
          contents: 'public vault descriptor',
        ),
        eventId: 'event-id',
        encryptedFile: files.vault,
      ),
    ],
    incomplete: false,
    rejectedEvents: 0,
  );

  PrepareAndPublishPortableVaultUsecase get prepareAndPublish =>
      PrepareAndPublishPortableVaultUsecase(
        PreparePortableBackupsUsecase(this),
        PublishPortableVaultUsecase(this),
      );
  PortableBackupCubit cubit() => PortableBackupCubit(
    prepareAndPublish,
    FetchPortableVaultUsecase(this),
    OpenPortableBackupUsecase(this),
  );

  @override
  Future<Result<PortableBackupFiles, PortableBackupFailure>> prepare({
    required String words,
    required String metadataJson,
    required String descriptor,
    required String network,
  }) async => preparePending == null ? Ok(files) : preparePending!.future;

  @override
  Future<Result<String, PortableBackupFailure>> publish({
    required String words,
    required Uint8List encryptedFile,
    required Uri relay,
    required NostrSession session,
  }) async {
    publishCalls++;
    publishedFile = encryptedFile;
    return publication;
  }

  @override
  Future<Result<PortableBackupFetch, PortableBackupFailure>> fetch({
    required String words,
    required String network,
    required Uri relay,
    required NostrSession session,
  }) async {
    fetchSession = session;
    return fetchPending == null ? Ok(recovered) : fetchPending!.future;
  }

  @override
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> open({
    required String words,
    required Uint8List file,
    required String network,
    required PortableBackupKind kind,
  }) async => Ok(
    PortableBackupArtifact(
      kind: kind,
      network: network,
      contents: privateMetadata,
    ),
  );

  @override
  Future<Result<PortableBackupArtifact, PortableBackupFailure>> openEncoded({
    required String words,
    required String encodedFile,
    required String network,
    required PortableBackupKind kind,
  }) => open(words: words, file: Uint8List(0), network: network, kind: kind);

  @override
  Future<Result<String, PortableBackupFailure>> derivePassword(
    String rootXprv,
  ) async => const Ok(testWords);
}
