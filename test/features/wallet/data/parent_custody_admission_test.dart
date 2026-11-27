import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:secrets/custody.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart'
    show BackupProof, InventoryBackupVerification;
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

final class _References implements SeedReferencePort {
  final Set<Fingerprint> parents = {};
  Future<void> Function()? beforeRead;
  bool incomplete = false;

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async {
    await beforeRead?.call();
    return incomplete
        ? const Err(SeedReferencesUnavailable())
        : Ok(Set.of(parents));
  }
}

final class _UnreadableBackups implements InventoryBackupVerification {
  const _UnreadableBackups();

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async => const Err(BackupStateUnavailableFailure());
}

final class _AfterDeleteStorage extends FakeSecureStoragePlatform {
  void Function()? afterDelete;
  int deletes = 0;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    await super.delete(key: key, options: options);
    deletes++;
    afterDelete?.call();
  }
}

void _holdCustody((String, SendPort) args) async {
  final commands = ReceivePort();
  final admission = SqliteParentCustodyAdmission(
    directory: () async => args.$1,
    mayCreate: true,
  );
  await admission.runExclusive<void>(Fingerprint('73c5da0a'), (lease) async {
    args.$2.send(commands.sendPort);
    await commands.first;
    return const Ok(null);
  });
  commands.close();
}

