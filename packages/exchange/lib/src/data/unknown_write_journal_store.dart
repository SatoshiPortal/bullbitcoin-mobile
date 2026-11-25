import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_environment.dart';
import '../domain/unknown_write_journal.dart';
import 'storage/exchange_database.dart';

/// [UnknownWriteJournal] in the exchange database (`unknown_writes`, schema
/// 2). Plain SQL, so the store does not depend on generated row classes.
final class DriftUnknownWriteJournal implements UnknownWriteJournal {
  final ExchangeDatabase _database;
  final String Function() _newId;

  DriftUnknownWriteJournal(this._database, {String Function()? newId})
    : _newId = newId ?? _randomId;

  @override
  Future<Result<UnknownWrite, UnknownWriteJournalFailure>> record(
    UnknownWriteDraft draft,
  ) async {
    final entry = UnknownWrite(
      id: _newId(),
      kind: draft.kind,
      environment: draft.environment,
      sessionEpoch: draft.sessionEpoch,
      orderId: draft.orderId,
      request: Map.unmodifiable(draft.request),
      recordedAt: clock.now().toUtc(),
    );
    try {
      await _database.customInsert(
        'INSERT INTO unknown_writes (id, kind, environment, session_epoch, '
        'order_id, request, recorded_at_ms) VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(entry.id),
          Variable<String>(entry.kind.wire),
          Variable<String>(entry.environment.name),
          Variable<int>(entry.sessionEpoch),
          Variable<String>(entry.orderId),
          Variable<String>(jsonEncode(entry.request)),
          Variable<int>(entry.recordedAt.millisecondsSinceEpoch),
        ],
      );
      return Ok(entry);
    } on Exception catch (e) {
      // SQL errors can quote the request: keep only the type.
      return Err(UnknownWriteJournalFailure('record: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<List<UnknownWrite>, UnknownWriteJournalFailure>> open(
    ExchangeEnvironment environment,
  ) async {
    try {
      final rows = await _database
          .customSelect(
            'SELECT id, kind, session_epoch, order_id, request, recorded_at_ms '
            'FROM unknown_writes WHERE environment = ? AND settled_at_ms IS NULL '
            'ORDER BY recorded_at_ms, id',
            variables: [Variable<String>(environment.name)],
          )
          .get();
      final entries = <UnknownWrite>[];
      for (final row in rows) {
        final kind = UnknownWriteKind.fromWire(row.read<String>('kind'));
        final request = jsonDecode(row.read<String>('request'));
        if (kind == null || request is! Map<String, dynamic>) {
          return const Err(UnknownWriteJournalFailure('unreadable entry'));
        }
        entries.add(
          UnknownWrite(
            id: row.read<String>('id'),
            kind: kind,
            environment: environment,
            sessionEpoch: row.readNullable<int>('session_epoch'),
            orderId: row.readNullable<String>('order_id'),
            request: {
              for (final MapEntry(:key, :value) in request.entries)
                key: '$value',
            },
            recordedAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('recorded_at_ms'),
              isUtc: true,
            ),
          ),
        );
      }
      return Ok(entries);
    } on Exception catch (e) {
      return Err(UnknownWriteJournalFailure('open: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<void, UnknownWriteJournalFailure>> settle(
    String id,
    UnknownWriteSettlement settlement,
  ) async {
    try {
      await _database.customUpdate(
        'UPDATE unknown_writes SET settled_at_ms = ?, settlement = ? '
        'WHERE id = ? AND settled_at_ms IS NULL',
        variables: [
          Variable<int>(clock.now().millisecondsSinceEpoch),
          Variable<String>(settlement.wire),
          Variable<String>(id),
        ],
        updateKind: UpdateKind.update,
      );
      return const Ok(null);
    } on Exception catch (e) {
      return Err(UnknownWriteJournalFailure('settle: ${e.runtimeType}'));
    }
  }
}

/// [UnknownWriteJournal] in memory, for tests and for hosts that have not
/// opened the exchange database. Not persistent.
final class InMemoryUnknownWriteJournal implements UnknownWriteJournal {
  final _entries = <String, (UnknownWrite, UnknownWriteSettlement?)>{};
  int _next = 0;

  /// Every entry recorded so far with its settlement, oldest first.
  List<(UnknownWrite, UnknownWriteSettlement?)> get entries =>
      List.unmodifiable(_entries.values);

  @override
  Future<Result<UnknownWrite, UnknownWriteJournalFailure>> record(
    UnknownWriteDraft draft,
  ) async {
    final entry = UnknownWrite(
      id: 'entry-${_next++}',
      kind: draft.kind,
      environment: draft.environment,
      sessionEpoch: draft.sessionEpoch,
      orderId: draft.orderId,
      request: Map.unmodifiable(draft.request),
      recordedAt: clock.now().toUtc(),
    );
    _entries[entry.id] = (entry, null);
    return Ok(entry);
  }

  @override
  Future<Result<List<UnknownWrite>, UnknownWriteJournalFailure>> open(
    ExchangeEnvironment environment,
  ) async => Ok([
    for (final (entry, settlement) in _entries.values)
      if (settlement == null && entry.environment == environment) entry,
  ]);

  @override
  Future<Result<void, UnknownWriteJournalFailure>> settle(
    String id,
    UnknownWriteSettlement settlement,
  ) async {
    if (_entries[id] case (final entry, null)) {
      _entries[id] = (entry, settlement);
    }
    return const Ok(null);
  }
}

String _randomId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
