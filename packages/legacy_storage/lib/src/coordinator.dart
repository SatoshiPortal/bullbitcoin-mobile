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
import 'retirement.dart';

/// Last published schema of the source imported by split-v1.
const splitV1SourceSchemaVersion = 16;

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

  /// True when the install had no legacy database before its first cutover,
  /// so the database was created afterwards. It may still hold data the app
  /// wrote since, which an owner must import rather than discard.
  final bool initialFresh;

  const LegacySource(
    this.file,
    this.schemaVersion, {
    this.initialFresh = false,
  });
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
    LifecycleAdmission admission,
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

/// An owner whose legacy sources live outside the shared legacy database can
/// refuse an initial state it cannot reconcile. The coordinator asks before it
/// publishes the first marker and again before it prepares an owner that the
/// marker has not admitted, because a marker published before the owner joined
/// the manifest never ran the first check.
abstract interface class SourceProvenanceCheck {
  /// [legacySqlitePresent] is true when the shared legacy database existed
  /// before this cutover started. A failure leaves every source untouched.
  @useResult
  Future<Result<void, LegacyImportFailure>> verifyInitialSource(
    ExclusiveAdmission admission, {
    required bool legacySqlitePresent,
  });
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
  final List<LegacyRetirementParticipant> retirementParticipants;
  final Set<String> requiredRetirementOwners;
  final Future<void> Function(String)? durableStep;

