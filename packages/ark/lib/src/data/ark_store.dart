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
  void commitObservation(
    ArkSnapshot snapshot, {
    Map<String, Object?>? syncFailures,
    List<ArkOperation> settledOperations = const [],
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final settled in settledOperations) {
        final previous = operation(settled.id);
        if (previous == null) throw const FormatException('Missing operation');
        saveOperation(settled, previous.binding);
      }
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
                  terminalMovementRetires(m, old.id, snapshot.vtxos) ||
                  (m.status == ArkMovementStatus.successful &&
                      m.inputVtxoIds.contains(old.id) &&
                      (m.kind == ArkMovementKind.payment ||
                          (m.kind == ArkMovementKind.renewal &&
                              m.outputVtxoIds.isNotEmpty)) &&
                      m.outputVtxoIds.every(
                        (id) => snapshot.vtxos.any(
                          (v) =>
                              v.id == id &&
                              v.eligibleAt(snapshot.tipHeight ?? 0),
                        ),
                      )),
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
      if (syncFailures != null) put('sync-stage-failures', syncFailures);
      saveSnapshot(snapshot);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void saveQuote(ArkQuote value, {bool claimAuthorityRequired = false}) =>
      _db.execute('INSERT INTO quotes VALUES(?,?)', [
        value.id,
        jsonEncode({
          ...quoteToJson(value),
          if (claimAuthorityRequired) 'claimAuthorityRequired': true,
        }),
      ]);
  ArkQuote? quote(String id) {
    final rows = _db.select('SELECT value FROM quotes WHERE id=?', [id]);
    return rows.isEmpty
        ? null
        : quoteFromJson(decodeMap(rows.single['value'] as String));
  }

  /// The smoke wallet admits only one manually funded reserve. Reopening or
  /// repricing the same exit cannot substitute a different payment.
  bool bindInitialExitReserve({
    required ArkQuote quote,
    required String reserveAddress,
    required ArkExitReserveFunding funding,
  }) {
    final destination = quote.destination;
    if (quote.kind != ArkOperationKind.emergencyExit ||
        quote.account.network != BitcoinNetwork.regtest ||
        destination == null ||
        reserveAddress.isEmpty ||
        quote.selectedIds.isEmpty ||
        funding.amount.value < quote.fee.value) {
      throw const FormatException('Invalid exit reserve binding');
    }
    const key = 'initial-exit-reserve';
    final ids = quote.selectedIds.toList()..sort();
    final binding = <String, Object?>{
      'account': quote.account.canonical,
      'source': quote.chainSource.toString(),
      'destination': destination,
      'reserve': reserveAddress,
      'ids': ids,
      'txid': funding.txid,
      'amount': funding.amount.toString(),
    };
    _db.execute('BEGIN IMMEDIATE');
    try {
      final existing = get(key);
      if (existing != null && jsonEncode(existing) != jsonEncode(binding)) {
        _db.execute('ROLLBACK');
        return false;
      }
      if (existing == null) put(key, binding);
      _db.execute('COMMIT');
      return true;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Returns only the funding bound to this exact exit scope and destination.
  ({ArkExitReserveFunding funding, String address})? initialExitReserve(
    ArkQuote quote,
  ) {
    final binding = get('initial-exit-reserve');
    final destination = quote.destination;
    final ids = quote.selectedIds.toList()..sort();
    if (binding == null ||
        quote.kind != ArkOperationKind.emergencyExit ||
        quote.account.network != BitcoinNetwork.regtest ||
        destination == null ||
        binding['account'] != quote.account.canonical ||
        binding['source'] != quote.chainSource.toString() ||
        binding['destination'] != destination ||
        jsonEncode(binding['ids']) != jsonEncode(ids)) {
      return null;
    }
    final address = binding['reserve'];
    final txid = binding['txid'];
    final amount = binding['amount'];
    if (address is! String || txid is! String || amount is! String) {
      throw const FormatException('Invalid stored reserve funding');
    }
    final amountSats = Sats.tryParseBitcoin(amount, BitcoinUnit.sats);
    if (amountSats == null || amountSats.value == BigInt.zero) {
      throw const FormatException('Invalid stored reserve funding amount');
    }
    final funding = ArkExitReserveFunding(txid: txid, amount: amountSats);
    if (funding.amount.value < quote.fee.value) return null;
    return (funding: funding, address: address);
  }

  /// Commits a signed child and debits the absolute budget before delivery.
  /// An ambiguous delivery keeps its debit; an identical retry is free.
  bool admitExitCpfp({
    required String exitOperationId,
    required String vtxoId,
    required String parentTxid,
    required String childTxid,
    required String raw,
    required Sats fee,
    required List<String> reserveInputs,
  }) {
    final txid = RegExp(r'^[0-9a-f]{64}$');
    final hex = RegExp(r'^(?:[0-9a-f]{2})+$');
    final outpoint = RegExp(r'^[0-9a-f]{64}:(?:0|[1-9][0-9]{0,9})$');
    if (!txid.hasMatch(parentTxid) ||
        !txid.hasMatch(childTxid) ||
        parentTxid == childTxid ||
        raw.length > 200000 ||
        !hex.hasMatch(raw) ||
        fee.value <= BigInt.zero ||
        reserveInputs.isEmpty ||
        reserveInputs.toSet().length != reserveInputs.length ||
        reserveInputs.any((input) => !outpoint.hasMatch(input))) {
      throw const FormatException('Invalid exit child evidence');
    }
    final inputs = reserveInputs.toList()..sort();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final admitted = operation(exitOperationId);
      final binding = admitted?.binding;
      final authorization = binding == null ? null : quote(binding);
      final start = get('initial-exit-start');
      if (start?['operation'] != exitOperationId ||
          start?['quote'] != binding ||
          admitted == null ||
          admitted.operation.kind != ArkOperationKind.emergencyExit ||
          !admitted.operation.actualIds.contains(vtxoId) ||
          authorization == null ||
          authorization.account.network != BitcoinNetwork.regtest ||
          !authorization.selectedIds.contains(vtxoId) ||
          !(admitted.operation.status == ArkOperationStatus.pending ||
              admitted.operation.status == ArkOperationStatus.succeeded)) {
        _db.execute('ROLLBACK');
        return false;
      }
      const key = 'initial-exit-cpfp';
      final journal = get(key) ?? {};
      if (journal.isNotEmpty && journal['operation'] != exitOperationId) {
        _db.execute('ROLLBACK');
        return false;
      }
      final entries = (journal['children'] as Map<String, Object?>?) ?? {};
      final evidence = {
        'vtxo': vtxoId,
        'txid': childTxid,
        'raw': raw,
        'fee': fee.value.toString(),
        'inputs': inputs,
      };
      final existing = entries[parentTxid];
      if (existing != null) {
        _db.execute('COMMIT');
        return jsonEncode(existing) == jsonEncode(evidence);
      }
      var spent = BigInt.zero;
      for (final entry in entries.values.cast<Map<String, Object?>>()) {
        spent += BigInt.parse(entry['fee'] as String);
        if (entry['txid'] == childTxid ||
            (entry['inputs'] as List<Object?>).any(inputs.contains)) {
          _db.execute('ROLLBACK');
          return false;
        }
      }
      if (spent + fee.value > authorization.fee.value) {
        _db.execute('ROLLBACK');
        return false;
      }
      put(key, {
        'operation': exitOperationId,
        'children': {...entries, parentTxid: evidence},
      });
      _db.execute('COMMIT');
      return true;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Progress can only reuse the bytes previously charged to this exit.
  ({String txid, String raw, Sats fee})? exitCpfpEvidence({
    required String exitOperationId,
    required String parentTxid,
  }) {
    final evidence = _exitCpfpChildren(exitOperationId)[parentTxid];
    if (evidence == null) return null;
    if (evidence case {
      'txid': final String txid,
      'raw': final String raw,
      'fee': final String sats,
    }) {
      final fee = Sats.tryParseBitcoin(sats, BitcoinUnit.sats);
      if (fee != null && fee.value > BigInt.zero) {
        return (txid: txid, raw: raw, fee: fee);
      }
    }
    throw const FormatException('Invalid stored exit child evidence');
  }

  /// Journal order is delivery order, so a reserve parent is imported before
  /// any later child that spends its change.
  List<({String txid, String raw, Sats fee})> exitCpfpHistory(
    String exitOperationId,
  ) => [
    for (final parent in _exitCpfpChildren(exitOperationId).keys)
      ?exitCpfpEvidence(exitOperationId: exitOperationId, parentTxid: parent),
  ];

  Map<String, Object?> _exitCpfpChildren(String exitOperationId) {
    final start = get('initial-exit-start');
    final journal = get('initial-exit-cpfp');
    if (start?['operation'] != exitOperationId ||
        journal?['operation'] != exitOperationId) {
      return const {};
    }
    final children = journal?['children'];
    if (children is! Map<String, Object?>) {
      throw const FormatException('Invalid stored exit child journal');
    }
    return children;
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
    if (existing?.evidence?['raw'] != null &&
        evidence != null &&
        jsonEncode(existing?.evidence) != jsonEncode(evidence)) {
      throw const FormatException(
        'Committed signed claim evidence is immutable',
      );
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

  /// Mutable delivery metadata stays separate from immutable signed evidence.
  void beginClaimDelivery(ArkOperation operation, String binding, DateTime at) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final key = 'claim-delivery:${operation.id}';
      final count = get(key)?['count'] ?? 0;
      if (count is! int || count < 0) {
        throw const FormatException('Invalid delivery count');
      }
      saveOperation(operation, binding);
      put(key, {
        'operationId': operation.id,
        'txid': operation.nativeReference,
        'source': operation.chainSource.toString(),
        'count': count + 1,
        'at': at.toIso8601String(),
      });
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Native execution is allowed only after both records commit together.
  bool admitExit(
    ArkQuote authorization,
    ArkOperation admitted, {
    bool requireInitialReserve = false,
  }) {
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
      if (requireInitialReserve &&
          (initialExitReserve(authorization) == null ||
              get('initial-exit-start') != null)) {
        _db.execute('ROLLBACK');
        return false;
      }
      if (!createClaimAuthority(
        admitted.id,
        authorization.selectedIds,
        destination,
        maximum,
      )) {
        _db.execute('ROLLBACK');
        return false;
      }
      if (requireInitialReserve) {
        put('initial-exit-start', {
          'operation': admitted.id,
          'quote': authorization.id,
        });
      }
      saveOperation(admitted, authorization.id);
      _db.execute('COMMIT');
      return true;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// A reviewed claim may change only its selected ids' remaining authority.
  /// The plan is inert until authority and admitted operation commit together.
  String? admitClaim(ArkQuote reviewed, ArkOperation admitted) {
    final destination = reviewed.destination;
    final maximum = reviewed.maxClaimFee;
    final stored = quote(reviewed.id);
    if (destination == null ||
        maximum == null ||
        maximum.value <= BigInt.zero ||
        stored == null ||
        reviewed.kind != ArkOperationKind.claim ||
        admitted.kind != reviewed.kind ||
        admitted.status != ArkOperationStatus.admitted ||
        admitted.chainSource != reviewed.chainSource ||
        admitted.configGeneration != reviewed.configGeneration ||
        jsonEncode(admitted.actualIds) != jsonEncode(reviewed.selectedIds) ||
        jsonEncode(quoteToJson(stored)) != jsonEncode(quoteToJson(reviewed))) {
      throw const FormatException('Invalid claim authorization binding');
    }
    _db.execute('BEGIN IMMEDIATE');
    try {
      final ids = reviewed.selectedIds;
      if (operations.any(
        (op) =>
            op.kind == ArkOperationKind.claim &&
            op.actualIds.any(ids.contains) &&
            (op.status == ArkOperationStatus.admitted ||
                op.status == ArkOperationStatus.pending ||
                op.status == ArkOperationStatus.outcomeUnknown ||
                op.status == ArkOperationStatus.conflicted ||
                operation(op.id)?.evidence?['raw'] != null),
      )) {
        _db.execute('ROLLBACK');
        return null;
      }
      var authority = claimAuthority(ids, destination, maximum);
      if (authority == null) {
        final row = _db.select('SELECT value FROM quotes WHERE id=?', [
          reviewed.id,
        ]).single;
        if (decodeMap(row['value'] as String)['claimAuthorityRequired'] !=
            true) {
          _db.execute('ROLLBACK');
          return null;
        }
        for (final allocation in _db.select('SELECT * FROM claim_allowances')) {
          final remaining = strings(
            jsonDecode(allocation['remaining_ids'] as String),
          );
          if (remaining.any(ids.contains)) {
            _db.execute(
              'UPDATE claim_allowances SET remaining_ids=? WHERE authority=?',
              [
                jsonEncode(remaining.where((id) => !ids.contains(id)).toList()),
                allocation['authority'],
              ],
            );
          }
        }
        authority = admitted.id;
        if (!createClaimAuthority(authority, ids, destination, maximum)) {
          throw const FormatException('Claim authority overlap');
        }
      }
      saveOperation(admitted, reviewed.id);
      _db.execute('COMMIT');
      return authority;
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

  /// What each started exit may still claim: its destination, the fee
  /// ceiling left and the VTXOs not yet claimed.
  List<({String destination, Sats remainingFee, List<String> remainingIds})>
  claimAllowances() => [
    for (final row in _db.select('SELECT * FROM claim_allowances'))
      (
        destination: row['destination'] as String,
        remainingFee: Sats(BigInt.parse(row['remaining_fee'] as String)),
        remainingIds: strings(jsonDecode(row['remaining_ids'] as String)),
      ),
  ];

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
