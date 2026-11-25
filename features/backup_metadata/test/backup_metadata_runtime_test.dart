import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:labels/backup.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:backup_metadata/backup_metadata.dart';
import 'package:backup_metadata/setup.dart';
import 'package:backup_metadata/src/data/backup_metadata_repository_impl.dart';
import 'package:backup_metadata/src/domain/usecases/apply_restore_usecase.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'support/fake_backup_secrets.dart';
import 'support/memory_backup_storage.dart';

void main() {
  late Directory directory;
  late String path;
  late MemoryBackupStorage storage;
  late _Inventory inventory;
  late _Labels labels;
  late FakeBackupSecrets secrets;

  BackupMetadataRepositoryImpl repository([
    String? statePath,
    BackupMetadataCodec codec = const _Codec(),
  ]) => BackupMetadataRepositoryImpl(
    store: BackupMetadataStore(path: statePath ?? path, key: testJournalKey),
    inventory: inventory,
    labels: labels,
    secrets: secrets,
    codec: codec,
    storages: [storage],
  );

  Future<void> enable([String? statePath]) async {
    expect(
      await repository(statePath).configure(
        destination: storage.destination,
        groups: {'group'},
        deleteOwnedFiles: false,
      ),
      isA<Ok<void, BackupMetadataFailure>>(),
    );
  }

  Future<BackupGroupStatus> run([String? statePath]) async {
    final result = await repository(statePath).run();
    return result.fold(
      (status) => status.groups.single,
      (failure) => throw StateError(failure.runtimeType.toString()),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup-metadata-test');
    path = '${directory.path}/metadata.sqlite';
    storage = MemoryBackupStorage();
    inventory = _Inventory();
    labels = _Labels();
    secrets = FakeBackupSecrets();
  });

  tearDown(() async => directory.delete(recursive: true));

  test('skips a matching digest only while its object is listed', () async {
    await enable();
    expect((await run()).pendingChanges, isFalse);
    await run();
    expect(storage.created, 1);

    storage.objects.clear();

    expect((await run()).lastDurableBackup, isNotNull);
    expect(storage.created, 2);
  });

  test(
    'publishes after descriptor changes even with unchanged labels',
    () async {
      await enable();
      await run();

      inventory.descriptor = 'another descriptor';

      final status = await run();
      expect(storage.created, 2);
      expect(status.previousVersionKept, isTrue);
    },
  );

  test('publishes on each account change, including switching back', () async {
    await enable();
    await run();

    storage.accountId = 'b';
    await run();
    expect(storage.objects, hasLength(1));

    storage.accountId = 'a';
    await run();
    expect(storage.objects, hasLength(2));
    expect(storage.created, 3);
  });

  test(
    'reconciles a create whose acknowledgement was lost on restart',
    () async {
      await enable();
      storage.failAfterCreate = true;
      final incomplete = await run();
      expect(incomplete.actionNeeded, isNotNull);
      expect(incomplete.lastDurableBackup, isNull);

      storage.failAfterCreate = false;

      final resumed = await run();
      expect(resumed.lastDurableBackup, isNotNull);
      expect(resumed.pendingChanges, isFalse);
      expect(storage.created, 1);
    },
  );

  test(
    'prunes only its own durable generations and lists foreign backups',
    () async {
      final otherPath = '${directory.path}/another-installation.sqlite';
      await enable(otherPath);
      await run(otherPath);
      final foreign = storage.objects.keys.single;

      await enable();
      for (var revision = 0; revision < 3; revision++) {
        labels.revision = revision;
        await run();
      }

      expect(storage.deleted, ['2']);
      expect(storage.objects, contains(foreign));
      final discovered = await repository().discover(storage.destination);
      expect(
        discovered.fold(
          (backups) => backups.map((backup) => backup.storedAt?.second),
          (_) => const <int>[],
        ),
        [4, 3, 1],
      );
    },
  );

  test(
    'keeps old durable generations until the iCloud upload becomes durable',
    () async {
      storage = MemoryBackupStorage(destination: BackupDestination.iCloud);
      await enable();
      await run();
      labels.revision = 1;
      await run();
      final previousStorage = storage;
      storage =
          MemoryBackupStorage(
              destination: BackupDestination.iCloud,
              durability: Durability.pending,
            )
            ..accounts.addAll(previousStorage.accounts)
            ..created = previousStorage.created;
      labels.revision = 2;

      final pending = await run();

      expect(pending.previousVersionKept, isTrue);
      expect(pending.pendingChanges, isTrue);
      expect(storage.deleted, isEmpty);
      expect(storage.objects, hasLength(3));

      final uploaded = storage.objects.entries.singleWhere(
        (entry) => entry.key.durability == Durability.pending,
      );
      final pendingObject = uploaded.key;
      storage.objects
        ..remove(pendingObject)
        ..[StoredObject(
              id: pendingObject.id,
              name: pendingObject.name,
              size: pendingObject.size,
              createdAt: pendingObject.createdAt,
              durability: Durability.durable,
            )] =
            uploaded.value;

      final durable = await run();
      expect(durable.pendingChanges, isFalse);
      expect(durable.previousVersionKept, isTrue);
      expect(storage.deleted, ['1']);
      expect(storage.created, 3);
    },
  );

  Uint8List envelopeFor(int revision) => Uint8List.fromList(
    utf8.encode(jsonEncode([inventory.descriptor, revision.toString()])),
  );

  StoredObject objectById(String id) =>
      storage.objects.keys.singleWhere((object) => object.id == id);

  Uint8List corruptSecondGeneration() {
    final second = objectById('2');
    final damaged = Uint8List.fromList([31, 41, 59]);
    storage.objects.remove(second);
    final pending = StoredObject(
      id: second.id,
      name: second.name,
      createdAt: second.createdAt,
      size: damaged.length,
      durability: Durability.pending,
    );
    storage.objects[pending] = damaged;
    expect(objectById('2').durability, Durability.pending);
    expect(storage.objects[pending], orderedEquals(damaged));
    return damaged;
  }

  Future<void> seedFolderGenerations() async {
    storage = MemoryBackupStorage(destination: BackupDestination.folder);
    await enable();
    labels.revision = 0;
    await run();
    labels.revision = 1;
    await run();
    expect(storage.created, 2);
    expect(storage.objects[objectById('1')], orderedEquals(envelopeFor(0)));
    expect(storage.objects[objectById('2')], orderedEquals(envelopeFor(1)));
  }

  test('restore discovery never moves the configured destination', () async {
    await enable();
    await run();
    expect(storage.created, 1);
    final configured = objectById('1');

    storage.discoveryAccountId = 'b';
    storage.accounts['b'] = {
      StoredObject(
        id: 'from-b',
        name: 'bull-data-fromb.bip138',
        size: envelopeFor(0).length,
        createdAt: DateTime.utc(2026, 1, 2),
        durability: Durability.durable,
      ): envelopeFor(
        0,
      ),
    };

    final discovered = await repository().discover(storage.destination);

    expect(
      discovered.fold((backups) => backups.single.storedAt, (_) => null),
      DateTime.utc(2026, 1, 2),
    );
    expect(storage.accountId, 'a', reason: 'browsing is not a configuration');
    expect(storage.interactiveAuthorizations, 1);
    expect(storage.discoveries, 1);

    await run();
    expect(storage.accounts['b'], hasLength(1));
    expect(storage.objects.keys, [configured]);
    expect(storage.created, 1);
  });

  test(
    'a persistently damaged pending upload is retired and replaced',
    () async {
      storage = MemoryBackupStorage(destination: BackupDestination.folder);
      await enable();
      storage.failAfterCreate = true;
      expect((await run()).actionNeeded, isNotNull);
      final damaged = objectById('1');
      final damagedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      storage.objects[damaged] = damagedBytes;
      storage.failAfterCreate = false;

      final repaired = await run();

      expect(repaired.pendingChanges, isFalse);
      expect(repaired.lastDurableBackup, isNotNull);
      expect(
        storage.created,
        2,
        reason: 'a confirmed mismatch must not block the group forever',
      );
      expect(storage.objects, hasLength(2));
      expect(storage.objects[damaged], orderedEquals(damagedBytes));
      expect(storage.objects[objectById('2')], orderedEquals(envelopeFor(0)));
      expect(storage.deleted, isEmpty);
    },
  );

  test(
    'discovery reports a decode failure instead of an empty destination',
    () async {
      await enable();
      await run();
      final broken = StoredObject(
        id: 'broken',
        name: 'bull-data-broken.bip138',
        size: 6,
        createdAt: DateTime.utc(2026, 1, 3),
        durability: Durability.durable,
      );
      storage.objects.clear();
      storage.objects[broken] = Uint8List.fromList(utf8.encode('broken'));

      final result = await repository(
        null,
        const _BrokenCodec(),
      ).discover(storage.destination);

      expect(
        result.fold((_) => null, (failure) => failure),
        isA<BackupMetadataUnexpectedFailure>(),
      );
    },
  );

  test('discovery keeps a usable copy when another fails to decode', () async {
    await enable();
    await run();
    final usable = objectById('1');
    storage.objects[StoredObject(
      id: 'broken',
      name: 'bull-data-broken.bip138',
      size: 6,
      createdAt: DateTime.utc(2026, 1, 3),
      durability: Durability.durable,
    )] = Uint8List.fromList(
      utf8.encode('broken'),
    );

    final discovered = await repository(
      null,
      const _BrokenCodec(),
    ).discover(storage.destination);

    expect(
      discovered.fold(
        (backups) => backups.map((backup) => backup.storedAt),
        (_) => const <DateTime?>[],
      ),
      [usable.createdAt],
    );
  });

  test(
    'folder repairs unchanged digest when latest receipt no longer matches',
    () async {
      await seedFolderGenerations();
      corruptSecondGeneration();

      await run();

      expect(
        storage.created,
        3,
        reason: 'a pending same-id object cannot satisfy the unchanged digest',
      );
      expect(storage.objects[objectById('1')], orderedEquals(envelopeFor(0)));
      expect(storage.objects[objectById('3')], orderedEquals(envelopeFor(1)));
      expect(objectById('3').durability, Durability.durable);
    },
  );

  test(
    'folder keeps the previous readable generation after a corrupt latest',
    () async {
      await seedFolderGenerations();
      final damaged = corruptSecondGeneration();
      labels.revision = 2;

      await run();

      expect(storage.created, 3);
      expect(storage.objects[objectById('3')], orderedEquals(envelopeFor(2)));
      expect(storage.objects[objectById('2')], orderedEquals(damaged));
      final fallback = storage.objects.entries
          .where((entry) => entry.key.id == '1')
          .map((entry) => entry.value)
          .firstOrNull;
      expect(
        fallback,
        orderedEquals(envelopeFor(0)),
        reason: 'G3 and corrupt same-id G2 cannot justify pruning readable G1',
      );
      expect(storage.deleted, isNot(contains('1')));
    },
  );

  test('a transient pending-folder read does not replace or prune', () async {
    await seedFolderGenerations();
    corruptSecondGeneration();
    storage.unavailableReads.add('2');

    final unchanged = await run();

    expect(unchanged.actionNeeded, BackupActionReason.unavailable);
    expect(storage.created, 2);
    expect(storage.deleted, isEmpty);

    labels.revision = 2;
    final changed = await run();

    expect(changed.actionNeeded, BackupActionReason.unavailable);
    expect(storage.created, 3);
    expect(storage.deleted, isEmpty);
    expect(storage.objects[objectById('1')], orderedEquals(envelopeFor(0)));
    expect(storage.objects[objectById('3')], orderedEquals(envelopeFor(2)));

    expect((await run()).actionNeeded, BackupActionReason.unavailable);
    expect(storage.created, 3);
    expect(storage.deleted, isEmpty);
  });

  test('does not acknowledge a capture with unreadable rows', () async {
    await enable();
    await run();
    labels.skipped = 1;

    final status = await run();

    expect(status.actionNeeded, BackupActionReason.incompleteCapture);
    expect(status.skippedCount, 1);
    expect(status.pendingChanges, isTrue);
    expect(status.lastDurableBackup, isNotNull);
    expect(storage.created, 1);
  });

  test('folder durability requires matching read-back bytes', () async {
    storage = MemoryBackupStorage(
      destination: BackupDestination.folder,
      durability: Durability.pending,
    )..corruptRead = true;
    await enable();
    final incomplete = await run();
    expect(incomplete.lastDurableBackup, isNull);
    expect(incomplete.actionNeeded, isNotNull);

    storage.corruptRead = false;

    expect((await run()).lastDurableBackup, isNotNull);
    expect(storage.created, 1);
  });

  test('disable with deletion preserves foreign files', () async {
    final otherPath = '${directory.path}/another-installation.sqlite';
    await enable(otherPath);
    await run(otherPath);
    final foreign = storage.objects.keys.single;
    await enable();
    await run();

    expect(
      await repository().configure(
        destination: null,
        groups: {},
        deleteOwnedFiles: true,
      ),
      isA<Ok<void, BackupMetadataFailure>>(),
    );
    expect(storage.objects.keys, [foreign]);
    expect((await run()).included, isFalse);
  });

  test('restore apply surfaces a stale plan from the labels port', () async {
    final plan = MergePlan(
      groupId: 'group',
      baseDigest: 'stale',
      additions: [],
      unchanged: 0,
      conflicts: [],
      freezes: [],
    );
    final group = (await inventory.read()).fold(
      (value) => value.groups.single,
      (_) => throw StateError('read'),
    );
    final backup = DiscoveredBackup(
      group: group,
      destination: storage.destination,
      storedAt: null,
      content: _content(0),
      scope: 'scope',
    );
    final result = await ApplyRestoreUsecase(
      labels,
      secrets,
    ).execute(backup, plan, MergeChoices({}));
    final report = result.fold(
      (value) => value,
      (failure) => throw StateError('$failure'),
    );
    expect(report.isPartial, isTrue);
    expect(report.labelsFailure, isA<BackupMetadataStalePlanFailure>());
    expect(report.secrets, isNotNull);
  });

  test('separate isolates serialize access to the same state path', () async {
    final acquired = Completer<void>();
    final release = Completer<void>();
    final first = BackupMetadataStore(path: path, key: testJournalKey).locked((
      state,
    ) async {
      acquired.complete();
      await release.future;
      return state.selection.lineage;
    }, view: 'scope');
    await acquired.future;

    final statePath = path;
    final messages = ReceivePort();
    final sender = messages.sendPort;
    final incoming = StreamIterator<dynamic>(messages);
    final contender = _readLineageInIsolate(statePath, sender);
    try {
      expect(await incoming.moveNext(), isTrue);
      expect(incoming.current, 'started');
      // Independently prove the lock rejects a contender while held.
      await expectLater(
        _tryLockInIsolate(statePath),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.resultCode,
            'result code',
            SqlError.SQLITE_BUSY,
          ),
        ),
      );
      release.complete();
      expect(await incoming.moveNext(), isTrue);
      expect(incoming.current, 'acquired');
      expect(await contender, await first);
    } finally {
      if (!release.isCompleted) release.complete();
      await contender;
      await first;
      await incoming.cancel();
      messages.close();
    }
  });
}

