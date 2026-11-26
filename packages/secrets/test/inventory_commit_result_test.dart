import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/access_repository.dart';
import 'package:secrets/src/data/backup_guard.dart';
import 'package:secrets/src/data/inventory_repository.dart';
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/inventory_session.dart';
import 'package:secrets/src/data/secrets_database.dart';
import 'package:secrets/src/domain/domain.dart';

class _CommitBarrier extends QueryInterceptor {
  final committed = Completer<void>();
  final release = Completer<void>();
  bool armed = false;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (!armed) return;
    committed.complete();
    await release.future;
  }
}

void main() {
  test('a committed command keeps its result after revocation', () async {
    final barrier = _CommitBarrier();
    final database = SecretsDatabase(
      NativeDatabase.memory().interceptWith(barrier),
    );
    await database.customStatement('CREATE TABLE durable_test (value INTEGER)');
    barrier.armed = true;
    var current = true;
    final result = runInventorySession<void>(
      () => boundary(
        () => guardedTransaction(database, () async {
          await database.customStatement('INSERT INTO durable_test VALUES (1)');
        }),
        orElse: StoreSecretFailure.new,
      ),
      isCurrent: () => current,
      preserveCommittedCommand: true,
    );
    await barrier.committed.future.timeout(const Duration(seconds: 5));
    current = false;
    barrier.release.complete();
    final returned = await result;
    final rows = await database
        .customSelect('SELECT value FROM durable_test')
        .get();
    await database.close();
    expect(rows.single.read<int>('value'), 1);
    expect(returned, isA<Ok<void, SecretFailure>>());
  });

  test('revocation before commit rolls the command back', () async {
    final database = SecretsDatabase(NativeDatabase.memory());
    await database.customStatement('CREATE TABLE durable_test (value INTEGER)');
    final entered = Completer<void>();
    final release = Completer<void>();
    var current = true;
    final result = runInventorySession<void>(
      () => boundary(
        () => guardedTransaction(database, () async {
          await database.customStatement('INSERT INTO durable_test VALUES (1)');
          entered.complete();
          await release.future;
        }),
        orElse: StoreSecretFailure.new,
      ),
      isCurrent: () => current,
      preserveCommittedCommand: true,
    );
    await entered.future;
    current = false;
    release.complete();
    final returned = await result;
    final rows = await database
        .customSelect('SELECT value FROM durable_test')
        .get();
    await database.close();
    expect(rows, isEmpty);
    expect(returned, isA<Err<void, SecretFailure>>());
  });

  test('a nested stale projection is not published after commit', () async {
    final barrier = _CommitBarrier();
    final database = SecretsDatabase(
      NativeDatabase.memory().interceptWith(barrier),
    );
    await database.customStatement('CREATE TABLE durable_test (value INTEGER)');
    barrier.armed = true;
    var current = true;
    final result = runInventorySession<String>(() async {
      final command = await runInventorySession<void>(
        () => boundary(
          () => guardedTransaction(database, () async {
            await database.customStatement(
              'INSERT INTO durable_test VALUES (1)',
            );
          }),
          orElse: StoreSecretFailure.new,
        ),
        isCurrent: () => current,
        preserveCommittedCommand: true,
      );
      if (command is Err<void, SecretFailure>) return Err(command.failure);
      return const Ok('old view');
    }, isCurrent: () => current);
    await barrier.committed.future.timeout(const Duration(seconds: 5));
    current = false;
    barrier.release.complete();
    final returned = await result;
    final rows = await database
        .customSelect('SELECT value FROM durable_test')
        .get();
    await database.close();
    expect(rows.single.read<int>('value'), 1);
    expect(returned, isA<Err<String, SecretFailure>>());
  });

  Future<SecretsDatabase> seeded(_CommitBarrier barrier) async {
    final database = SecretsDatabase(
      NativeDatabase.memory().interceptWith(barrier),
    );
    await database.customStatement(
      "INSERT INTO views (id, name, background_enabled) VALUES ('all', 'all', 0)",
    );
    await database.customStatement(
      "INSERT INTO wallets (id, secret_fingerprint, master_fingerprint, signer, "
      "network, xpub, external_descriptor, internal_descriptor, label, birthday, "
      "is_default) VALUES ('w1', NULL, '01234567', 'none', 'bitcoinMainnet', "
      "'x', 'e', 'i', NULL, NULL, 0)",
    );
    await database.customStatement(
      "INSERT INTO view_members (view_id, member) VALUES ('all', 'wallet:w1')",
    );
    return database;
  }

  Future<Result<void, SecretFailure>> lockAfterCommit(
    _CommitBarrier barrier,
    Future<Result<void, SecretFailure>> Function() command,
  ) async {
    barrier.armed = true;
    var current = true;
    final result = runInventorySession<void>(
      command,
      isCurrent: () => current,
      preserveCommittedCommand: true,
    );
    await barrier.committed.future.timeout(const Duration(seconds: 5));
    current = false;
    barrier.release.complete();
    return result;
  }

  test(
    'a committed wallet removal keeps its durable row change and result',
    () async {
      final barrier = _CommitBarrier();
      final database = await seeded(barrier);
      final returned = await lockAfterCommit(
        barrier,
        () => InventoryRepository(database).remove(view: 'all', id: 'w1'),
      );
      final wallets = await database
          .customSelect('SELECT id FROM wallets')
          .get();
      final members = await database
          .customSelect('SELECT member FROM view_members')
          .get();
      await database.close();
      expect(wallets, isEmpty);
      expect(members, isEmpty);
      expect(returned, isA<Ok<void, SecretFailure>>());
    },
  );

  test(
    'a committed background grant keeps its durable value and result',
    () async {
      final barrier = _CommitBarrier();
      final database = await seeded(barrier);
      final returned = await lockAfterCommit(
        barrier,
        () => AccessRepository(
          database,
          BackupGuard(null),
        ).setBackgroundEnabled(true),
      );
      final rows = await database
          .customSelect('SELECT background_enabled AS b FROM views')
          .get();
      await database.close();
      expect(rows.single.read<int>('b'), 1);
      expect(returned, isA<Ok<void, SecretFailure>>());
    },
  );

  test(
    'only commands are acknowledged after a commit, never reads or reveals',
    () {
      final source = File('lib/src/public/secrets_inventory.dart')
          .readAsStringSync();
      final marked = RegExp(
        r'Future<Result<void, SecretFailure>> (\w+)\([^;]*?'
        r'preserveCommittedCommand: true',
        dotAll: true,
      ).allMatches(source).map((match) => match.group(1)).toList();
      expect(
        marked,
        unorderedEquals([
          'setCredential',
          'removeCredential',
          'setBackgroundEnabled',
          'removeWallet',
        ]),
      );
      expect(
        'preserveCommittedCommand: true'.allMatches(source).length,
        4,
        reason: 'a read, a reveal or a projection must never be preserved',
      );
    },
  );
}
