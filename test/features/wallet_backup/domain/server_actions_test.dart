import 'dart:async';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_files_usecase.dart'
    show DecodeWalletBackupFileUsecase;
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_codec_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Catalog extends Mock implements KeychainManifestFacade {}

class _Wallets extends Mock implements WalletInventoryBackupRepository {}

class _Vaults extends Mock implements BullVaultBackupRepository {}

class _Metadata extends Mock implements WalletMetadataBackupRepository {}

class _VaultCodec extends Mock implements BullVaultFacade {}

T value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;

class _Remote implements WalletBackupRemoteRepository {
  WalletBackupRemoteHead head = WalletBackupRemoteHead(
    generation: 0,
    etag: null,
  );
  int fetches = 0, deletes = 0, stores = 0;
  bool unavailable = false, loseStoreReply = false;
  bool loseDeleteReply = false;
  Future<void> Function()? afterDelete;
  void install(BackupCredential credential, WalletBackupCiphertext ciphertext) {
    final generation = head.generation + 1;
    head = WalletBackupRemoteHead(
      generation: generation,
      etag: BackupServerProtocol.etag(
        identity: credential.serverPublicKey,
        generation: generation,
        ciphertextHash: ciphertext.hash,
      ),
      ciphertext: ciphertext,
      updatedAt: DateTime.utc(2026, 9, 18),
    );
  }

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch(
    BackupCredential credential,
  ) async {
    fetches++;
    if (unavailable) return const Err(WalletBackupNetworkFailure());
    return Ok(head);
  }

  @override
  Future<Result<WalletBackupCheckpoint, WalletBackupFailure>> store(
    BackupCredential credential,
    WalletBackupCiphertext ciphertext, {
    required int generation,
    required String? expectedEtag,
  }) async {
    stores++;
    if (unavailable) return const Err(WalletBackupNetworkFailure());
    if (expectedEtag != head.etag || generation != head.generation + 1) {
      return const Err(WalletBackupConflictFailure());
    }
    install(credential, ciphertext);
    if (loseStoreReply) {
      loseStoreReply = false;
      return const Err(WalletBackupNetworkFailure());
    }
    return Ok(
      WalletBackupCheckpoint(
        generation: head.generation,
        etag: head.etag!,
        ciphertextHash: ciphertext.hash,
      ),
    );
  }

