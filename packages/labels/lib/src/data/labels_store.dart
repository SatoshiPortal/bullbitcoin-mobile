import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:flutter/services.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'labels_database.dart';

final class LabelsStore {
  final LabelsDatabase database;
  final LifecycleHandle handle;

  const LabelsStore(this.database, this.handle);

  static Future<Result<LabelsStore, DatabaseOpenFailure>> open(
    File file,
    LifecycleAdmission admission, {
    required bool existing,
    DatabaseKeys? testingKeys,
    Future<DriftIsolate> Function(String, bool, SendPort, SendPort)?
    testingWorker,
  }) async {
    final settled = Completer<void>();
    LabelsDatabase? database;
    DriftIsolate? worker;
    Future<void>? shuttingDown;
    ReceivePort? closedPort;
    Future<dynamic>? closedFuture;
    // Reserve ownership before the first await or native open. Concurrent
    // cleanup must wait for startup to settle before releasing the lease.
    final handle = admission.track(() async {
      await settled.future;
      try {
        await database?.close();
      } on Exception {
        if (worker == null) rethrow;
        // Shutdown below must confirm closure of the actual native server.
      }
      if (worker case final current?) {
        await (shuttingDown ??= current.shutdownAll());
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
    Result<LabelsStore, DatabaseOpenFailure> result;
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
            final selected = LabelsDatabase(value);
            database = selected;
            result = Ok(LabelsStore(selected, handle));
        }
      } else {
        final token = RootIsolateToken.instance;
        if (token == null && testingWorker == null) {
          result = const Err(DatabaseNotReady());
        } else {
          final status = ReceivePort();
          final statusFuture = status.first;
          final sendStatus = status.sendPort;
          final path = file.path;
          final confirmation = ReceivePort();
          closedPort = confirmation;
          closedFuture = confirmation.first;
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
              isolate = await _spawnLabelsWorker(
                path,
                existing,
                token,
                sendStatus,
                confirmation.sendPort,
              );
            } else {
              throw const LifecycleException('missing_root_token');
            }
            worker = isolate;
            final selected = LabelsDatabase(await isolate.connect());
            database = selected;
            try {
              await selected.customSelect('SELECT 1').get();
              await statusFuture;
              result = Ok(LabelsStore(selected, handle));
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
    } finally {
      settled.complete();
    }
    if (result is Err<LabelsStore, DatabaseOpenFailure>) await handle.close();
    return result;
  }
}

final class _StoreOpenException implements Exception {
  const _StoreOpenException();
}

// Keep the spawn closure in a scope containing only transferable arguments.
// Capturing the open() frame could capture its ReceivePort and live admission.
Future<DriftIsolate> _spawnLabelsWorker(
  String path,
  bool existing,
  RootIsolateToken token,
  SendPort sendStatus,
  SendPort closed,
) => DriftIsolate.spawn(() {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final notification = NativeCloseAcknowledgement(closed);
  return DatabaseConnection(
    LazyDatabase(() async {
      final opened =
          await Secrets(
                scratchDirectory: () async =>
                    throw UnsupportedError('Database-only capability'),
              )
              .databaseKeys(module: 'labels')
              .open(
                name: 'main',
                file: File(path),
                existingSchemaVersion: existing ? 1 : null,
              );
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
