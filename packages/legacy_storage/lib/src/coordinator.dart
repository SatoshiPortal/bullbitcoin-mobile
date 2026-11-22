import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../legacy_storage.dart';
import 'lifecycle.dart';

/// Every legacy obligation, including projections from shared historical rows.
const splitV1Owners = <String>{
  'electrum',
  'mempool',
  'labels',
  'preferences',
  'swaps',
  'announcements',
  'secrets',
  'signers',
  'sync',
  'exchange',
  'payjoin',
  'recoverbull',
};

enum OwnerOrigin { legacy, fresh }

enum OwnerReadiness { pending, imported, initialized }

final class LegacySource {
  final File file;
  final int schemaVersion;
  const LegacySource(this.file, this.schemaVersion);
}

abstract interface class LegacyImportParticipant {
  String get ownerId;
  Future<bool> hasState();
  @useResult
  Future<Result<PreparedOwner, LegacyImportFailure>> prepare(
    ExclusiveAdmission admission,
    OwnerOrigin origin,
  );
  @useResult
  Future<Result<OwnerReadiness, LegacyImportFailure>> inspect(
    RuntimeAdmission admission,
  );
}

abstract interface class PreparedOwner {
  @useResult
  Future<Result<void, LegacyImportFailure>> importLegacy(LegacySource source);
  @useResult
  Future<Result<void, LegacyImportFailure>> initializeFresh();
  @useResult
  Future<Result<OwnerReadiness, LegacyImportFailure>> receipt();
  @useResult
  Future<Result<void, LegacyImportFailure>> close();
}

/// Historical migrations are provided as an inert factory by composition.
/// This adapter owns all query and connection-lifetime policy.
final class LegacySourceStore<T extends GeneratedDatabase> {
  final LegacySource source;
  final T Function(QueryExecutor) create;

  const LegacySourceStore({required this.source, required this.create});

  Future<void> prepare(ExclusiveAdmission admission) async {
    final (database, handle) = await _open(admission, existing: false);
    await database.customSelect('SELECT 1').get();
    final row = await database.customSelect('PRAGMA user_version').getSingle();
    if (row.read<int>('user_version') != source.schemaVersion) {
      throw const LifecycleException('source_schema');
    }
    await handle.close();
  }

  void verify() {
    final native = sqlite.sqlite3.open(
      source.file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      if (native.userVersion != source.schemaVersion) {
        throw const LifecycleException('source_schema');
      }
    } finally {
      native.close();
    }
  }

  Future<T> open(RuntimeAdmission admission) async {
    verify();
    final (database, _) = await _open(admission, existing: true);
    return database;
  }

  Future<(T, LifecycleHandle)> _open(
    LifecycleAdmission admission, {
    required bool existing,
  }) async {
    final settled = Completer<void>();
    final closed = ReceivePort();
    final confirmed = closed.first;
    T? database;
    DriftIsolate? isolate;
    Future<void>? stopping;
    final handle = admission.track(() async {
      await settled.future;
      try {
        await database?.close();
      } on Exception {
        if (isolate == null) rethrow;
      }
      if (isolate case final worker?) {
        await (stopping ??= worker.shutdownAll());
        await confirmed.timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw const LifecycleException('native_close_unconfirmed'),
        );
      }
      closed.close();
    });
    try {
      final worker = await _spawnSourceWorker(
        source.file.path,
        existing,
        closed.sendPort,
      );
      isolate = worker;
      final selected = create(await worker.connect());
      database = selected;
      return (selected, handle);
    } finally {
      settled.complete();
    }
  }
}

final class StorageCutover {
  final Directory directory;
  final LegacySourceStore legacy;
  final Set<String> expectedOwners;
  final List<LegacyImportParticipant> participants;
  final List<File> destinationFamilies;
  final Future<void> Function(String)? durableStep;

  StorageCutover({
    required this.directory,
    required this.legacy,
    required Set<String> expectedOwners,
    required List<LegacyImportParticipant> participants,
    List<File> destinationFamilies = const [],
    this.durableStep,
  }) : expectedOwners = Set.unmodifiable(expectedOwners),
       participants = List.unmodifiable(participants),
       destinationFamilies = List.unmodifiable(destinationFamilies);

  File get _marker => File('${directory.path}/split-v1.json');
  NativeFileGate get _gate =>
      NativeFileGate(File('${directory.path}/lifecycle.lock'));

