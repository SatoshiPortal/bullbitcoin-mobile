import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:flutter/services.dart' show RootIsolateToken;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'preferences_database.dart';

final class PreferencesStore {
  final PreferencesDatabase database;
  final LifecycleHandle handle;

  const PreferencesStore(this.database, this.handle);

  static Future<Result<PreferencesStore, DatabaseOpenFailure>> open(
    File file,
    LifecycleAdmission admission, {
    required bool existing,
    DatabaseKeys? testingKeys,
    Future<DriftIsolate> Function(String, bool, SendPort, SendPort)?
    testingWorker,
  }) async {
    final settled = Completer<void>();
    PreferencesDatabase? database;
    DriftIsolate? worker;
    Future<void>? disconnecting;
    Future<void>? shuttingDown;
    ReceivePort? closedPort;
    Future<void>? closedFuture;
    // Reserve ownership before the first await or native open. Concurrent
    // cleanup must wait for startup to settle before releasing the lease.
    final handle = admission.track(() async {
      await settled.future;
      try {
        if (database case final connection?) {
          await (disconnecting ??= connection.close()).timeout(
            const Duration(seconds: 2),
          );
        }
      } on Exception {
        if (worker == null) rethrow;
        // Shutdown below must confirm closure of the actual native server.
      }
      if (worker case final current?) {
        await (shuttingDown ??= current.shutdownAll()).timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw const LifecycleException('worker_shutdown_unconfirmed'),
        );
      } else {
        closedPort?.close();
        return;
      }
      final confirmed = closedFuture;
      if (confirmed != null) {
        await confirmed.timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw const LifecycleException('native_close_unconfirmed'),
        );
        closedPort?.close();
      }
    });
    Result<PreferencesStore, DatabaseOpenFailure> result;
    try {
      if (testingKeys != null) {
        final opened = await testingKeys.open(
          name: 'main',
          file: file,
          existingSchemaVersion: existing ? 1 : null,
        );
        switch (opened) {
          case Err(:final failure):
            result = Err(failure);
          case Ok(:final value):
            final selected = PreferencesDatabase(value);
            database = selected;
            result = Ok(PreferencesStore(selected, handle));
        }
      } else {
        final token = RootIsolateToken.instance;
        if (token == null && testingWorker == null) {
          result = const Err(DatabaseNotReady());
        } else {
          final status = ReceivePort();
          final statusFuture = _receiveAcknowledgement(status);
          final sendStatus = status.sendPort;
          final path = file.path;
          final confirmation = ReceivePort();
          closedPort = confirmation;
          closedFuture = _receiveAcknowledgement(confirmation)
              .then<void>((_) {});
          try {
            final DriftIsolate isolate;
            if (testingWorker != null) {
              isolate = await testingWorker(
                path,
                existing,
                sendStatus,
                confirmation.sendPort,
              );
            } else if (token != null) {
              isolate = await _spawnPreferencesWorker(
                Secrets.databaseOpener<DatabaseOpenFailure>(
                  module: 'preferences',
                  name: 'main',
                  file: file,
                  schema: 1,
                  deferred: const DatabaseNotReady(),
                  unavailable: const DatabaseFileUnavailable(
                    DatabaseFileProblem.inaccessible,
                  ),
                )(existing),
                sendStatus,
                confirmation.sendPort,
              );
            } else {
              throw const LifecycleException('missing_root_token');
            }
            worker = isolate;
            final selected = PreferencesDatabase(await isolate.connect());
            database = selected;
            try {
              await selected.customSelect('SELECT 1').get();
              await statusFuture;
              result = Ok(PreferencesStore(selected, handle));
            } on Exception {
              // The lazy opener reports its bounded failure before rejecting
              // the query; migration failures follow a successful open report.
              final failure = await statusFuture.timeout(
                const Duration(seconds: 2),
                onTimeout: () => const DatabaseNotReady(),
              );
              result = Err(
                failure is DatabaseOpenFailure
                    ? failure
                    : const DatabaseFileUnavailable(
                        DatabaseFileProblem.inaccessible,
                      ),
              );
            }
          } finally {
            status.close();
          }
        }
      }
    } on Exception {
      result = const Err(
        DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
      );
    } finally {
      settled.complete();
    }
    if (result is Err<PreferencesStore, DatabaseOpenFailure>) {
      try {
        await handle.close();
      } on Exception {
        // Admission still owns the handle and retries its native closure.
        return const Err(
          DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
        );
      }
    }
    return result;
  }
}

// A worker that never started closes its ports without a first message.
Future<Object?> _receiveAcknowledgement(ReceivePort port) {
  final received = Completer<Object?>();
  port.listen((Object? message) {
    if (!received.isCompleted) received.complete(message);
  });
  return received.future;
}

final class _StoreOpenException implements Exception {
  const _StoreOpenException();
}

// Keep the spawn closure in a scope containing only transferable arguments.
// Capturing the open() frame could capture its ReceivePort and live admission.
Future<DriftIsolate> _spawnPreferencesWorker(
  Future<Result<QueryExecutor, DatabaseOpenFailure>> Function() openExecutor,
  SendPort sendStatus,
  SendPort closed,
) => DriftIsolate.spawn(() {
  final notification = NativeCloseAcknowledgement(closed);
  return DatabaseConnection(
    LazyDatabase(() async {
      final opened = await openExecutor();
      switch (opened) {
        case Ok(:final value):
          sendStatus.send(null);
          return value;
        case Err(:final failure):
          notification.openFailedWithoutHandle();
          sendStatus.send(failure);
          throw const _StoreOpenException();
      }
    }).interceptWith(notification, sticky: false),
  );
});
