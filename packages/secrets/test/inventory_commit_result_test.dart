import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/backup_guard.dart';
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
}
