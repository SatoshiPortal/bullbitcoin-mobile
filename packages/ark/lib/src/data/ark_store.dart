import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../ark.dart';
import 'ark_codec.dart';

/// Account-private journal. Never stores child material. Schema zero is allowed
/// only for explicit foreground creation, never inferred from a missing file.
final class ArkStore {
  final Database _db;
  ArkStore._(this._db);
  static String accountPath(String root, ArkAccountId id) =>
      '$root/${sha256.convert(utf8.encode(id.canonical))}';

  static ArkStore open(
    String path, {
    required bool create,
    bool readOnly = false,
  }) {
    if (readOnly && create) {
      throw const FormatException('Read-only creation refused');
    }
    if (!create && !File(path).existsSync()) {
      throw const FileSystemException('Ark metadata missing');
    }
    final db = sqlite3.open(
      path,
      mode: readOnly
          ? OpenMode.readOnly
          : create
          ? OpenMode.readWriteCreate
          : OpenMode.readWrite,
    );
    try {
      db.execute('PRAGMA busy_timeout=0');
      if (!readOnly) db.execute('PRAGMA synchronous=FULL');
      final version = db.select('PRAGMA user_version').single.values.single;
      if (version == 0 && create) {
        if (db
            .select("SELECT name FROM sqlite_master WHERE type='table'")
            .isNotEmpty) {
          throw const FormatException('Foreign Ark metadata');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE state(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          db.execute(
            'CREATE TABLE operations(id TEXT PRIMARY KEY, binding TEXT NOT NULL, value TEXT NOT NULL, evidence TEXT)',
          );
          db.execute(
            'CREATE TABLE quotes(id TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          db.execute(
            'CREATE TABLE claim_allowances(authority TEXT PRIMARY KEY, remaining_fee TEXT NOT NULL, remaining_ids TEXT NOT NULL, destination TEXT NOT NULL)',
          );
          db.execute('PRAGMA user_version=1');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } else if (version != 1) {
        throw const FormatException('Incompatible Ark metadata');
      }
      return ArkStore._(db);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  Map<String, Object?>? get(String key) {
    final rows = _db.select('SELECT value FROM state WHERE key=?', [key]);
    return rows.isEmpty ? null : decodeMap(rows.single['value'] as String);
  }

  void put(String key, Map<String, Object?> value) => _db.execute(
    'INSERT INTO state VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, jsonEncode(value)],
  );
  ArkSnapshot? get snapshot => switch (get('snapshot')) {
    final value? => snapshotFromJson(value),
    null => null,
  };
  void saveSnapshot(ArkSnapshot value) =>
      put('snapshot', snapshotToJson(value));

  /// One durable observation: positive-but-partial ids cannot erase themselves,
  /// and a failed snapshot commit cannot advance retirement evidence.
  void commitObservation(ArkSnapshot snapshot) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final prior = get('inventory-obligations') ?? get('complete-inventory');
      final known = prior == null
          ? const <ArkVtxo>[]
          : maps(prior['vtxos']).map(vtxoFromJson).toList();
      final retained = snapshot.vtxos
          .where((v) => v.state != ArkVtxoState.spent)
          .toList();
      final retainedIds = retained.map((v) => v.id).toSet();
      final retirement = get('inventory-retirements') ?? <String, Object?>{};
      for (final old in known.where(
        (v) => v.state != ArkVtxoState.spent && !retainedIds.contains(v.id),
      )) {
        final movement = snapshot.movements
            .where(
              (m) =>
                  m.status == ArkMovementStatus.successful &&
                  m.inputVtxoIds.contains(old.id) &&
                  (m.kind == ArkMovementKind.payment ||
                      (m.kind == ArkMovementKind.renewal &&
                          m.outputVtxoIds.isNotEmpty)) &&
                  m.outputVtxoIds.every(
                    (id) => snapshot.vtxos.any(
                      (v) =>
                          v.id == id && v.eligibleAt(snapshot.tipHeight ?? 0),
                    ),
                  ),
            )
            .firstOrNull;
        final exit = snapshot.exitDetails
            .where(
              (e) =>
                  e.id == old.id &&
                  e.status == ArkExitStatus.claimed &&
                  e.claimTxid != null,
            )
            .firstOrNull;
        if (movement == null && exit == null) {
          throw const FormatException('Missing inventory retirement evidence');
        }
        retirement[old.id] = {
          'movement': movement?.id,
          'outputs': movement?.outputVtxoIds,
          'claimTxid': exit?.claimTxid,
          'tip': snapshot.tipHeight,
          'revision': snapshot.revision,
        };
      }
      put('inventory-obligations', {
        'vtxos': retained.map(vtxoToJson).toList(),
      });
      put('inventory-retirements', retirement);
      if (snapshot.vtxoInventoryComplete && !snapshot.stale) {
        put('complete-inventory', {
          'vtxos': snapshot.vtxos.map(vtxoToJson).toList(),
        });
      }
      saveSnapshot(snapshot);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void saveQuote(ArkQuote value) => _db.execute(
    'INSERT INTO quotes VALUES(?,?)',
    [value.id, jsonEncode(quoteToJson(value))],
  );
  ArkQuote? quote(String id) {
    final rows = _db.select('SELECT value FROM quotes WHERE id=?', [id]);
    return rows.isEmpty
        ? null
        : quoteFromJson(decodeMap(rows.single['value'] as String));
  }

  ({ArkOperation operation, String binding, Map<String, Object?>? evidence})?
  operation(String id) {
    final rows = _db.select('SELECT * FROM operations WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    final row = rows.single;
    final evidence = row['evidence'] as String?;
    return (
      operation: operationFromJson(decodeMap(row['value'] as String)),
      binding: row['binding'] as String,
      evidence: evidence == null ? null : decodeMap(evidence),
    );
  }

  List<ArkOperation> get operations => _db
      .select('SELECT value FROM operations ORDER BY rowid')
      .map((row) => operationFromJson(decodeMap(row['value'] as String)))
      .toList();
  void saveOperation(
    ArkOperation value,
    String binding, {
    Map<String, Object?>? evidence,
  }) {
    final existing = operation(value.id);
    if (existing != null && existing.binding != binding) {
      throw const FormatException('Operation binding mismatch');
    }
    _db.execute(
      'INSERT INTO operations VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET value=excluded.value,evidence=COALESCE(excluded.evidence,operations.evidence)',
      [
        value.id,
        binding,
        jsonEncode(operationToJson(value)),
        evidence == null ? null : jsonEncode(evidence),
      ],
    );
    final previous = get('snapshot');
    if (previous != null) {
      previous['stale'] = true;
      previous['operations'] = operations.map(operationToJson).toList();
      put('snapshot', previous);
    }
  }

  /// Native execution is allowed only after both records commit together.
  bool admitExit(ArkQuote authorization, ArkOperation admitted) {
    final destination = authorization.destination;
    final maximum = authorization.maxClaimFee;
    final stored = quote(authorization.id);
    if (destination == null ||
        maximum == null ||
        stored == null ||
        authorization.kind != ArkOperationKind.emergencyExit ||
        admitted.kind != authorization.kind ||
        admitted.status != ArkOperationStatus.admitted ||
        admitted.chainSource != authorization.chainSource ||
        admitted.configGeneration != authorization.configGeneration ||
        jsonEncode(admitted.actualIds) !=
            jsonEncode(authorization.selectedIds) ||
        jsonEncode(quoteToJson(stored)) !=
            jsonEncode(quoteToJson(authorization))) {
      throw const FormatException('Invalid exit authorization binding');
    }
    _db.execute('BEGIN IMMEDIATE');
    try {
      if (!createClaimAuthority(
        admitted.id,
        authorization.selectedIds,
        destination,
        maximum,
      )) {
        _db.execute('ROLLBACK');
        return false;
      }
      saveOperation(admitted, authorization.id);
      _db.execute('COMMIT');
      return true;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  bool createClaimAuthority(
    String id,
    List<String> ids,
    String destination,
    Sats maximum,
  ) {
    final existing = _db.select('SELECT remaining_ids FROM claim_allowances');
    if (existing.any(
      (row) =>
          strings(jsonDecode(row['remaining_ids'] as String)).any(ids.contains),
    )) {
      return false;
    }
    _db.execute('INSERT INTO claim_allowances VALUES(?,?,?,?)', [
      id,
      maximum.toString(),
      jsonEncode(ids),
      destination,
    ]);
    return true;
  }

  String? claimAuthority(List<String> ids, String destination, Sats maximum) {
    final rows = _db.select(
      'SELECT * FROM claim_allowances WHERE destination=?',
      [destination],
    );
    for (final row in rows) {
      final remaining = strings(jsonDecode(row['remaining_ids'] as String))
          .toSet();
      if (ids.every(remaining.contains) &&
          maximum.value <= BigInt.parse(row['remaining_fee'] as String)) {
        return row['authority'] as String;
      }
    }
    return null;
  }

  void commitClaim(
    String authority,
    ArkOperation operation,
    String binding,
    Set<String> actual,
    Sats fee,
    Map<String, Object?> evidence,
  ) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final row = _db.select(
        'SELECT * FROM claim_allowances WHERE authority=?',
        [authority],
      ).single;
      final remaining = strings(jsonDecode(row['remaining_ids'] as String))
          .toSet();
      final available = BigInt.parse(row['remaining_fee'] as String);
      if (actual.isEmpty ||
          !actual.every(remaining.contains) ||
          fee.value > available) {
        throw const FormatException('Claim allowance mismatch');
      }
      remaining.removeAll(actual);
      _db.execute(
        'UPDATE claim_allowances SET remaining_fee=?,remaining_ids=? WHERE authority=?',
        [
          (available - fee.value).toString(),
          jsonEncode(remaining.toList()),
          authority,
        ],
      );
      saveOperation(operation, binding, evidence: evidence);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _db.close();
}
