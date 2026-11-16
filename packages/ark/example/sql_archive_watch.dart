import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/exit_archive/bark_sql_archive_watcher.dart';
import 'package:ark/src/data/exit_archive/bark_sql_observer.dart';
import 'package:ark/src/data/exit_archive/bark_sql_schema.dart';
import 'package:ark/src/data/exit_archive/sqlite_exit_archive.dart';
import 'package:primitives/primitives.dart';

String field(Map<String, Object?> config, String name) {
  final value = config[name];
  if (value is! String || value.isEmpty) throw const FormatException();
  return value;
}

T accepted<T>(Result<T, ArkWalletFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw _Refused(failure),
};

/// Explicit Linux regtest runner. Not mounted into ArkClient or the app.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: sql_archive_watch.dart CONFIG.json');
    exitCode = 64;
    return;
  }
  SqliteBarkObserver? observer;
  SqliteExitArchive? archive;
  BarkSqlArchiveWatcher? watcher;
  final signals = <StreamSubscription<ProcessSignal>>[];
  try {
    final config = jsonDecode(File(args.single).readAsStringSync());
    if (config is! Map<String, Object?>) throw const FormatException();
    final sourcePath = field(config, 'sourcePath'),
        archivePath = field(config, 'archivePath');
    if (File(sourcePath).absolute.uri.normalizePath() ==
            File(archivePath).absolute.uri.normalizePath() ||
        (File(sourcePath).existsSync() &&
            File(archivePath).existsSync() &&
            FileSystemEntity.identicalSync(
              File(sourcePath).resolveSymbolicLinksSync(),
              File(archivePath).resolveSymbolicLinksSync(),
            ))) {
      throw const FormatException();
    }
    final namespace = field(config, 'namespaceFingerprint');
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(namespace)) {
      throw const FormatException();
    }
    final server = field(config, 'expectedServerPubkey');
    // Standalone namespace only; this does NOT authenticate a BIP85 parent.
    final account = ArkAccountId(
      parent: Fingerprint(namespace),
      network: BitcoinNetwork.regtest,
      serverIdentity: server,
    );
    final schema = BarkSqlSchema(
      account,
      field(config, 'expectedNativeFingerprint'),
      server,
    );
    observer = SqliteBarkObserver(sourcePath: sourcePath, schema: schema);
    accepted(await observer.read());
    archive = accepted<SqliteExitArchive>(
      SqliteExitArchive.open(
        archivePath,
        account,
        create: true,
        sqlSchema: schema,
        derivationProfile: 'regtest-sql-opaque',
      ),
    );
    watcher = BarkSqlArchiveWatcher(
      observer: observer,
      archive: archive,
      onStatus: (stage, failure) {
        final kind = switch (failure) {
          null => 'ok',
          ArkStorageFailure() => 'storage',
          ArkValidationFailure() => 'validation',
          ArkUnavailableFailure() => 'unavailable',
          _ => 'other',
        };
        stderr.writeln(
          'watcher.${stage.name}: $kind ${failure?.reason.name ?? 'recovered'}',
        );
      },
    );
    final stop = Completer<void>();
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      signals.add(
        signal.watch().listen((_) {
          if (!stop.isCompleted) stop.complete();
        }),
      );
    }
    accepted(await watcher.capture());
    if (stop.isCompleted) return;
    accepted(watcher.start());
    stdout.writeln(
      'Regtest SQL archive watcher started; opaque evidence remains incomplete.',
    );
    await stop.future;
  } on _Refused catch (refusal) {
    stderr.writeln('Watcher refused: ${refusal.failure.reason.name}');
    exitCode = 1;
  } on FormatException {
    stderr.writeln('Invalid regtest watcher configuration.');
    exitCode = 64;
  } on FileSystemException {
    stderr.writeln('Watcher filesystem unavailable.');
    exitCode = 1;
  } finally {
    for (final signal in signals) {
      await signal.cancel();
    }
    final active = watcher;
    if (active != null) {
      await active.close();
    } else {
      await observer?.close();
      await archive?.close();
    }
  }
}

final class _Refused implements Exception {
  final ArkWalletFailure failure;
  _Refused(this.failure);
}
