import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/exit_archive/bark_sql_archive_watcher.dart';
import 'package:ark/src/data/exit_archive/bark_sql_observation.dart';
import 'package:ark/src/data/exit_archive/bark_sql_observer.dart';
import 'package:ark/src/data/exit_archive/sqlite_exit_archive.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/bark_sql_fixture.dart';

Future<void> until(bool Function() condition) async {
  final limit = Stopwatch()..start();
  while (!condition()) {
    if (limit.elapsed > const Duration(seconds: 3)) {
      fail('Watcher barrier not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Protocol-only reader fake for scheduling/lifetime, never SQL validation proof.
final class Reader implements BarkSqlObserverPort {
  @override
  final String sourcePath;
  final BarkSqlObservation observation;
  Completer<void>? hold;
  final entered = Completer<void>();
  int reads = 0, reopens = 0, closes = 0;
  Reader(this.sourcePath, this.observation);
  @override
  Future<Result<BarkSqlObservation, ArkWalletFailure>> read() async {
    reads++;
    if (!entered.isCompleted) entered.complete();
    final gate = hold;
    if (gate != null) await gate.future;
    return Ok(observation);
  }

  @override
  void reopen() {
    reopens++;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  late Directory temp;
  late Database writer;
  late String path;
  late SqliteBarkObserver observer;
  late SqliteExitArchive archive;
  BarkSqlArchiveWatcher? watcher;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('ark-watch-');
    final native = Directory('${temp.path}/native')..createSync();
    path = '${native.path}/db.sqlite';
    writer = sqlite3.open(path);
    seed(writer);
    writer.execute('PRAGMA journal_mode=WAL');
    observer = SqliteBarkObserver(sourcePath: path, schema: schema);
    archive = got(
      SqliteExitArchive.open(
        '${temp.path}/archive',
        account,
        create: true,
        sqlSchema: schema,
      ),
    );
  });
  tearDown(() async {
    await watcher?.close();
    watcher = null;
    await observer.close();
    await archive.close();
    writer.close();
    temp.deleteSync(recursive: true);
  });
  List<Row> rows() {
    final db = sqlite3.open('${temp.path}/archive');
    try {
      return db.select('SELECT * FROM opaque_sql_rows').toList();
    } finally {
      db.close();
    }
  }

  test('real DB/WAL events capture new opaque rows and close stops future captures', () async {
    final active = watcher = BarkSqlArchiveWatcher(
      observer: observer,
      archive: archive,
      fallbackInterval: const Duration(seconds: 10),
      changeCoalesce: const Duration(milliseconds: 20),
    );
    got(active.start());
    await until(() => rows().isNotEmpty);
    writer.execute("INSERT INTO bark_vtxo(id,raw_bare) VALUES('event',x'01')");
    await until(() => rows().any((r) => r['source_table'] == 'bark_vtxo'));
    expect(active.sourceFailure, isNull);
    expect(active.archiveFailure, isNull);
    await active.close();
    final count = active.captures;
    writer.execute("UPDATE bark_vtxo SET raw_bare=x'02'");
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(active.captures, count);
  });
  test(
    'move INTO configured path reopens retained old inode before new read',
    () async {
      final active = watcher = BarkSqlArchiveWatcher(
        observer: observer,
        archive: archive,
        fallbackInterval: const Duration(seconds: 10),
        changeCoalesce: const Duration(milliseconds: 20),
      );
      got(active.start());
      await until(() => active.lastObservedToken != null);
      final old = active.lastObservedToken;
      writer.close();
      final stage = '${File(path).parent.path}/replacement.sqlite';
      final replacement = sqlite3.open(stage);
      seed(replacement);
      replacement.execute(
        "INSERT INTO bark_vtxo(id,raw_bare) VALUES('replacement',x'02')",
      );
      replacement.close();
      File(stage).renameSync(path);
      writer = sqlite3.open(path);
      await until(
        () => rows().any((r) => r['row_key'] == '["text","replacement"]'),
      );
      expect(
        active.lastObservedToken?.epochConn,
        greaterThan(old?.epochConn ?? 0),
      );
    },
  );
  test('SHM and unrelated files never create a self-trigger loop', () async {
    final observation = got(await observer.read());
    final fakePath = '${temp.path}/events/db.sqlite';
    Directory(File(fakePath).parent.path).createSync();
    File(fakePath).writeAsStringSync('event fixture');
    final reader = Reader(fakePath, observation);
    final active = watcher = BarkSqlArchiveWatcher(
      observer: reader,
      archive: archive,
      fallbackInterval: const Duration(seconds: 10),
      changeCoalesce: const Duration(milliseconds: 20),
    );
    got(active.start());
    await until(() => reader.reads == 1 && rows().isNotEmpty);
    File('$fakePath-shm').writeAsStringSync('ignored');
    File('${File(fakePath).parent.path}/unrelated')
        .writeAsStringSync('ignored');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(reader.reads, 1);
  });
  test(
    'first event deadline survives a continuous modification burst',
    () async {
      final observation = got(await observer.read());
      final fakePath = '${temp.path}/events/db.sqlite';
      Directory(File(fakePath).parent.path).createSync();
      File(fakePath).writeAsStringSync('event fixture');
      final reader = Reader(fakePath, observation);
      final active = watcher = BarkSqlArchiveWatcher(
        observer: reader,
        archive: archive,
        fallbackInterval: const Duration(seconds: 10),
        changeCoalesce: const Duration(milliseconds: 50),
      );
      got(active.start());
      await until(() => reader.reads == 1 && rows().isNotEmpty);
      final burst = Timer.periodic(
        const Duration(milliseconds: 5),
        (t) => File(fakePath).writeAsStringSync('${t.tick}'),
      );
      try {
        await until(() => reader.reads >= 2);
      } finally {
        burst.cancel();
      }
      expect(active.archiveFailure, isNull);
    },
  );
  test('source replacement during admitted read is deferred and retained for next pass', () async {
    final reader = Reader(path, got(await observer.read()))
      ..hold = Completer<void>();
    final active = watcher = BarkSqlArchiveWatcher(
      observer: reader,
      archive: archive,
      fallbackInterval: const Duration(seconds: 10),
      changeCoalesce: Duration.zero,
    );
    got(active.start());
    await reader.entered.future;
    active.sourceReplaced();
    expect(reader.reopens, 0);
    final gate = reader.hold;
    reader.hold = null;
    gate?.complete();
    await until(() => reader.reads >= 2);
    expect(reader.reopens, 1);
    expect(reader.closes, 0);
  });
  test('close awaits admitted reader and append before closing resources, never rearms', () async {
    final reader = Reader(path, got(await observer.read()))
      ..hold = Completer<void>();
    final active = watcher = BarkSqlArchiveWatcher(
      observer: reader,
      archive: archive,
      fallbackInterval: const Duration(milliseconds: 20),
    );
    got(active.start());
    await reader.entered.future;
    var settled = false;
    final closing = active.close().then((_) => settled = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(settled, isFalse);
    expect(reader.closes, 0);
    reader.hold?.complete();
    await closing;
    expect(reader.closes, 1);
    final count = reader.reads;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(reader.reads, count);
    expect(await active.capture(), isA<Err>());
  });
  test(
    'watch failure remains visible despite successful fallback capture',
    () async {
      final reader = Reader(
        '${temp.path}/absent/db.sqlite',
        got(await observer.read()),
      );
      final active = watcher = BarkSqlArchiveWatcher(
        observer: reader,
        archive: archive,
        fallbackInterval: const Duration(milliseconds: 20),
      );
      got(active.start());
      await until(() => reader.reads >= 2);
      expect(active.watchFailure, isNotNull);
      expect(active.sourceFailure, isNull);
      expect(rows(), isNotEmpty);
    },
  );
  test(
    'controlled watch failure stays sticky across a late old WAL event',
    () async {
      final reader = Reader(path, got(await observer.read()));
      final events = StreamController<FileSystemEvent>();
      final transitions = <ArkWalletFailure?>[];
      await IOOverrides.runZoned(() async {
        final active = watcher = BarkSqlArchiveWatcher(
          observer: reader,
          archive: archive,
          fallbackInterval: const Duration(seconds: 10),
          changeCoalesce: Duration.zero,
          onStatus: (stage, failure) {
            if (stage == BarkSqlWatchStage.watch) transitions.add(failure);
          },
        );
        try {
          got(active.start());
          await until(() => reader.reads == 1 && rows().isNotEmpty);
          events.addError(const FileSystemException('controlled watch loss'));
          await until(() => active.watchFailure != null);
          events.add(FileSystemCreateEvent('$path-wal', false));
          await until(() => reader.reads >= 2);
          expect(active.watchFailure, isNotNull);
          expect(transitions.last, isNotNull);
        } finally {
          await active.close();
          await events.close();
        }
      }, fsWatch: (path, flags, recursive) => events.stream);
    },
  );
  test(
    'physical source/archive alias refuses before reader admission',
    () async {
      final alias = '${temp.path}/archive-alias';
      Link(alias).createSync(archive.archivePath);
      final reader = Reader(alias, got(await observer.read()));
      final active = watcher = BarkSqlArchiveWatcher(
        observer: reader,
        archive: archive,
      );
      expect(active.start(), isA<Err>());
      expect(await active.capture(), isA<Err>());
      expect(reader.reads, 0);
      expect(reader.reopens, 0);
    },
  );
  test(
    'capture failure leaves actual durable financial evidence untouched',
    () async {
      final financialPath = '${temp.path}/financial';
      final financial = ArkStore.open(financialPath, create: true);
      financial.saveOperation(
        ArkOperation(
          id: 'uncertain',
          kind: ArkOperationKind.payment,
          status: ArkOperationStatus.outcomeUnknown,
          chainSource: Uri.parse('http://localhost:3000'),
          configGeneration: 1,
          actualIds: ['protected-input'],
        ),
        'binding',
        evidence: {'reference': 'public-fact'},
      );
      financial.close();
      final original = File(financialPath).readAsBytesSync();
      final db = sqlite3.open(archive.archivePath);
      db.execute(
        "CREATE TRIGGER deny_capture BEFORE UPDATE ON archive_meta BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      db.close();
      final active = watcher = BarkSqlArchiveWatcher(
        observer: observer,
        archive: archive,
      );
      expect(await active.capture(), isA<Err>());
      expect(active.archiveFailure, isNotNull);
      expect(File(financialPath).readAsBytesSync(), original);
      final reopened = ArkStore.open(financialPath, create: false);
      try {
        expect(
          reopened.operation('uncertain')?.operation.status,
          ArkOperationStatus.outcomeUnknown,
        );
        expect(reopened.operation('uncertain')?.operation.actualIds, [
          'protected-input',
        ]);
      } finally {
        reopened.close();
      }
    },
  );
  test(
    'status callbacks deduplicate bounded reasons and report actual recovery',
    () async {
      final changes = <(BarkSqlWatchStage, ArkFailureReason?)>[];
      final active = watcher = BarkSqlArchiveWatcher(
        observer: observer,
        archive: archive,
        onStatus: (stage, failure) => changes.add((stage, failure?.reason)),
      );
      got(await active.capture());
      writer.execute(
        "UPDATE bark_properties SET fingerprint='invalid-fingerprint'",
      );
      expect(await active.capture(), isA<Err>());
      expect(await active.capture(), isA<Err>());
      expect(changes, [
        (BarkSqlWatchStage.source, ArkFailureReason.identityMismatch),
      ]);
      writer.execute('UPDATE bark_properties SET fingerprint=?', [
        schema.expectedNativeFingerprint,
      ]);
      got(await active.capture());
      expect(changes.last, (BarkSqlWatchStage.source, null));
      expect(active.sourceFailure, isNull);
    },
  );
  test(
    'standalone package runner starts real watcher and drains on SIGINT',
    () async {
      final config = File('${temp.path}/example-config.json')
        ..writeAsStringSync(
          jsonEncode({
            'sourcePath': path,
            'archivePath': '${temp.path}/example-archive',
            'namespaceFingerprint': account.parent.hex,
            'expectedNativeFingerprint': schema.expectedNativeFingerprint,
            'expectedServerPubkey': schema.expectedServerPubkey,
          }),
        );
      final packageConfig = await Isolate.packageConfig;
      final package = await Isolate.resolvePackageUri(
        Uri.parse('package:ark/ark.dart'),
      );
      if (packageConfig == null || package == null) {
        fail('Missing pinned package resolution');
      }
      final process = await Process.start(Platform.resolvedExecutable, [
        '--packages=${packageConfig.toFilePath()}',
        package.resolve('../example/sql_archive_watch.dart').toFilePath(),
        config.path,
      ]);
      final errors = <String>[];
      final stderr = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) {
            errors.add(line);
            return line;
          })
          .join('\n');
      try {
        final started = await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((_) => true, orElse: () => '');
        expect(
          started,
          contains('watcher started'),
          reason: started.isEmpty ? await stderr : null,
        );
        writer.execute('UPDATE bark_properties SET fingerprint=?', [
          'DO_NOT_LOG_SOURCE_PAYLOAD',
        ]);
        await until(
          () => errors.any(
            (line) => line == 'watcher.source: validation identityMismatch',
          ),
        );
        writer.execute('UPDATE bark_properties SET fingerprint=?', [
          'DO_NOT_LOG_SECOND_VALUE',
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(
          errors.where(
            (line) => line == 'watcher.source: validation identityMismatch',
          ),
          hasLength(1),
        );
        writer.execute('UPDATE bark_properties SET fingerprint=?', [
          schema.expectedNativeFingerprint,
        ]);
        await until(() => errors.contains('watcher.source: ok recovered'));
        process.kill(ProcessSignal.sigint);
        expect(await process.exitCode, 0, reason: await stderr);
        for (final text in errors) {
          expect(text, isNot(contains(temp.path)));
          expect(text, isNot(contains('DO_NOT_LOG')));
          expect(text, isNot(contains(schema.expectedServerPubkey)));
        }
        final own = sqlite3.open('${temp.path}/example-archive');
        try {
          expect(
            own.select('SELECT count(*) AS n FROM opaque_sql_rows').single['n'],
            greaterThan(0),
          );
        } finally {
          own.close();
        }
      } finally {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode;
      }
    },
  );
}
