import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../ark.dart';
import 'ark_exit_archive.dart';

/// Dedicated evidence DB. Call only under the account writer; never opens Bark.
/// Methods contain no asynchronous suspension: close cannot overtake admitted SQL.
final class SqliteExitArchive implements ArkExitArchive {
  final Database _db;
  final ArkExitArchiveIdentity identity;
  bool _closed = false;
  SqliteExitArchive._(this._db, this.identity);
  static const _tables = [
    'archive_meta',
    'proof_versions',
    'vtxo_heads',
    'claim_material',
    'capture_intents',
  ];

  static Result<SqliteExitArchive, ArkWalletFailure> open(
    String path,
    ArkAccountId account, {
    required bool create,
    String nativeVersion = '0.27.0+bark-0.8.1',
    String derivationProfile = 'bip85-11811/bark-350h-0h',
  }) {
    Database? opened;
    try {
      final exists = File(path).existsSync();
      if (!create && !exists) return const Err(ArkStorageFailure());
      final db = opened = sqlite3.open(
        path,
        mode: create ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
      db.execute('PRAGMA busy_timeout=0');
      db.execute('PRAGMA synchronous=FULL');
      final version = db.select('PRAGMA user_version').single.values.single;
      if (!exists && create && version == 0) {
        _transaction(db, () {
          for (final table in _tables) {
            db.execute(
              'CREATE TABLE $table (id TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
            );
          }
          final id = List.generate(16, (_) => Random.secure().nextInt(256));
          _put(db, 'archive_meta', 'state', {
            'archive': _hex(id),
            'account': account.canonical,
            'native': nativeVersion,
            'profile': derivationProfile,
            'sequence': 0,
            'ack': 0,
            'issues': [ArkExitCaptureIssue.nativeCoverageUnavailable.name],
          });
          db.execute('PRAGMA user_version=1');
        });
      } else if (version != 1) {
        throw const FormatException('Incompatible archive');
      }
      _checkSchema(db);
      final meta = _get(db, 'archive_meta', 'state');
      if (meta == null ||
          meta['account'] != account.canonical ||
          meta['native'] != nativeVersion ||
          meta['profile'] != derivationProfile ||
          db.select('SELECT id FROM archive_meta').length != 1) {
        throw const FormatException('Archive identity mismatch');
      }
      final archive = SqliteExitArchive._(
        db,
        ArkExitArchiveIdentity(
          account,
          nativeVersion,
          derivationProfile,
          archiveId: _string(meta, 'archive'),
        ),
      );
      archive._view(); // Refuse malformed initialized records without reset.
      return Ok(archive);
    } on FormatException {
      opened?.close();
      return const Err(ArkStorageFailure(ArkFailureReason.storeIncompatible));
    } on SqliteException {
      opened?.close();
      return const Err(ArkStorageFailure());
    } on FileSystemException {
      opened?.close();
      return const Err(ArkStorageFailure());
    }
  }

  Result<T, ArkWalletFailure> _run<T>(T Function() action) {
    if (_closed) return const Err(ArkStorageFailure(ArkFailureReason.closed));
    try {
      return Ok(action());
    } on FormatException {
      return const Err(ArkValidationFailure());
    } on SqliteException {
      return const Err(ArkStorageFailure());
    }
  }

  @override
  Future<Result<ArkExitCaptureIntent, ArkWalletFailure>> begin(
    ArkExitCaptureStage stage, {
    String? operationId,
    int? sourceRevision,
    List<String> knownInputs = const [],
  }) async => _run(
    () => _transaction(_db, () {
      _readState();
      _validateIntentFields(sourceRevision, knownInputs);
      final meta = _meta;
      final next = _int(meta, 'sequence') + 1;
      final intent = ArkExitCaptureIntent(
        identity,
        next,
        stage,
        operationId: operationId,
        sourceRevision: sourceRevision,
        knownInputs: knownInputs,
      );
      _put(_db, 'capture_intents', '$next', _intentJson(intent));
      meta['sequence'] = next;
      _put(_db, 'archive_meta', 'state', meta);
      return intent;
    }),
  );

  Map<String, Object?> get _meta =>
      _get(_db, 'archive_meta', 'state') ?? (throw const FormatException());
  void _checkIntent(ArkExitCaptureIntent intent) {
    final stored = _get(_db, 'capture_intents', '${intent.sequence}');
    if (stored == null ||
        !identity.matches(intent.archive) ||
        !_intent(stored).matches(intent)) {
      throw const FormatException();
    }
  }

  @override
  Future<Result<void, ArkWalletFailure>> commit(
    ArkExitCaptureIntent intent,
    ArkExitCaptureBatch batch,
  ) async => _run(
    () => _transaction(_db, () {
      _readState();
      _checkIntent(intent);
      final meta = _meta;
      final issues = _strings(meta, 'issues').toSet()
        ..addAll(batch.issues.map((i) => i.name));
      final through = batch.coveredThrough;
      if (through != null &&
          (through < _int(meta, 'ack') ||
              through < 0 ||
              through > intent.sequence ||
              through > _int(meta, 'sequence'))) {
        throw const FormatException();
      }
      for (final proof in batch.proofs) {
        final fresh = _proofJson(proof);
        _validateProof(fresh);
        final key = jsonEncode([proof.vtxoId, proof.proofHash.toLowerCase()]);
        final old = _get(_db, 'proof_versions', key);
        if (old != null) {
          for (final field in ['id', 'hash', 'full', 'encoding']) {
            if (old[field] != fresh[field]) throw const FormatException();
          }
          for (final field in ['server', 'checkpoint']) {
            _retain(old, fresh, field);
          }
          final previous = _string(old, 'witness');
          final current = _string(fresh, 'witness');
          if (current == ArkExitWitnessState.unknown.name) {
            fresh['witness'] = previous;
          } else if (previous != ArkExitWitnessState.unknown.name &&
              previous != current) {
            throw const FormatException();
          }
        }
        _put(_db, 'proof_versions', key, fresh);
      }
      for (final material in batch.material) {
        if (material.indexVerified &&
            (material.keyIndex == null || material.publicKey == null)) {
          throw const FormatException();
        }
        final fresh = _materialJson(material);
        final old = _get(_db, 'claim_material', material.id);
        if (old != null) {
          for (final field in ['vtxo', 'key', 'index', 'hash', 'preimage']) {
            _retain(old, fresh, field);
          }
          fresh['verified'] =
              old['verified'] == true || fresh['verified'] == true;
        }
        _validateMaterial(fresh);
        _put(_db, 'claim_material', material.id, fresh);
      }
      for (final head in batch.heads) {
        _head(_headJson(head));
        final key = jsonEncode([head.vtxoId, head.proofHash.toLowerCase()]);
        if (_get(_db, 'proof_versions', key) == null) {
          throw const FormatException();
        }
        _put(_db, 'vtxo_heads', head.vtxoId, _headJson(head));
      }
      // No evidence-specific issue resolution exists at this pin. Never clear gaps.
      if (through != null) throw const FormatException('Coverage unavailable');
      meta['issues'] = issues.toList()..sort();
      _put(
        _db,
        'archive_meta',
        'state',
        meta,
      ); // Last logical write: transaction test cutpoint.
    }),
  );

  @override
  Future<Result<void, ArkWalletFailure>> failed(
    ArkExitCaptureIntent intent,
  ) async => _run(
    () => _transaction(_db, () {
      _readState();
      _checkIntent(intent);
      final meta = _meta;
      meta['issues'] = (_strings(
        meta,
        'issues',
      ).toSet()..add(ArkExitCaptureIssue.captureFailed.name)).toList();
      _put(_db, 'archive_meta', 'state', meta);
    }),
  );

  @override
  Future<Result<ArkExitArchiveView, ArkWalletFailure>> read() async =>
      _run(_view);
  ArkExitArchiveView _view() => _transaction(_db, _readState);

  // Caller already owns BEGIN IMMEDIATE. Read and write admission share this
  // validation; no malformed row can be repaired by a later merge/admission.
  ArkExitArchiveView _readState() {
    _checkSchema(_db);
    final metadata = _all(_db, 'archive_meta');
    if (metadata.length != 1) throw const FormatException();
    final meta = metadata.single;
    final sequence = _int(meta, 'sequence'), ack = _int(meta, 'ack');
    if (sequence < 0 ||
        ack != 0 ||
        _string(meta, 'archive') != identity.archiveId ||
        meta['account'] != identity.account.canonical ||
        meta['native'] != identity.nativeVersion ||
        meta['profile'] != identity.derivationProfile) {
      throw const FormatException();
    }
    final proofs = _all(_db, 'proof_versions').map((m) {
      _validateProof(m);
      return _proof(m);
    }).toList();
    final material = _all(_db, 'claim_material').map((m) {
      _validateMaterial(m);
      return _material(m);
    }).toList();
    final heads = _all(_db, 'vtxo_heads').map(_head).toList();
    final pending = _all(_db, 'capture_intents').map(_intent).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (pending.length != sequence ||
        pending.asMap().entries.any(
          (entry) =>
              !identity.matches(entry.value.archive) ||
              entry.value.sequence != entry.key + 1,
        ) ||
        heads.any(
          (h) => !proofs.any(
            (p) => p.vtxoId == h.vtxoId && p.proofHash == h.proofHash,
          ),
        )) {
      throw const FormatException();
    }
    final issues =
        _strings(
            meta,
            'issues',
          ).map((s) => _enum(ArkExitCaptureIssue.values, s)).toSet()
          ..add(ArkExitCaptureIssue.nativeCoverageUnavailable);
    return ArkExitArchiveView(
      identity: identity,
      sequence: sequence,
      acknowledgedThrough: ack,
      state: pending.isEmpty
          ? ArkExitCaptureState.incomplete
          : ArkExitCaptureState.dirty,
      issues: issues,
      proofs: proofs,
      heads: heads,
      material: material,
      pending: pending,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _db.close();
  }

  ArkExitCaptureIntent _intent(Map<String, Object?> m) {
    final intent = ArkExitCaptureIntent(
      ArkExitArchiveIdentity(
        identity.account,
        _string(m, 'native'),
        _string(m, 'profile'),
        archiveId: _string(m, 'archive'),
      ),
      _int(m, 'sequence'),
      _enum(ArkExitCaptureStage.values, _string(m, 'stage')),
      operationId: _optional<String>(m, 'operation'),
      sourceRevision: _optional<int>(m, 'revision'),
      knownInputs: _strings(m, 'inputs'),
    );
    _validateIntentFields(intent.sourceRevision, intent.knownInputs);
    return intent;
  }
}

T _transaction<T>(Database db, T Function() action) {
  db.execute('BEGIN IMMEDIATE');
  try {
    final value = action();
    db.execute('COMMIT');
    return value;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void _put(
  Database db,
  String table,
  String id,
  Map<String, Object?> value,
) => db.execute(
  'INSERT INTO $table VALUES(?,?) ON CONFLICT(id) DO UPDATE SET value=excluded.value',
  [id, jsonEncode(value)],
);
Map<String, Object?>? _get(Database db, String table, String id) {
  final rows = db.select('SELECT id,value FROM $table WHERE id=?', [id]);
  return rows.isEmpty ? null : _row(table, rows.single);
}

List<Map<String, Object?>> _all(Database db, String table) => db
    .select('SELECT id,value FROM $table ORDER BY id')
    .map((r) => _row(table, r))
    .toList();
Map<String, Object?> _row(String table, Map<String, Object?> row) {
  final value = _decode(row['value']);
  final expected = switch (table) {
    'archive_meta' => 'state',
    'capture_intents' => '${_int(value, 'sequence')}',
    'proof_versions' => jsonEncode([
      _string(value, 'id'),
      _string(value, 'hash'),
    ]),
    'vtxo_heads' || 'claim_material' => _string(value, 'id'),
    _ => throw const FormatException(),
  };
  if (row['id'] != expected) throw const FormatException();
  return value;
}

void _checkSchema(Database db) {
  if (db.select('PRAGMA user_version').single.values.single != 1) {
    throw const FormatException('Incompatible archive');
  }
  for (final table in SqliteExitArchive._tables) {
    final columns = db.select('PRAGMA table_info($table)');
    if (columns.length != 2 ||
        columns[0]['name'] != 'id' ||
        columns[1]['name'] != 'value' ||
        columns[0]['pk'] != 1 ||
        columns.any((c) => c['type'] != 'TEXT' || c['notnull'] != 1)) {
      throw const FormatException('Incompatible archive');
    }
  }
}

void _validateIntentFields(int? revision, List<String> inputs) {
  if ((revision != null && revision < 0) ||
      inputs.toSet().length != inputs.length ||
      inputs.any((id) => id.isEmpty)) {
    throw const FormatException();
  }
}

Map<String, Object?> _decode(Object? value) {
  if (value is! String) throw const FormatException();
  final decoded = jsonDecode(value);
  if (decoded is! Map<String, Object?>) throw const FormatException();
  return decoded;
}

String _string(Map<String, Object?> m, String key) {
  final value = m[key];
  if (value is! String || value.isEmpty) throw const FormatException();
  return value;
}

int _int(Map<String, Object?> m, String key) {
  final value = m[key];
  if (value is! int) throw const FormatException();
  return value;
}

T? _optional<T>(Map<String, Object?> m, String key) {
  final value = m[key];
  if (value != null && value is! T) throw const FormatException();
  return value as T?;
}

List<String> _strings(Map<String, Object?> m, String key) {
  final value = m[key];
  if (value is! List || value.any((v) => v is! String)) {
    throw const FormatException();
  }
  return value.cast<String>();
}

T _enum<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw const FormatException();
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
List<int> _bytes(String value) {
  if (value.isEmpty ||
      value.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const FormatException();
  }
  return [
    for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16),
  ];
}

void _retain(
  Map<String, Object?> old,
  Map<String, Object?> fresh,
  String field,
) {
  if (fresh[field] != null &&
      old[field] != null &&
      fresh[field] != old[field]) {
    throw const FormatException();
  }
  fresh[field] ??= old[field];
}

Map<String, Object?> _intentJson(ArkExitCaptureIntent i) => {
  'archive': i.archive.archiveId,
  'native': i.archive.nativeVersion,
  'profile': i.archive.derivationProfile,
  'sequence': i.sequence,
  'stage': i.stage.name,
  'operation': i.operationId,
  'revision': i.sourceRevision,
  'inputs': i.knownInputs,
};
Map<String, Object?> _proofJson(ArkExitProofVersion p) => {
  'id': p.vtxoId,
  'hash': p.proofHash.toLowerCase(),
  'full': p.fullHex.toLowerCase(),
  'encoding': p.encodingVersion,
  'server': p.serverKey,
  'checkpoint': p.checkpointId,
  'witness': p.witnesses.name,
};
ArkExitProofVersion _proof(Map<String, Object?> m) => ArkExitProofVersion(
  vtxoId: _string(m, 'id'),
  proofHash: _string(m, 'hash'),
  fullHex: _string(m, 'full'),
  encodingVersion: _int(m, 'encoding'),
  serverKey: _optional<String>(m, 'server'),
  checkpointId: _optional<String>(m, 'checkpoint'),
  witnesses: _enum(ArkExitWitnessState.values, _string(m, 'witness')),
);
void _validateProof(Map<String, Object?> m) {
  _string(m, 'id');
  if (_int(m, 'encoding') != 1 ||
      sha256.convert(_bytes(_string(m, 'full'))).toString() !=
          _string(m, 'hash')) {
    throw const FormatException();
  }
  _proof(m);
}

Map<String, Object?> _headJson(ArkExitProofHead h) => {
  'id': h.vtxoId,
  'hash': h.proofHash.toLowerCase(),
  'life': h.life.name,
  'evidence': h.evidenceReference,
};
ArkExitProofHead _head(Map<String, Object?> m) {
  final head = ArkExitProofHead(
    _string(m, 'id'),
    _string(m, 'hash'),
    _enum(ArkExitProofLife.values, _string(m, 'life')),
    evidenceReference: _optional<String>(m, 'evidence'),
  );
  // No supported producer supplies positive native retirement evidence.
  if (head.life == ArkExitProofLife.superseded ||
      head.life == ArkExitProofLife.chainSpent) {
    throw const FormatException();
  }
  return head;
}

Map<String, Object?> _materialJson(ArkExitClaimMaterial m) => {
  'id': m.id,
  'vtxo': m.vtxoId,
  'key': m.publicKey?.toLowerCase(),
  'index': m.keyIndex,
  'verified': m.indexVerified,
  'hash': m.paymentHash?.toLowerCase(),
  'preimage': m.preimage?.toLowerCase(),
};
ArkExitClaimMaterial _material(Map<String, Object?> m) => ArkExitClaimMaterial(
  id: _string(m, 'id'),
  vtxoId: _optional<String>(m, 'vtxo'),
  publicKey: _optional<String>(m, 'key'),
  keyIndex: _optional<int>(m, 'index'),
  indexVerified: m['verified'] == true,
  paymentHash: _optional<String>(m, 'hash'),
  preimage: _optional<String>(m, 'preimage'),
);
void _validateMaterial(Map<String, Object?> m) {
  final value = _material(m);
  if (m['verified'] is! bool ||
      (value.keyIndex != null && (value.keyIndex ?? -1) < 0) ||
      (value.indexVerified &&
          (value.keyIndex == null || value.publicKey == null)) ||
      (value.publicKey == null &&
          value.paymentHash == null &&
          value.vtxoId == null)) {
    throw const FormatException();
  }
  if (value.publicKey case final key?) {
    if (_bytes(key).length != 33 ||
        !(key.startsWith('02') || key.startsWith('03'))) {
      throw const FormatException();
    }
  }
  if (value.paymentHash case final hash?) {
    if (_bytes(hash).length != 32) throw const FormatException();
  }
  if (value.preimage case final secret?) {
    if (_bytes(secret).length != 32 ||
        sha256.convert(_bytes(secret)).toString() != value.paymentHash) {
      throw const FormatException();
    }
  }
}