Future<String> _readLineageInIsolate(String path, SendPort events) =>
    Isolate.run(() async {
      events.send('started');
      final lineage = await BackupMetadataStore(
        path: path,
        key: testJournalKey,
      ).locked((state) async => state.selection.lineage, view: 'scope');
      events.send('acquired');
      return lineage;
    });

Future<void> _tryLockInIsolate(String path) => Isolate.run(
  () => BackupMetadataStore(
    path: path,
    key: testJournalKey,
    lockTimeout: Duration.zero,
  ).locked((_) async {}, view: 'scope'),
);

final class _Inventory implements BackupInventoryPort {
  String descriptor = 'first descriptor';
  int calls = 0;
  bool ambiguous = false;

  @override
  Future<Result<BackupInventory, BackupMetadataFailure>> read() async {
    calls++;
    return Ok(
      BackupInventory(
        groups: [
          BackupGroup(
            id: 'group',
            displayName: 'Group',
            network: BitcoinNetwork.regtest,
            bitcoinWalletIds: ['wallet'],
            liquidWalletIds: [],
            bitcoinPublicDescriptors: [descriptor],
            seedBackupVerified: true,
            ambiguous: ambiguous,
          ),
        ],
        unsupported: [],
      ),
    );
  }
}

final class _Labels implements BackupLabelsPort {
  int revision = 0;
  int skipped = 0;
  int applied = 0;
  bool failApply = true;
  void Function()? onCapture;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupGroup group,
  ) async {
    onCapture?.call();
    return Ok(_snapshot(revision, skipped: skipped));
  }

  @override
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupGroup group,
    LabelsSnapshot incoming,
  ) async => const Err(BackupMetadataUnexpectedFailure());

  @override
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    MergePlan plan,
    MergeChoices choices,
  ) async {
    if (failApply) return const Err(BackupMetadataStalePlanFailure());
    applied++;
    return Ok(
      ApplyReport(
        labelsApplied: 0,
        labelsUnchanged: 0,
        labelsRejected: {},
        freezes: {},
      ),
    );
  }
}