  @override
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> delete(
    BackupCredential credential, {
    required int generation,
    required String expectedEtag,
  }) async {
    deletes++;
    if (expectedEtag != head.etag || generation != head.generation + 1) {
      return const Err(WalletBackupConflictFailure());
    }
    head = WalletBackupRemoteHead(
      generation: generation,
      etag: BackupServerProtocol.etag(
        identity: credential.serverPublicKey,
        generation: generation,
        ciphertextHash: null,
      ),
      updatedAt: DateTime.utc(2026, 9, 18),
    );
    final deleted = head;
    await afterDelete?.call();
    if (loseDeleteReply) {
      loseDeleteReply = false;
      return const Err(WalletBackupNetworkFailure());
    }
    return Ok(deleted);
  }
}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final snapshot = backupSnapshotFixture(credential, populated: false);
  final codec = WalletBackupCodecRepositoryImpl(_VaultCodec());
  late SqliteDatabase database;
  late DriftWalletBackupStateRepository state;
  late WalletBackupOperationQueue operations;
  late _Identity identity;
  late _Catalog catalog;
  late _Wallets wallets;
  late _Vaults vaults;
  late _Metadata metadata;
  late _Remote remote;
  late InspectWalletBackupUsecase inspect;
  late RecoverWalletBackupUsecase recover;
  late DeleteWalletBackupUsecase delete;
  late CompareWalletBackupFileUsecase compareFile;
  late RecoverWalletBackupFileUsecase recoverFile;
  var mutations = 0;
  late WalletBackupCiphertext ciphertext;

  setUpAll(() {
    registerFallbackValue(snapshot.manifest);
    registerFallbackValue(snapshot.metadata);
  });
  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    state = DriftWalletBackupStateRepository(database);
    operations = WalletBackupOperationQueue();
    identity = _Identity();
    catalog = _Catalog();
    wallets = _Wallets();
    vaults = _Vaults();
    metadata = _Metadata();
    remote = _Remote();
    mutations = 0;
    when(identity.resolve).thenAnswer((_) async => Ok(credential));
    when(
      () => identity.fromWords(backupFixtureWords),
    ).thenReturn(Ok(credential));
    when(
      () => identity.fromWords('wrong'),
    ).thenReturn(const Err(InvalidDataRecoveryWords()));
    when(() => catalog.restorePublicRecords(any())).thenAnswer((_) async {
      mutations++;
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
      return const Ok(null);
    });
    when(() => wallets.restore([])).thenAnswer(
      (_) async => Ok(
        WalletInventoryRecovery(walletReferences: {}, failedReferences: []),
      ),
    );
    when(() => vaults.restore([], [])).thenAnswer(
      (_) async => Ok(
        WalletInventoryRecovery(walletReferences: {}, failedReferences: []),
      ),
    );
    when(
      () => metadata.apply(any(), {}),
    ).thenAnswer((_) async => const Ok(null));
    final apply = ApplyWalletBackupSnapshotUsecase(
      state: state,
      codec: codec,
      catalog: catalog,
      wallets: wallets,
      vaults: vaults,
      metadata: metadata,
    );
    inspect = InspectWalletBackupUsecase(
      identity: identity,
      remote: remote,
      codec: codec,
    );
    recover = RecoverWalletBackupUsecase(
      operations: operations,
      identity: identity,
      state: state,
      remote: remote,
      codec: codec,
      apply: apply,
    );
    delete = DeleteWalletBackupUsecase(
      operations: operations,
      identity: identity,
      state: state,
      remote: remote,
    );
    final decodeFile = DecodeWalletBackupFileUsecase(
      identity: identity,
      codec: codec,
    );
    compareFile = CompareWalletBackupFileUsecase(
      decode: decodeFile,
      inspect: inspect,
      state: state,
      codec: codec,
    );
    recoverFile = RecoverWalletBackupFileUsecase(
      operations: operations,
      identity: identity,
      state: state,
      remote: remote,
      codec: codec,
      decode: decodeFile,
      apply: apply,
      recoverRemote: recover,
    );
    ciphertext = value(codec.encrypt(snapshot, credential));
    remote.install(credential, ciphertext);
  });
  tearDown(() => database.close());

  Future<WalletBackupInspection> inspection() async =>
      value(await inspect.execute());
  Future<void> checkpoint() async {
    value(
      await state.recordPublication(
        identity: credential.serverPublicKey,
        expectedEtag: null,
        checkpoint: WalletBackupCheckpoint(
          generation: remote.head.generation,
          etag: remote.head.etag!,
          ciphertextHash: ciphertext.hash,
        ),
        contentHash: value(codec.contentHash(snapshot)),
        succeededAt: DateTime.utc(2026, 9, 18),
      ),
    );
  }

  test('inspection is read-only even when automatic backup is off', () async {
    value(await state.setEnabled(false));
    final result = await inspection();
    expect(result.snapshot, isNotNull);
    expect(result.identity, credential.serverPublicKey);
    expect(remote.fetches, 1);
    expect(mutations, 0);
    expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    expect(
      value(await state.get(credential.serverPublicKey)).checkpoint,
      isNull,
    );
  });
  test(
    'invalid words never contact the server; absence is a normal inspection',
    () async {
      expect(await inspect.execute(words: 'wrong'), isA<Err>());
      expect(remote.fetches, 0);
      remote.head = WalletBackupRemoteHead(generation: 0, etag: null);
      expect((await inspection()).snapshot, isNull);
      expect(mutations, 0);
    },
  );
  test(
    'words recover without a local seed and preserve disabled consent',
    () async {
      value(await state.setEnabled(false));
      when(
        identity.resolve,
      ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
      final selected = value(await inspect.execute(words: backupFixtureWords));
      final result = value(
        await recover.execute(selected, words: backupFixtureWords),
      );
      expect(result.complete, isTrue);
      expect(mutations, 1);
      expect(value(await state.getControl()).enabled, isFalse);
      final stored = value(await state.get(credential.serverPublicKey));
      expect(stored.checkpoint!.etag, selected.head.etag);
      expect(stored.confirmedContentHash, value(codec.contentHash(snapshot)));
      expect(stored.lastSuccessAt, remote.head.updatedAt);
    },
  );
  test('a changed inspected head fails before any owner mutation', () async {
    final selected = await inspection();
    remote.install(credential, ciphertext);
    expect(await recover.execute(selected), isA<Err>());
    expect(mutations, 0);
    expect(value(await state.getControl()).recoveryIncomplete, isFalse);
  });
  test(
    'remote edits during recovery leave the fence, and a newly inspected retry can finish',
    () async {
      final selected = await inspection();
      when(() => metadata.apply(any(), {})).thenAnswer((_) async {
        remote.install(credential, ciphertext);
        return const Ok(null);
      });
      final first = value(await recover.execute(selected));
      expect(first.complete, isFalse);
      expect(first.failure, isA<WalletBackupConflictFailure>());
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
      expect(
        value(await state.get(credential.serverPublicKey)).checkpoint,
        isNull,
      );
      when(
        () => metadata.apply(any(), {}),
      ).thenAnswer((_) async => const Ok(null));
      final retried = value(
        await recover.execute(await inspection(), enableAfterRecovery: true),
      );
      expect(retried.complete, isTrue);
      expect(value(await state.getControl()).enabled, isTrue);
      expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    },
  );
  test('partial recovery cannot acknowledge or enable backup', () async {
    when(
      () => metadata.apply(any(), {}),
    ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));
    final result = value(
      await recover.execute(await inspection(), enableAfterRecovery: true),
    );
    expect(result.complete, isFalse);
    expect(value(await state.getControl()).enabled, isNot(isTrue));
    expect(value(await state.getControl()).recoveryIncomplete, isTrue);
    expect(
      value(await state.get(credential.serverPublicKey)).checkpoint,
      isNull,
    );
  });
  test(
    'seedless words recovery cannot enable a different or absent default identity',
    () async {
      final selected = await inspection();
      when(
        identity.resolve,
      ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
      expect(
        await recover.execute(
          selected,
          words: backupFixtureWords,
          enableAfterRecovery: true,
        ),
        isA<Err>(),
      );
      expect(mutations, 0);
    },
  );
  test(
    'delete requires confirmation and backup off before network access',
    () async {
      expect(await delete.execute(confirmed: false), isA<Err>());
      value(await state.setEnabled(true));
      expect(await delete.execute(confirmed: true), isA<Err>());
      expect(remote.fetches, 0);
      expect(remote.deletes, 0);
    },
  );
  test(
    'delete verifies absence and clears only the checkpoint, leaving backup off',
    () async {
      await checkpoint();
      value(await state.setEnabled(false));
      expect(await delete.execute(confirmed: true), isA<Ok>());
      expect(remote.deletes, 1);
      expect(remote.fetches, 2);
      expect(remote.head.found, isFalse);
      final local = value(await state.get(credential.serverPublicKey));
      expect(local.checkpoint, isNull);
      expect(local.lastSuccessAt, isNull);
      expect(local.enabled, isFalse);
    },
  );
  test(
    'a lost delete response leaves the checkpoint until a retry verifies absence',
    () async {
      await checkpoint();
      value(await state.setEnabled(false));
      remote.loseDeleteReply = true;
      expect(await delete.execute(confirmed: true), isA<Err>());
      expect(
        value(await state.get(credential.serverPublicKey)).checkpoint,
        isNotNull,
      );
      expect(await delete.execute(confirmed: true), isA<Ok>());
      expect(remote.deletes, 1);
      expect(
        value(await state.get(credential.serverPublicKey)).checkpoint,
        isNull,
      );
    },
  );
  test(
    'a concurrent server replacement prevents false deletion success',
    () async {
      await checkpoint();
      value(await state.setEnabled(false));
      remote.afterDelete = () async => remote.install(credential, ciphertext);
      expect(await delete.execute(confirmed: true), isA<Err>());
      expect(
        value(await state.get(credential.serverPublicKey)).checkpoint,
        isNotNull,
      );
    },
  );
  test(
    'queued deletion waits for the earlier operation, and later work observes off and no head',
    () async {
      await checkpoint();
      value(await state.setEnabled(false));
      final gate = Completer<void>();
      final previous = operations.run(() => gate.future);
      final deleting = delete.execute(confirmed: true);
      final following = operations.run(() async {
        expect(value(await state.getControl()).enabled, isFalse);
        expect(remote.head.found, isFalse);
      });
      await Future<void>.delayed(Duration.zero);
      expect(remote.deletes, 0);
      gate.complete();
      await previous;
      expect(await deleting, isA<Ok>());
      await following;
    },
  );
  test(
    'an already absent copy clears stale local status without a deletion write',
    () async {
      await checkpoint();
      value(await state.setEnabled(false));
      remote.head = WalletBackupRemoteHead(generation: 0, etag: null);
      expect(await delete.execute(confirmed: true), isA<Ok>());
      expect(remote.deletes, 0);
      expect(
        value(await state.get(credential.serverPublicKey)).checkpoint,
        isNull,
      );
    },
  );

  test(
    'turning off takes effect during an operation; enabling waits in the queue',
    () async {
      final enable = SetWalletBackupEnabledUsecase(
        operations: operations,
        identity: identity,
        state: state,
      );
      value(await state.setEnabled(true));
      final gate = Completer<void>();
      final running = operations.run(() => gate.future);
      expect(await enable.execute(false), isA<Ok>());
      expect(value(await state.getControl()).enabled, isFalse);
      var completed = false;
      final enabling = enable.execute(true).then((result) {
        expect(result, isA<Ok>());
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      gate.complete();
      await running;
      await enabling;
      expect(value(await state.getControl()).enabled, isTrue);
    },
  );

  WalletBackupSnapshot selectedFileSnapshot() => WalletBackupSnapshot(
    manifest: snapshot.manifest,
    vaults: snapshot.vaults,
    metadata: WalletMetadataBackup(
      labels: [
        LabelEntity(
          id: 0,
          type: LabelType.address,
          label: 'Chosen file',
          reference: 'fixture-address',
        ),
      ],
      frozenOutputs: snapshot.metadata.frozenOutputs,
      settings: snapshot.metadata.settings,
    ),
  );
  String selectedFile() => value(
    codec.encodeFile(
      selectedFileSnapshot(),
      credential,
      format: WalletBackupFileFormat.readable,
    ),
  );

  test(
    'file comparison reports same, different sections, absent and unavailable without applying',
    () async {
      final same = value(
        await compareFile.execute(
          value(
            codec.encodeFile(
              snapshot,
              credential,
              format: WalletBackupFileFormat.encrypted,
            ),
          ),
        ),
      );
      expect(same.situation, WalletBackupImportSituation.same);
      final different = value(await compareFile.execute(selectedFile()));
      expect(different.situation, WalletBackupImportSituation.different);
      expect(different.differences, {WalletBackupDifference.metadata});
      expect(mutations, 0);
      remote.head = WalletBackupRemoteHead(generation: 0, etag: null);
      expect(
        value(await compareFile.execute(selectedFile())).situation,
        WalletBackupImportSituation.automaticBackupDisabled,
      );
      value(await state.setEnabled(true));
      expect(
        value(await compareFile.execute(selectedFile())).situation,
        WalletBackupImportSituation.noServerBackup,
      );
      remote.unavailable = true;
      expect(
        value(await compareFile.execute(selectedFile())).situation,
        WalletBackupImportSituation.serverUnavailable,
      );
      expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    },
  );
  test(
    'choosing a file with automatic backup off applies locally without writing the server',
    () async {
      value(await state.setEnabled(false));
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      final result = value(
        await recoverFile.execute(
          source,
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      );
      expect(result.complete, isTrue);
      expect(remote.stores, 0);
      expect(mutations, 1);
      expect(value(await state.getControl()).enabled, isFalse);
    },
  );
  test(
    'choosing a file with backup on replaces the inspected head and acknowledges exactly the selected copy',
    () async {
      value(await state.setEnabled(true));
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      final result = value(
        await recoverFile.execute(
          source,
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      );
      expect(result.complete, isTrue);
      expect(remote.stores, 1);
      final restored = value(
        codec.decrypt(remote.head.ciphertext!, credential),
      );
      expect(
        value(codec.contentHash(restored)),
        value(codec.contentHash(selectedFileSnapshot())),
      );
      final local = value(await state.get(credential.serverPublicKey));
      expect(
        local.confirmedContentHash,
        value(codec.contentHash(selectedFileSnapshot())),
      );
      expect(local.checkpoint!.etag, remote.head.etag);
      expect(local.recoveryIncomplete, isFalse);
    },
  );
  test(
    'choosing the server applies the single inspected server copy instead of the file',
    () async {
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      when(() => metadata.apply(any(), {})).thenAnswer((call) async {
        expect(
          (call.positionalArguments.first as WalletMetadataBackup).labels,
          isEmpty,
        );
        return const Ok(null);
      });
      final result = value(
        await recoverFile.execute(
          source,
          comparison: comparison,
          source: WalletBackupImportSource.server,
          confirmed: true,
        ),
      );
      expect(result.complete, isTrue);
      expect(remote.stores, 0);
    },
  );
  test('a stale file/server comparison prevents mutation', () async {
    value(await state.setEnabled(true));
    final source = selectedFile();
    final comparison = value(await compareFile.execute(source));
    remote.install(credential, ciphertext);
    expect(
      await recoverFile.execute(
        source,
        comparison: comparison,
        source: WalletBackupImportSource.file,
        confirmed: true,
      ),
      isA<Err>(),
    );
    expect(mutations, 0);
    expect(remote.stores, 0);
  });
  test(
    'a server edit during file application leaves the fence and prevents overwrite',
    () async {
      value(await state.setEnabled(true));
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      when(() => metadata.apply(any(), {})).thenAnswer((_) async {
        remote.install(credential, ciphertext);
        return const Ok(null);
      });
      final result = value(
        await recoverFile.execute(
          source,
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      );
      expect(result.complete, isFalse);
      expect(remote.stores, 0);
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
    },
  );
  test('partial file recovery never replaces the remote copy', () async {
    value(await state.setEnabled(true));
    final source = selectedFile();
    final comparison = value(await compareFile.execute(source));
    when(
      () => metadata.apply(any(), {}),
    ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));
    final result = value(
      await recoverFile.execute(
        source,
        comparison: comparison,
        source: WalletBackupImportSource.file,
        confirmed: true,
      ),
    );
    expect(result.complete, isFalse);
    expect(remote.stores, 0);
    expect(value(await state.getControl()).recoveryIncomplete, isTrue);
  });
  test(
    'a lost file replacement reply remains fenced and retry recognizes accepted content',
    () async {
      value(await state.setEnabled(true));
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      remote.loseStoreReply = true;
      expect(
        value(
          await recoverFile.execute(
            source,
            comparison: comparison,
            source: WalletBackupImportSource.file,
            confirmed: true,
          ),
        ).complete,
        isFalse,
      );
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
      expect(
        value(
          await recoverFile.execute(
            source,
            comparison: comparison,
            source: WalletBackupImportSource.file,
            confirmed: true,
          ),
        ).complete,
        isTrue,
      );
      expect(remote.stores, 1);
      expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    },
  );
  test(
    'an explicitly chosen offline file restores locally but cannot release publication until server reconciliation',
    () async {
      value(await state.setEnabled(true));
      remote.unavailable = true;
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      final result = value(
        await recoverFile.execute(
          source,
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      );
      expect(result.metadataRestored, isTrue);
      expect(result.complete, isFalse);
      expect(value(await state.getControl()).recoveryIncomplete, isTrue);
      remote.unavailable = false;
      final current = value(await compareFile.execute(source));
      expect(
        value(
          await recoverFile.execute(
            source,
            comparison: current,
            source: WalletBackupImportSource.file,
            confirmed: true,
          ),
        ).complete,
        isTrue,
      );
      expect(value(await state.getControl()).recoveryIncomplete, isFalse);
    },
  );
  test(
    'disabling during file application finishes locally without a replacement write',
    () async {
      value(await state.setEnabled(true));
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      when(() => metadata.apply(any(), {})).thenAnswer((_) async {
        value(await state.setEnabled(false));
        return const Ok(null);
      });
      expect(
        value(
          await recoverFile.execute(
            source,
            comparison: comparison,
            source: WalletBackupImportSource.file,
            confirmed: true,
          ),
        ).complete,
        isTrue,
      );
      expect(remote.stores, 0);
      expect(value(await state.getControl()).enabled, isFalse);
    },
  );

  test(
    'enabling after a local-only comparison requires a fresh comparison before server replacement',
    () async {
      value(await state.setEnabled(false));
      final source = selectedFile();
      final comparison = value(await compareFile.execute(source));
      value(await state.setEnabled(true));
      expect(
        await recoverFile.execute(
          source,
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
        isA<Err>(),
      );
      expect(mutations, 0);
      expect(remote.stores, 0);
    },
  );

  test(
    'a different authenticated file cannot reuse an earlier comparison',
    () async {
      final comparison = value(await compareFile.execute(selectedFile()));
      final different = value(
        codec.encodeFile(
          snapshot,
          credential,
          format: WalletBackupFileFormat.readable,
        ),
      );
      expect(
        await recoverFile.execute(
          different,
          comparison: comparison,
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
        isA<Err>(),
      );
      expect(mutations, 0);
      expect(remote.stores, 0);
    },
  );
}