  /// Production supplies no [retirementParticipants] until the activation
  /// step: without them the retirement gate refuses and nothing is evaluated
  /// as eligible.
  StorageCutover({
    required this.directory,
    required this.legacy,
    required Set<String> expectedOwners,
    required List<LegacyImportParticipant> participants,
    List<File> destinationFamilies = const [],
    List<LegacyRetirementParticipant> retirementParticipants = const [],
    Set<String> requiredRetirementOwners = legacyRetirementOwners,
    this.durableStep,
  }) : expectedOwners = Set.unmodifiable(expectedOwners),
       participants = List.unmodifiable(participants),
       destinationFamilies = List.unmodifiable(destinationFamilies),
       retirementParticipants = List.unmodifiable(retirementParticipants),
       requiredRetirementOwners = Set.unmodifiable(requiredRetirementOwners);

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
      if (marker != null && marker.state != RetirementState.importing) {
        _validate(marker);
        return Err(_retirementBlock(marker));
      }
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
        for (final participant in participants) {
          if (participant case final SourceProvenanceCheck check) {
            final verified = await check.verifyInitialSource(
              exclusive,
              legacySqlitePresent: hasMain,
            );
            if (verified case Err(:final failure)) return Err(failure);
          }
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
      for (final participant in participants) {
        if (marker.admittedOwners.contains(participant.ownerId) &&
            !await participant.hasState()) {
          return const Err(LegacyImportUnavailable());
        }
      }
      await legacy.prepare(exclusive);
      await durableStep?.call('source-prepared');
      if (!marker.sourceEstablished) {
        marker = marker.established();
        await _publish(marker);
      }
      await durableStep?.call('source-established');
      var established = marker;
      for (final participant in participants) {
        final ownerId = participant.ownerId;
        // The legacy source no longer contains all writes to an admitted owner.
        if (established.admittedOwners.contains(ownerId)) continue;
        // The first marker alone fixes an origin; a resume never rewrites it.
        final origin = established.origins[ownerId];
        if (origin == null) throw const LifecycleException('owner');
        // A marker published before this owner joined the manifest skipped
        // the first-marker check, so ask again before the owner is prepared.
        if (participant case final SourceProvenanceCheck check) {
          final verified = await check.verifyInitialSource(
            exclusive,
            legacySqlitePresent: !established.initialFresh,
          );
          if (verified case Err(:final failure)) return Err(failure);
        }
        final prepared = await participant.prepare(exclusive, origin);
        if (prepared case Err(:final failure)) return Err(failure);
        final owner =
            (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
        final result = origin == OwnerOrigin.legacy
            ? await owner.importLegacy(
                LegacySource(
                  legacy.source.file,
                  legacy.source.schemaVersion,
                  initialFresh: established.initialFresh,
                ),
              )
            : await owner.initializeFresh();
        if (result case Err(:final failure)) return Err(failure);
        final receipt = await owner.receipt();
        if (!_ready(receipt, origin)) throw const LifecycleException('receipt');
        await durableStep?.call('owner-$ownerId');
        final closed = await owner.close();
        if (closed case Err(:final failure)) return Err(failure);
        established = established.withAdmittedOwner(ownerId);
        await _publish(established, stage: 'owner-$ownerId');
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
      if (marker.state != RetirementState.importing) {
        return Err(_retirementBlock(marker));
      }
      if (!marker.sourceEstablished) {
        throw const LifecycleException('not_ready');
      }
      _checkFamily(allowAbsent: false);
      legacy.verify();
      for (final participant in participants) {
        final ownerId = participant.ownerId;
        final origin = marker.origins[ownerId];
        if (origin == null) throw const LifecycleException('owner');
        if (!marker.admittedOwners.contains(ownerId)) {
          return const Err(LegacyImportDeferred());
        }
        if (!await participant.hasState()) {
          return const Err(LegacyImportUnavailable());
        }
        final inspection = await participant.inspect(shared);
        if (inspection case Err(:final failure)) return Err(failure);
        if (!_ready(inspection, origin)) {
          throw const LifecycleException('not_ready');
        }
      }
      // A foreground publisher may have died after rename but before fsync.
      // No runtime writes may start off a non-durable owner milestone.
      if (participants.isNotEmpty) syncLifecycleDirectory(directory);
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
        !expectedOwners.containsAll(marker.origins.keys) ||
        !expectedOwners.containsAll(marker.admittedOwners) ||
        (!marker.sourceEstablished && marker.admittedOwners.isNotEmpty)) {
      throw const LifecycleException('manifest');
    }
    if (marker.state != RetirementState.importing &&
        (!marker.sourceEstablished ||
            marker.admittedOwners.length != expectedOwners.length ||
            !marker.admittedOwners.containsAll(expectedOwners))) {
      throw const LifecycleException('retirement');
    }
    if (marker.retireDoneSteps.any(
      (step) =>
          !step.startsWith('keychain:') ||
          !expectedOwners.contains(step.substring('keychain:'.length)),
    )) {
      throw const LifecycleException('retirement');
    }
  }

  /// A marker past `importing` never admits: `retiring` waits for the resumed
  /// cleanup, `retired` is handled by the activation step.
  LegacyImportFailure _retirementBlock(_CutoverMarker marker) =>
      marker.state == RetirementState.retiring
      ? const LegacyImportDeferred()
      : const LegacyImportUnavailable();

  /// Evaluates the retirement gate without changing business data or markers.
  /// Acquiring the lease may create its lock file. Opening destination stores
  /// read-write may create or update SQLite WAL/SHM files; this is not a claim
  /// of physical filesystem immutability. A shared lease blocks this check.
  Future<RetirementReport> evaluateRetirement({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    LifecycleAdmission? held;
    try {
      final LifecycleAdmission exclusive;
      try {
        exclusive = await _gate.acquire(exclusive: true, timeout: timeout);
      } on LifecycleException {
        return RetirementReport(null, const ['lease_not_exclusive']);
      }
      held = exclusive;
      if (exclusive is! ExclusiveAdmission) {
        return RetirementReport(null, const ['lease_not_exclusive']);
      }
      final _CutoverMarker? marker;
      try {
        marker = await _read();
      } on Exception {
        return RetirementReport(null, const ['marker_unreadable']);
      }
      if (marker == null) {
        return RetirementReport(null, const ['marker_missing']);
      }
      try {
        _validate(marker);
      } on LifecycleException {
        return RetirementReport(marker.state, const ['marker_invalid']);
      }
      if (marker.state != RetirementState.importing) {
        return RetirementReport(marker.state, [
          marker.state == RetirementState.retiring
              ? 'retiring_in_progress'
              : 'already_retired',
        ]);
      }
      return RetirementReport(
        marker.state,
        await _gateBlockers(exclusive, marker),
      );
    } on Exception {
      return RetirementReport(null, const ['evaluation_failed']);
    } finally {
      try {
        await held?.close();
      } on LifecycleException {
        // Failed resources remain strongly retained by the admission.
      }
    }
  }

  /// Every blocker, or none when the retirement is allowed. Structural
  /// blockers stop the evaluation before any owner database is opened.
  Future<List<String>> _gateBlockers(
    ExclusiveAdmission exclusive,
    _CutoverMarker marker,
  ) async {
    final blockers = <String>[];
    final imported = participants.map((p) => p.ownerId).toList();
    final retiring = retirementParticipants.map((p) => p.ownerId).toList();
    if (imported.toSet().length != imported.length ||
        !imported.toSet().containsAll(expectedOwners) ||
        imported.toSet().length != expectedOwners.length ||
        marker.origins.length != expectedOwners.length ||
        !marker.admittedOwners.containsAll(expectedOwners) ||
        marker.admittedOwners.length != expectedOwners.length) {
      blockers.add('owner_manifest');
    }
    if (retiring.toSet().length != retiring.length ||
        !retiring.toSet().containsAll(requiredRetirementOwners) ||
        !expectedOwners.containsAll(retiring)) {
      blockers.add('retirement_participants');
    }
    if (!marker.sourceEstablished) blockers.add('source_not_established');
    if (blockers.isNotEmpty) return blockers;
    try {
      _checkFamily(allowAbsent: false);
      legacy.verify();
    } on Exception {
      return ['source_family'];
    }
    for (final participant in participants) {
      final ownerId = participant.ownerId;
      final origin = marker.origins[ownerId];
      if (origin == null) {
        blockers.add('owner_manifest');
        continue;
      }
      if (!await participant.hasState()) {
        blockers.add('destination:$ownerId');
        continue;
      }
      Result<OwnerReadiness, LegacyImportFailure> inspection;
      try {
        inspection = await participant.inspect(exclusive);
      } on Exception {
        inspection = const Err(LegacyImportUnavailable());
      }
      if (!_ready(inspection, origin)) blockers.add('receipt:$ownerId');
    }
    if (blockers.isNotEmpty) return blockers;
    for (final participant in retirementParticipants) {
      final origin = marker.origins[participant.ownerId];
      if (origin == null) {
        blockers.add('owner_manifest');
        continue;
      }
      Result<void, LegacyImportFailure> verdict;
      try {
        verdict = await participant.verifyRetirable(
          exclusive,
          origin: origin,
          source: legacy.source,
        );
      } on Exception {
        verdict = const Err(LegacyImportUnavailable());
      }
      if (verdict case Err(:final failure)) {
        blockers.add('proof:${participant.ownerId}:${failure.runtimeType}');
      }
    }
    // D94 recovery provenance is not yet available on this base. A receipt
    // alone cannot establish that every historical owner survived recovery.
    // Remain closed until the recovery journal has an independent verifier.
    blockers.add('recovery_provenance_unavailable');
    return blockers;
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

  Future<void> _publish(_CutoverMarker marker, {String? stage}) async {
    directory.createSync(recursive: true);
    final temporary = File('${_marker.path}.tmp');
    await temporary.writeAsString(jsonEncode(marker.json), flush: true);
    final checkpoint =
        stage ?? (marker.sourceEstablished ? 'established' : 'initial');
    await durableStep?.call('marker-$checkpoint-flushed');
    await temporary.rename(_marker.path);
    await durableStep?.call('marker-$checkpoint-renamed');
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
  final Set<String> admittedOwners;
  final RetirementState state;
  final int? retireIntentAt;
  final Set<String> retireDoneSteps;

  const _CutoverMarker({
    required this.sourceSchemaVersion,
    required this.initialFresh,
    required this.sourceEstablished,
    required this.origins,
    this.admittedOwners = const {},
    this.state = RetirementState.importing,
    this.retireIntentAt,
    this.retireDoneSteps = const {},
  });

  _CutoverMarker _copy({
    bool? sourceEstablished,
    Map<String, OwnerOrigin>? origins,
    Set<String>? admittedOwners,
    RetirementState? state,
    int? retireIntentAt,
    Set<String>? retireDoneSteps,
  }) => _CutoverMarker(
    sourceSchemaVersion: sourceSchemaVersion,
    initialFresh: initialFresh,
    sourceEstablished: sourceEstablished ?? this.sourceEstablished,
    origins: origins ?? this.origins,
    admittedOwners: admittedOwners ?? this.admittedOwners,
    state: state ?? this.state,
    retireIntentAt: retireIntentAt ?? this.retireIntentAt,
    retireDoneSteps: retireDoneSteps ?? this.retireDoneSteps,
  );

  _CutoverMarker established() => _copy(sourceEstablished: true);

  _CutoverMarker withAdmittedOwner(String owner) =>
      _copy(admittedOwners: {...admittedOwners, owner});

  /// Importing markers keep the format of the shipped coordinator so a
  /// downgrade still reads them. Only a retirement bumps the version, and the
  /// older decoders reject it: that is the anti-rollback protection.
  Map<String, Object> get json => {
    'version': state == RetirementState.importing ? 2 : 3,
    'protocol': 'split-v1',
    'sourceSchemaVersion': sourceSchemaVersion,
    'state': state.name,
    'initialFresh': initialFresh,
    'sourceEstablished': sourceEstablished,
    'origins': origins.map((key, value) => MapEntry(key, value.name)),
    'admittedOwners': admittedOwners.toList()..sort(),
    if (state != RetirementState.importing)
      'retire': {
        'intentAt': ?retireIntentAt,
        'doneSteps': retireDoneSteps.toList()..sort(),
      },
  };

  static _CutoverMarker decode(String text) {
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic> ||
        (value['version'] != 1 &&
            value['version'] != 2 &&
            value['version'] != 3) ||
        value['protocol'] != 'split-v1' ||
        value['sourceSchemaVersion'] is! int ||
        value['initialFresh'] is! bool ||
        value['sourceEstablished'] is! bool ||
        value['origins'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid cutover marker');
    }
    final state = RetirementState.values
        .where((candidate) => candidate.name == value['state'])
        .firstOrNull;
    if (state == null ||
        (state != RetirementState.importing && value['version'] != 3)) {
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
    // The field did not exist in the provisional S1a development marker.
    final admittedOwners = <String>{};
    if (value['version'] != 1 || value.containsKey('admittedOwners')) {
      final raw = value['admittedOwners'];
      if (raw is! List<dynamic>) {
        throw const FormatException('Invalid owner admission');
      }
      for (final owner in raw) {
        if (owner is! String || !admittedOwners.add(owner)) {
          throw const FormatException('Invalid owner admission');
        }
      }
    }
    int? intentAt;
    final doneSteps = <String>{};
    final retire = value['retire'];
    if (state == RetirementState.importing) {
      if (retire != null) throw const FormatException('Invalid retirement');
    } else {
      if (retire is! Map<String, dynamic> ||
          retire['intentAt'] is! int ||
          retire['doneSteps'] is! List<dynamic>) {
        throw const FormatException('Invalid retirement');
      }
      intentAt = retire['intentAt'] as int;
      for (final step in retire['doneSteps'] as List<dynamic>) {
        if (step is! String ||
            !step.startsWith('keychain:') ||
            !origins.containsKey(step.substring('keychain:'.length)) ||
            !doneSteps.add(step)) {
          throw const FormatException('Invalid retirement');
        }
      }
    }
    return _CutoverMarker(
      sourceSchemaVersion: value['sourceSchemaVersion'] as int,
      initialFresh: value['initialFresh'] as bool,
      sourceEstablished: value['sourceEstablished'] as bool,
      origins: origins,
      admittedOwners: admittedOwners,
      state: state,
      retireIntentAt: intentAt,
      retireDoneSteps: doneSteps,
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