final class _Codec implements BackupMetadataCodec {
  const _Codec();

  @override
  Result<PreparedBackup, BackupMetadataFailure> prepare(
    BackupGroup group,
    BackupContent content,
  ) {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode([
          ...group.bitcoinPublicDescriptors,
          content.labels.records.single.ref,
        ]),
      ),
    );
    return Ok((
      digest: sha256.convert(bytes).toString(),
      encrypt: () async => Ok(bytes),
    ));
  }

  @override
  Future<Result<BackupContent?, BackupMetadataFailure>> decode(
    BackupGroup group,
    Uint8List envelope,
  ) async {
    final data = jsonDecode(utf8.decode(envelope));
    if (data case [final String descriptor, final String revision]
        when group.bitcoinPublicDescriptors.contains(descriptor)) {
      return Ok(_content(int.parse(revision)));
    }
    return const Ok(null);
  }
}

BackupContent _content(int revision) => BackupContent(
  labels: _snapshot(revision),
  wallets: const [],
  derivations: const [],
);

LabelsSnapshot _snapshot(int revision, {int skipped = 0}) => LabelsSnapshot(
  records: [
    BackupLabelRecord(
      chain: BackupLabelChain.bitcoin,
      type: BackupLabelType.tx,
      ref: revision.toString(),
    ),
  ],
  unattributedCount: 0,
  skippedCount: skipped,
);

final class _BrokenCodec implements BackupMetadataCodec {
  const _BrokenCodec();

  @override
  Result<PreparedBackup, BackupMetadataFailure> prepare(
    BackupGroup group,
    BackupContent content,
  ) => const _Codec().prepare(group, content);

  @override
  Future<Result<BackupContent?, BackupMetadataFailure>> decode(
    BackupGroup group,
    Uint8List envelope,
  ) async {
    final data = utf8.decode(envelope, allowMalformed: true);
    if (data == 'broken') {
      return const Err(BackupMetadataUnexpectedFailure());
    }
    return const _Codec().decode(group, envelope);
  }
}
