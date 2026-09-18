import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_codec_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Vaults extends Mock implements BullVaultFacade {}

T _value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;

class _Snapshots implements WalletBackupSnapshotRepository {
  final events = StreamController<void>.broadcast(sync: true);
  WalletBackupSnapshot current;
  Future<void> Function()? onCapture;
  int captures = 0;
  _Snapshots(this.current);
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> capture(
    BackupCredential credential,
  ) async {
    captures++;
    final captured = current;
    await onCapture?.call();
    return Ok(captured);
  }

  void edit({bool notify = true}) {
    current = WalletBackupSnapshot(
      manifest: current.manifest,
      vaults: current.vaults,
      metadata: WalletMetadataBackup(
        labels: [
          ...current.metadata.labels,
          LabelEntity(
            id: 0,
            type: LabelType.address,
            label: 'Changed ${current.metadata.labels.length}',
            reference: 'new-address',
          ),
        ],
        frozenOutputs: current.metadata.frozenOutputs,
        settings: current.metadata.settings,
      ),
    );
    if (notify) events.add(null);
  }
}

class _Remote implements WalletBackupRemoteRepository {
  WalletBackupRemoteHead head = WalletBackupRemoteHead(
    generation: 0,
    etag: null,
  );
  Future<void> Function()? onStore;
  Future<void> Function()? onFetch;
  bool loseNextReply = false;
  int fetches = 0;
  int stores = 0;
  void install(
    BackupCredential credential,
    WalletBackupCiphertext ciphertext,
    int generation,
  ) {
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
    await onFetch?.call();
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
    if (expectedEtag != head.etag || generation != head.generation + 1) {
      return const Err(WalletBackupConflictFailure());
    }
    install(credential, ciphertext, generation);
    await onStore?.call();
    if (loseNextReply) {
      loseNextReply = false;
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
  }) => throw UnimplementedError();
}

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final codec = WalletBackupCodecRepositoryImpl(_Vaults());
  late Directory directory;
  late SqliteDatabase db;
  late DriftWalletBackupStateRepository state;
  late _Snapshots snapshots;
  late _Remote remote;
  late _Identity identity;
  late PublishWalletBackupUsecase publish;
  PublishWalletBackupUsecase publisher() => PublishWalletBackupUsecase(
    operations: WalletBackupOperationQueue(),
    identity: identity,
    state: state,
    snapshots: snapshots,
    codec: codec,
    remote: remote,
    now: () => DateTime.utc(2026, 9, 18, 12),
  );
  Future<WalletBackupState> localState() async =>
      _value(await state.get(credential.serverPublicKey));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bull-backup-publication-',
    );
    db = SqliteDatabase(
      NativeDatabase(File('${directory.path}/state.sqlite3')),
    );
    state = DriftWalletBackupStateRepository(db);
    _value(await state.setEnabled(true));
    snapshots = _Snapshots(backupSnapshotFixture(credential));
    remote = _Remote();
    identity = _Identity();
    when(identity.resolve).thenAnswer((_) async => Ok(credential));
    publish = publisher();
  });
  tearDown(() async {
    await snapshots.events.close();
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'off and durable recovery fence prevent capture and network publication',
    () async {
      _value(await state.setEnabled(false));
      expect(_value(await publish.execute()), WalletBackupPublication.inactive);
      _value(await state.setEnabled(true));
      _value(await state.setRecoveryIncomplete(true));
      expect(
        (await publish.execute() as Err).failure,
        isA<WalletBackupIncompleteFailure>(),
      );
      expect(snapshots.captures, 0);
      expect(remote.fetches, 0);
      expect(remote.stores, 0);
    },
  );
  test(
    'success requires readback and records only the sent content; unchanged content skips upload',
    () async {
      final hash = _value(codec.contentHash(snapshots.current));
      expect(
        _value(await publish.execute()),
        WalletBackupPublication.published,
      );
      expect(remote.fetches, 2);
      expect(remote.stores, 1);
      expect((await localState()).confirmedContentHash, hash);
      expect(
        (await localState()).checkpoint!.ciphertextHash,
        remote.head.ciphertext!.hash,
      );
      expect(_value(await publish.execute()), WalletBackupPublication.upToDate);
      expect(remote.fetches, 2);
      expect(remote.stores, 1);
    },
  );
  test(
    'an edit during capture stays pending without publishing a stale capture',
    () async {
      snapshots.onCapture = () async {
        snapshots.onCapture = null;
        snapshots.edit();
      };
      expect(_value(await publish.execute()), WalletBackupPublication.pending);
      expect(remote.stores, 0);
      expect(
        _value(await publish.execute()),
        WalletBackupPublication.published,
      );
    },
  );
  for (final notify in [true, false]) {
    test(
      'edit during upload stays pending with notification=$notify',
      () async {
        final originalHash = _value(codec.contentHash(snapshots.current));
        remote.onStore = () async {
          remote.onStore = null;
          snapshots.edit(notify: notify);
        };
        expect(
          _value(await publish.execute()),
          WalletBackupPublication.pending,
        );
        expect((await localState()).confirmedContentHash, originalHash);
        expect(
          (await localState()).confirmedContentHash,
          isNot(_value(codec.contentHash(snapshots.current))),
        );
        expect(
          _value(await publish.execute()),
          WalletBackupPublication.published,
        );
        expect(remote.head.generation, 2);
        expect(
          (await localState()).confirmedContentHash,
          _value(codec.contentHash(snapshots.current)),
        );
      },
    );
  }
  test(
    'lost successful reply is reconciled before publishing an intervening edit',
    () async {
      final firstHash = _value(codec.contentHash(snapshots.current));
      remote.loseNextReply = true;
      expect(
        (await publish.execute() as Err).failure,
        isA<WalletBackupNetworkFailure>(),
      );
      expect((await localState()).checkpoint, isNull);
      snapshots.edit(notify: false);
      expect(_value(await publish.execute()), WalletBackupPublication.pending);
      expect((await localState()).confirmedContentHash, firstHash);
      expect(remote.stores, 1);
      expect(
        _value(await publish.execute()),
        WalletBackupPublication.published,
      );
      expect(remote.stores, 2);
    },
  );
  test(
    'after database reopen an identical remote payload resolves a lost reply without another store',
    () async {
      remote.loseNextReply = true;
      expect(await publish.execute(), isA<Err>());
      await db.close();
      db = SqliteDatabase(
        NativeDatabase(File('${directory.path}/state.sqlite3')),
      );
      state = DriftWalletBackupStateRepository(db);
      publish = publisher();
      expect(_value(await publish.execute()), WalletBackupPublication.upToDate);
      expect(remote.stores, 1);
      expect((await localState()).checkpoint!.generation, 1);
    },
  );
  test(
    'different remote data needs explicit Replace and a stale inspected head cannot replace',
    () async {
      final other = _Snapshots(snapshots.current)..edit();
      addTearDown(other.events.close);
      remote.install(
        credential,
        _value(codec.encrypt(other.current, credential)),
        1,
      );
      expect(
        (await publish.execute() as Err).failure,
        isA<WalletBackupConflictFailure>(),
      );
      expect(remote.stores, 0);
      final inspected = remote.head;
      remote.install(credential, remote.head.ciphertext!, 2);
      expect(
        (await publish.execute(replace: inspected) as Err).failure,
        isA<WalletBackupConflictFailure>(),
      );
      expect(
        _value(await publish.execute(replace: remote.head)),
        WalletBackupPublication.published,
      );
      expect(remote.head.generation, 3);
    },
  );
  test(
    'disable during upload records the accepted copy and prevents queued recreation',
    () async {
      remote.onStore = () async {
        _value(await state.setEnabled(false));
      };
      expect(_value(await publish.execute()), WalletBackupPublication.inactive);
      final stored = await localState();
      expect(stored.enabled, isFalse);
      expect(stored.checkpoint!.generation, 1);
      expect(_value(await publish.execute()), WalletBackupPublication.inactive);
      expect(remote.stores, 1);
    },
  );
  test(
    'changed readback cannot produce a successful local checkpoint',
    () async {
      remote.onFetch = () async {
        if (remote.fetches == 2) {
          snapshots.edit(notify: false);
          remote.install(
            credential,
            _value(codec.encrypt(snapshots.current, credential)),
            2,
          );
        }
      };
      expect(
        (await publish.execute() as Err).failure,
        isA<WalletBackupConflictFailure>(),
      );
      expect((await localState()).checkpoint, isNull);
    },
  );
  test(
    'concurrent publication requests share one operation and one upload',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      snapshots.onCapture = () async {
        snapshots.onCapture = null;
        entered.complete();
        await release.future;
      };
      final first = publish.execute();
      await entered.future;
      final second = publish.execute();
      expect(remote.stores, 0);
      release.complete();
      expect(
        (await Future.wait([first, second])).every((result) => result is Ok),
        isTrue,
      );
      expect(remote.stores, 1);
    },
  );
  test(
    'a changed active backup identity stays pending instead of claiming the new identity is backed up',
    () async {
      final other = BackupCredential.fromWords(
        'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      remote.onStore = () async {
        when(identity.resolve).thenAnswer((_) async => Ok(other));
      };
      expect(_value(await publish.execute()), WalletBackupPublication.pending);
      expect((await localState()).checkpoint, isNotNull);
      expect(_value(await state.get(other.serverPublicKey)).checkpoint, isNull);
    },
  );
  test(
    'an edit during the final confirmation capture remains pending',
    () async {
      snapshots.onCapture = () async {
        if (snapshots.captures == 2) snapshots.edit();
      };
      expect(_value(await publish.execute()), WalletBackupPublication.pending);
    },
  );
  test(
    'explicit replacement works after the deleted server generation has expired',
    () async {
      expect(
        _value(await publish.execute()),
        WalletBackupPublication.published,
      );
      final oldEtag = (await localState()).checkpoint!.etag;
      remote.head = WalletBackupRemoteHead(generation: 0, etag: null);
      snapshots.edit();
      expect(
        _value(await publish.execute(replace: remote.head)),
        WalletBackupPublication.published,
      );
      expect((await localState()).checkpoint!.generation, 1);
      expect((await localState()).checkpoint!.etag, isNot(oldEtag));
    },
  );
  test(
    'restart with different unconfirmed remote content reports conflict instead of guessing ownership',
    () async {
      remote.loseNextReply = true;
      expect(await publish.execute(), isA<Err>());
      snapshots.edit(notify: false);
      publish = publisher();
      expect(
        (await publish.execute() as Err).failure,
        isA<WalletBackupConflictFailure>(),
      );
      expect(remote.stores, 1);
    },
  );
  test(
    'an uncertain newer upload is reconciled even if local edits return to the last confirmed content',
    () async {
      final original = snapshots.current;
      expect(
        _value(await publish.execute()),
        WalletBackupPublication.published,
      );
      snapshots.edit();
      remote.loseNextReply = true;
      expect(await publish.execute(), isA<Err>());
      snapshots.current = original;
      expect(_value(await publish.execute()), WalletBackupPublication.pending);
      expect(
        _value(await publish.execute()),
        WalletBackupPublication.published,
      );
      expect(remote.head.generation, 3);
      expect(
        (await localState()).confirmedContentHash,
        _value(codec.contentHash(original)),
      );
    },
  );
}