void main() {
  final parent = Fingerprint('73c5da0a');
  late Directory directory;
  late SqliteParentCustodyAdmission admission;

  String statePath() =>
      p.join(directory.path, 'parent_custody', '${parent.hex}.state.sqlite');

  setUp(() {
    directory = Directory.systemTemp.createTempSync('parent-custody-test-');
    log = Logger.replace(directory: directory);
    admission = SqliteParentCustodyAdmission(
      directory: () async => directory.path,
      mayCreate: true,
      waitLimit: const Duration(milliseconds: 100),
    );
  });
  tearDown(() async {
    await log.flush();
    directory.deleteSync(recursive: true);
  });

  test('durable tombstone does not release the separate exclusion', () async {
    final entered = Completer<void>();
    final finish = Completer<void>();
    final holding = admission.runExclusive<void>(parent, (lease) async {
      expect(lease.markDeleting(), isA<Ok>());
      entered.complete();
      await finish.future;
      expect(lease.markDeleted(), isA<Ok>());
      return const Ok(null);
    });
    await entered.future;
    final db = sqlite3.open(statePath(), mode: OpenMode.readOnly);
    expect(db.select('SELECT state FROM custody').single['state'], 'deleting');
    db.close();
    final refused = await admission.runExclusive<void>(parent, (_) async {
      fail('another action entered while deletion was admitted');
    });
    expect((refused as Err).failure, isA<ParentCustodyBusyFailure>());
    finish.complete();
    expect(await holding, isA<Ok>());
    expect(
      await admission.runExclusive(parent, (lease) async => lease.readState()),
      isA<Ok<ParentCustodyState, ParentCustodyFailure>>().having(
        (result) => result.value,
        'persisted state',
        ParentCustodyState.deleted,
      ),
    );
  });

  test('an old lease stays invalid during a later admission', () async {
    ParentCustodyLease? previous;
    await admission.runExclusive<void>(parent, (lease) async {
      previous = lease;
      return const Ok(null);
    });
    await admission.runExclusive<void>(parent, (lease) async {
      expect(previous?.readState(), isA<Err>());
      expect(previous?.markDeleting(), isA<Err>());
      expect(lease.readState(), isA<Ok>());
      return const Ok(null);
    });
    expect(previous?.reconcilePresent(), isA<Err>());
  });

  test('callback errors propagate after releasing exclusion', () async {
    await expectLater(
      admission.runExclusive<void>(parent, (_) async {
        throw StateError('programmer bug');
      }),
      throwsStateError,
    );
    expect(
      await admission.runExclusive(parent, (lease) async => lease.readState()),
      isA<Ok>(),
    );
  });

  test('missing committed state is never recreated by foreground', () async {
    await admission.runExclusive(parent, (lease) async => lease.readState());
    File(statePath()).deleteSync();
    expect(
      await admission.runExclusive(parent, (lease) async => lease.readState()),
      isA<Err>().having(
        (result) => result.failure,
        'missing state',
        isA<ParentCustodyMetadataFailure>(),
      ),
    );
    expect(File(statePath()).existsSync(), isFalse);
  });

  test('foreign schema and unreadable inventory fail closed', () async {
    await admission.runExclusive(parent, (lease) async => lease.readState());
    final db = sqlite3.open(statePath());
    db.userVersion = 2;
    db.close();
    expect(
      await admission.runExclusive(parent, (lease) async => lease.readState()),
      isA<Err>(),
    );
    final after = sqlite3.open(statePath());
    expect(after.userVersion, 2);
    after.close();
  });

  test('existing-only opener creates no directory or state', () async {
    final existing = SqliteParentCustodyAdmission(
      directory: () async => p.join(directory.path, 'missing'),
      mayCreate: false,
    );
    expect(
      await existing.runExclusive(parent, (lease) async => lease.readState()),
      isA<Err>(),
    );
    expect(Directory(p.join(directory.path, 'missing')).existsSync(), isFalse);
    await admission.runExclusive(parent, (lease) async => lease.readState());
    final ready = SqliteParentCustodyAdmission(
      directory: () async => directory.path,
      mayCreate: false,
    );
    expect(
      await ready.runExclusive(parent, (lease) async => lease.readState()),
      isA<Ok>(),
    );
  });

  test('process death preserves tombstone and releases OS exclusion', () async {
    await admission.runExclusive(parent, (lease) async => lease.readState());
    final process = await Process.start('python3', [
      '-c',
      'import sqlite3,sys\n'
          'lock=sqlite3.connect(sys.argv[1],timeout=0)\n'
          'lock.execute("BEGIN IMMEDIATE")\n'
          'state=sqlite3.connect(sys.argv[2])\n'
          'state.execute("UPDATE custody SET state=\'deleting\'")\n'
          'state.commit()\n'
          'print("held",flush=True)\n'
          'sys.stdin.read()\n',
      p.join(directory.path, 'parent_custody', '${parent.hex}.lock.sqlite'),
      statePath(),
    ]);
    addTearDown(() async {
      process.kill();
      await process.exitCode;
    });
    expect(
      await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first,
      'held',
    );
    expect(
      await admission.runExclusive(parent, (lease) async => lease.readState()),
      isA<Err>(),
    );
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    final recovered = await admission.runExclusive(
      parent,
      (lease) async => lease.readState(),
    );
    expect((recovered as Ok).value, ParentCustodyState.deleting);
  });

  test(
    'Dart isolate death keeps the native lease until process exit',
    () async {
      final messages = ReceivePort();
      final exited = ReceivePort();
      final isolate = await Isolate.spawn(_holdCustody, (
        directory.path,
        messages.sendPort,
      ), onExit: exited.sendPort);
      addTearDown(() {
        isolate.kill(priority: Isolate.immediate);
        messages.close();
        exited.close();
      });
      expect(await messages.first, isA<SendPort>());
      isolate.kill(priority: Isolate.immediate);
      await exited.first;
      expect(
        (await admission.runExclusive(
          parent,
          (lease) async => lease.readState(),
        ) as Err).failure,
        isA<ParentCustodyBusyFailure>(),
      );
    },
  );

  test(
    'unused temporary state before publication does not become authority',
    () async {
      final temporary = Directory(
        p.join(
          directory.path,
          'parent_custody',
          '.custody-initializing-interrupted',
        ),
      );
      temporary.createSync(recursive: true);
      File(p.join(temporary.path, 'state.sqlite')).writeAsStringSync('partial');
      expect(
        await admission.runExclusive(
          parent,
          (lease) async => lease.readState(),
        ),
        isA<Ok>(),
      );
      expect(
        File(p.join(temporary.path, 'state.sqlite')).readAsStringSync(),
        'partial',
      );
    },
  );

  test('committed state after rename can finish first lock creation', () async {
    await admission.runExclusive(parent, (lease) async => lease.readState());
    final recoveredRoot = Directory(p.join(directory.path, 'renamed'));
    final parentRoot = Directory(p.join(recoveredRoot.path, 'parent_custody'));
    parentRoot.createSync(recursive: true);
    final recoveredState = p.join(
      parentRoot.path,
      '${parent.hex}.state.sqlite',
    );
    File(statePath()).copySync(recoveredState);
    final recovery = SqliteParentCustodyAdmission(
      directory: () async => recoveredRoot.path,
      mayCreate: true,
    );
    expect(
      await recovery.runExclusive(parent, (lease) async => lease.readState()),
      isA<Ok>(),
    );
    expect(
      File(p.join(parentRoot.path, '${parent.hex}.lock.sqlite')).existsSync(),
      isTrue,
    );
  });

  group('deletion and new custody references', () {
    late Secrets secrets;
    late FakeSecureStoragePlatform storage;
    late _References owner;
    late SeedReferences references;
    late Fingerprint id;

    setUp(() async {
      storage = FakeSecureStoragePlatform()..install();
      secrets = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      );
      final result = await secrets.import(
        language: Language.english,
        words: [...List.filled(11, 'abandon'), 'about'],
      );
      id = (result as Ok<Secret, SecretFailure>).value.id;
      owner = _References();
      references = SeedReferences(
        owner,
        admission: admission,
        backupVerification: FakeInventoryBackups(verified: {id}),
      );
    });

    test('provisioning wins before deletion inventory', () async {
      final entered = Completer<void>();
      final publish = Completer<void>();
      final provisioning = admission.runExclusive<void>(id, (lease) async {
        expect(await secrets.fetch(id), isA<Ok>());
        entered.complete();
        await publish.future;
        owner.parents.add(id);
        return const Ok(null);
      });
      await entered.future;
      final deletion = references.deleteUnreferenced(secrets, id);
      publish.complete();
      expect(await provisioning, isA<Ok>());
      expect(
        (await deletion as Err).failure,
        isA<ParentCustodyReferencedFailure>(),
      );
      expect(await secrets.fetch(id), isA<Ok>());
    });

    test('deletion wins before a provisioner can read the parent', () async {
      final inventoryEntered = Completer<void>();
      final finishInventory = Completer<void>();
      owner.beforeRead = () async {
        inventoryEntered.complete();
        await finishInventory.future;
      };
      final deletion = references.deleteUnreferenced(secrets, id);
      await inventoryEntered.future;
      final provisioning = admission.runExclusive<void>(id, (lease) async {
        expect((lease.readState() as Ok).value, ParentCustodyState.deleted);
        expect(await secrets.fetch(id), isA<Err>());
        return const Err(ParentCustodyStateFailure());
      });
      finishInventory.complete();
      expect(await deletion, isA<Ok>());
      expect(await provisioning, isA<Err>());
    });

    test('incomplete owner preserves seed and ready state', () async {
      owner.incomplete = true;
      expect(
        (await references.deleteUnreferenced(secrets, id) as Err).failure,
        isA<ParentCustodyInventoryFailure>(),
      );
      expect(await secrets.fetch(id), isA<Ok>());
      final state = await admission.runExclusive(
        id,
        (lease) async => lease.readState(),
      );
      expect((state as Ok).value, ParentCustodyState.ready);
    });

    test('a verified backup deletes the unreferenced seed', () async {
      expect(await references.deleteUnreferenced(secrets, id), isA<Ok>());
      expect(await secrets.fetch(id), isA<Err>());
    });

    test('a verified backup never deletes a seed still referenced', () async {
      owner.parents.add(id);

      expect(
        (await references.deleteUnreferenced(secrets, id) as Err).failure,
        isA<ParentCustodyReferencedFailure>(),
      );
      expect(await secrets.fetch(id), isA<Ok>());
    });

    test('a seed without a tested backup is never deleted', () async {
      final guarded = SeedReferences(
        owner,
        admission: admission,
        backupVerification: const FakeInventoryBackups(),
      );

      expect(
        (await guarded.deleteUnreferenced(secrets, id) as Err).failure,
        isA<ParentCustodyBackupRequiredFailure>(),
      );
      expect(await secrets.fetch(id), isA<Ok>());
      final state = await admission.runExclusive(
        id,
        (lease) async => lease.readState(),
      );
      expect((state as Ok).value, ParentCustodyState.ready);
    });

    test('an unreadable backup state preserves the seed', () async {
      final guarded = SeedReferences(
        owner,
        admission: admission,
        backupVerification: const _UnreadableBackups(),
      );

      expect(
        (await guarded.deleteUnreferenced(secrets, id) as Err).failure,
        isA<ParentCustodyBackupUnavailableFailure>(),
      );
      expect(await secrets.fetch(id), isA<Ok>());
      final state = await admission.runExclusive(
        id,
        (lease) async => lease.readState(),
      );
      expect((state as Ok).value, ParentCustodyState.ready);
    });

    test('an absent seed is reconciled to deleted without a backup', () async {
      // The tombstone records a deletion that already ran; the entry is gone.
      // Completing it must not require a proof for a seed that cannot be
      // backed up, because it no longer exists.
      expect(
        await admission.runExclusive<void>(
          id,
          (lease) async => lease.markDeleting(),
        ),
        isA<Ok>(),
      );
      expect(await secrets.trash(id), isA<Ok>());
      final guarded = SeedReferences(
        owner,
        admission: admission,
        backupVerification: const FakeInventoryBackups(),
      );

      expect(
        await guarded.deleteUnreferenced(
          secrets,
          id,
          reconcileBeforeDelete: true,
        ),
        isA<Ok<void, ParentCustodyFailure>>(),
      );
      final state = await admission.runExclusive(
        id,
        (lease) async => lease.readState(),
      );
      expect((state as Ok).value, ParentCustodyState.deleted);
    });

    test(
      'failed trash stays tombstoned until a new manual recovery request',
      () async {
        storage.writesFail = true;
        expect(
          (await references.deleteUnreferenced(secrets, id) as Err).failure,
          isA<ParentCustodyDeletionFailure>(),
        );
        storage.writesFail = false;
        expect(
          (await references.deleteUnreferenced(secrets, id) as Err).failure,
          isA<ParentCustodyStateFailure>(),
        );
        expect(await secrets.fetch(id), isA<Ok>());
        expect(
          await references.deleteUnreferenced(
            secrets,
            id,
            reconcileBeforeDelete: true,
          ),
          isA<Ok>(),
        );
        expect(await secrets.fetch(id), isA<Err>());
      },
    );

    test(
      'failed final marker preserves completed trash for manual reconciliation',
      () async {
        final faultStore = _AfterDeleteStorage();
        faultStore.entries.addAll(storage.entries);
        faultStore.install();
        Database? blocking;
        faultStore.afterDelete = () {
          blocking = sqlite3.open(statePath());
          blocking?.execute('BEGIN IMMEDIATE');
        };
        final deleted = await references.deleteUnreferenced(secrets, id);
        blocking?.execute('ROLLBACK');
        blocking?.close();
        faultStore.afterDelete = null;
        expect((deleted as Err).failure, isA<ParentCustodyDeletionFailure>());
        expect(await secrets.fetch(id), isA<Err>());
        expect(faultStore.deletes, 1);
        final pending = await admission.runExclusive(
          id,
          (lease) async => lease.readState(),
        );
        expect((pending as Ok).value, ParentCustodyState.deleting);
        expect(
          await references.deleteUnreferenced(
            secrets,
            id,
            reconcileBeforeDelete: true,
          ),
          isA<Ok>(),
        );
        expect(faultStore.deletes, 1);
        final completed = await admission.runExclusive(
          id,
          (lease) async => lease.readState(),
        );
        expect((completed as Ok).value, ParentCustodyState.deleted);
      },
    );

    test(
      'unreadable parent never counts as absence during reconciliation',
      () async {
        await admission.runExclusive<void>(
          id,
          (lease) async => lease.markDeleting(),
        );
        storage.locked = true;
        expect(
          (await references.deleteUnreferenced(
            secrets,
            id,
            reconcileBeforeDelete: true,
          ) as Err).failure,
          isA<ParentCustodyDeletionFailure>(),
        );
        storage.locked = false;
        final state = await admission.runExclusive(
          id,
          (lease) async => lease.readState(),
        );
        expect((state as Ok).value, ParentCustodyState.deleting);
        expect(await secrets.fetch(id), isA<Ok>());
      },
    );

    test(
      'manual deletion after reimport reconciles a deleted parent',
      () async {
        expect(await references.deleteUnreferenced(secrets, id), isA<Ok>());
        expect(
          await secrets.import(
            language: Language.english,
            words: [...List.filled(11, 'abandon'), 'about'],
          ),
          isA<Ok>(),
        );
        expect(
          await references.deleteUnreferenced(
            secrets,
            id,
            reconcileBeforeDelete: true,
          ),
          isA<Ok>(),
        );
        expect(await secrets.fetch(id), isA<Err>());
      },
    );
  });
}