  /// Production must supply the complete manifest in one release. An incomplete
  /// development slice never retires the source or advances to retired.
  @useResult
  Future<Result<RuntimeAdmission, LegacyImportFailure>> prepare({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    LifecycleAdmission? held;
    try {
      final LifecycleAdmission exclusive;
      try {
        exclusive = await _gate.acquire(exclusive: true, timeout: timeout);
      } on LifecycleException catch (error) {
        if (error.reason != 'busy') rethrow;
        // A background isolate can hold a shared lease across startup.
        // Admission checks the source and receipts under its own shared lease.
        return await admit(timeout: Duration.zero);
      }
      held = exclusive;
      if (exclusive is! ExclusiveAdmission) {
        throw const LifecycleException('admission');
      }
      var marker = await _read(recover: true);
      if (marker == null) {
        for (final destination in destinationFamilies) {
          if ([
            '',
            '-wal',
            '-shm',
            '-journal',
            '.retire-pending',
          ].any((suffix) => File('${destination.path}$suffix').existsSync())) {
            throw const LifecycleException('unclaimed_destination');
          }
        }
        for (final participant in participants) {
          if (await participant.hasState()) {
            throw const LifecycleException('unclaimed_destination');
          }
        }
        final hasMain = legacy.source.file.existsSync();
        _checkFamily(allowAbsent: true);
        final active = participants.map((p) => p.ownerId).toSet();
        if (!expectedOwners.containsAll(active) ||
            active.length != participants.length) {
          throw const LifecycleException('manifest');
        }
        marker = _CutoverMarker(
          sourceSchemaVersion: legacy.source.schemaVersion,
          initialFresh: !hasMain,
          sourceEstablished: hasMain,
          origins: {
            for (final owner in expectedOwners)
              owner: !hasMain && active.contains(owner)
                  ? OwnerOrigin.fresh
                  : OwnerOrigin.legacy,
          },
        );
        await _publish(marker);
        await durableStep?.call('marker');
      }
      _validate(marker);
      _checkFamily(allowAbsent: !marker.sourceEstablished);
      await legacy.prepare(exclusive);
      await durableStep?.call('source-prepared');
      if (!marker.sourceEstablished) {
        marker = marker.established();
        await _publish(marker);
      }
      await durableStep?.call('source-established');
      for (final participant in participants) {
        final origin = marker.origins[participant.ownerId];
        if (origin == null) throw const LifecycleException('owner');
        final prepared = await participant.prepare(exclusive, origin);
        if (prepared case Err(:final failure)) return Err(failure);
        final owner =
            (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
        final result = origin == OwnerOrigin.legacy
            ? await owner.importLegacy(legacy.source)
            : await owner.initializeFresh();
        if (result case Err(:final failure)) return Err(failure);
        final receipt = await owner.receipt();
        if (!_ready(receipt, origin)) throw const LifecycleException('receipt');
        await durableStep?.call('owner-${participant.ownerId}');
        final closed = await owner.close();
        if (closed case Err(:final failure)) return Err(failure);
      }
      await exclusive.close();
      held = null;
      // No handle survives this gap. Revalidate after acquiring the runtime
      // lease rather than assuming flock conversion is atomic.
      final admitted = await admit(timeout: timeout);
      return admitted;
    } on LifecycleException catch (error) {
      return switch (error.reason) {
        'busy' ||
        'runtime_still_open' ||
        'resources_still_open' ||
        'not_ready' ||
        'not_started' => const Err(LegacyImportDeferred()),
        _ => const Err(LegacyImportUnavailable()),
      };
    } on FileSystemException {
      return const Err(LegacyImportUnavailable());
    } on FormatException {
      return const Err(LegacyImportUnavailable());
    } on sqlite.SqliteException {
      return const Err(LegacyImportUnavailable());
    } finally {
      try {
        await held?.close();
      } on LifecycleException {
        // Failed resources remain strongly retained by the admission.
      }
    }
  }

  @useResult
  Future<Result<RuntimeAdmission, LegacyImportFailure>> admit({
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    LifecycleAdmission? held;
    try {
      final shared = await _gate.acquire(exclusive: false, timeout: timeout);
      held = shared;
      if (shared is! RuntimeAdmission) {
        throw const LifecycleException('admission');
      }
      final marker = await _read();
      if (marker == null) throw const LifecycleException('not_started');
      _validate(marker);
      if (!marker.sourceEstablished) {
        throw const LifecycleException('not_ready');
      }
      _checkFamily(allowAbsent: false);
      legacy.verify();
      for (final participant in participants) {
        final origin = marker.origins[participant.ownerId];
        if (origin == null) throw const LifecycleException('owner');
        final inspection = await participant.inspect(shared);
        if (inspection case Err(:final failure)) return Err(failure);
        if (!_ready(inspection, origin)) {
          throw const LifecycleException('not_ready');
        }
      }
      held = null;
      return Ok(shared);
    } on LifecycleException catch (error) {
      return switch (error.reason) {
        'busy' ||
        'runtime_still_open' ||
        'resources_still_open' ||
        'not_ready' ||
        'not_started' => const Err(LegacyImportDeferred()),
        _ => const Err(LegacyImportUnavailable()),
      };
    } on FileSystemException {
      return const Err(LegacyImportUnavailable());
    } on FormatException {
      return const Err(LegacyImportUnavailable());
    } on sqlite.SqliteException {
      return const Err(LegacyImportUnavailable());
    } finally {
      try {
        await held?.close();
      } on LifecycleException {
        // Failed resources remain strongly retained by the admission.
      }
    }
  }

  bool _ready(
    Result<OwnerReadiness, LegacyImportFailure> result,
    OwnerOrigin origin,
  ) =>
      result is Ok<OwnerReadiness, LegacyImportFailure> &&
      result.value ==
          (origin == OwnerOrigin.legacy
              ? OwnerReadiness.imported
              : OwnerReadiness.initialized);

  void _checkFamily({required bool allowAbsent}) {
    final file = legacy.source.file;
    final exists = file.existsSync();
    final sidecars = [
      '-wal',
      '-shm',
      '-journal',
    ].any((suffix) => File('${file.path}$suffix').existsSync());
    if ((!exists && (!allowAbsent || sidecars)) ||
        (exists && file.lengthSync() == 0 && sidecars)) {
      throw const LifecycleException('source_family');
    }
  }

  void _validate(_CutoverMarker marker) {
    if (!marker.initialFresh &&
        (!marker.sourceEstablished ||
            marker.origins.values.any(
              (origin) => origin == OwnerOrigin.fresh,
            ))) {
      throw const LifecycleException('provenance');
    }
    if (marker.sourceSchemaVersion != legacy.source.schemaVersion ||
        marker.origins.length != expectedOwners.length ||
        !expectedOwners.containsAll(marker.origins.keys)) {
      throw const LifecycleException('manifest');
    }
  }

  Future<_CutoverMarker?> _read({bool recover = false}) async {
    if (!await _marker.exists()) {
      if (await File('${_marker.path}.tmp').exists()) {
        if (!recover) throw const LifecycleException('unpublished_marker');
        final temporary = File('${_marker.path}.tmp');
        final pending = _CutoverMarker.decode(await temporary.readAsString());
        _validate(pending);
        await temporary.rename(_marker.path);
        syncLifecycleDirectory(directory);
        return pending;
      }
      return null;
    }
    final marker = _CutoverMarker.decode(await _marker.readAsString());
    if (recover) syncLifecycleDirectory(directory);
    return marker;
  }

  Future<void> _publish(_CutoverMarker marker) async {
    directory.createSync(recursive: true);
    final temporary = File('${_marker.path}.tmp');
    await temporary.writeAsString(jsonEncode(marker.json), flush: true);
    final stage = marker.sourceEstablished ? 'established' : 'initial';
    await durableStep?.call('marker-$stage-flushed');
    await temporary.rename(_marker.path);
    await durableStep?.call('marker-$stage-renamed');
    // Failure after rename is not evidence that the old marker survived.
    // Abort this invocation. The next exclusive admission rereads and validates.
    syncLifecycleDirectory(directory);
  }
}

final class _CutoverMarker {
  final int sourceSchemaVersion;
  final bool initialFresh;
  final bool sourceEstablished;
  final Map<String, OwnerOrigin> origins;

  const _CutoverMarker({
    required this.sourceSchemaVersion,
    required this.initialFresh,
    required this.sourceEstablished,
    required this.origins,
  });

  _CutoverMarker established() => _CutoverMarker(
    sourceSchemaVersion: sourceSchemaVersion,
    initialFresh: initialFresh,
    sourceEstablished: true,
    origins: origins,
  );

  Map<String, Object> get json => {
    'version': 1,
    'protocol': 'split-v1',
    'sourceSchemaVersion': sourceSchemaVersion,
    'state': 'importing',
    'initialFresh': initialFresh,
    'sourceEstablished': sourceEstablished,
    'origins': origins.map((key, value) => MapEntry(key, value.name)),
  };

  static _CutoverMarker decode(String text) {
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['protocol'] != 'split-v1' ||
        value['state'] != 'importing' ||
        value['sourceSchemaVersion'] is! int ||
        value['initialFresh'] is! bool ||
        value['sourceEstablished'] is! bool ||
        value['origins'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid cutover marker');
    }
    final origins = <String, OwnerOrigin>{};
    for (final entry in (value['origins'] as Map<String, dynamic>).entries) {
      origins[entry.key] = switch (entry.value) {
        'legacy' => OwnerOrigin.legacy,
        'fresh' => OwnerOrigin.fresh,
        _ => throw const FormatException('Invalid owner origin'),
      };
    }
    return _CutoverMarker(
      sourceSchemaVersion: value['sourceSchemaVersion'] as int,
      initialFresh: value['initialFresh'] as bool,
      sourceEstablished: value['sourceEstablished'] as bool,
      origins: origins,
    );
  }
}

Future<DriftIsolate> _spawnSourceWorker(
  String path,
  bool existing,
  SendPort closed,
) => DriftIsolate.spawn(
  () => DatabaseConnection(
    NativeDatabase(
      File(path),
      enableMigrations: !existing,
      setup: (database) {
        database.execute('PRAGMA busy_timeout = 2000');
        if (!existing) database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA synchronous = FULL');
      },
    ).interceptWith(NativeCloseAcknowledgement(closed), sticky: false),
  ),
);
