import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SeedReferencePort;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

/// Wallet-owned durable source funding. Sync calls reserve under the one spend
/// lease; this store never calls Sync, the freeze authority or a wallet facade.
/// Requested/reserved/signed/unknown operations survive restart and own their
/// exact inputs until a positive confirmed transaction observation settles them.
final class SqliteArkFundingReservations
    implements FundingReservationPort, SeedReferencePort {
  final Database _db;
  bool _closed = false;
  SqliteArkFundingReservations._(this._db);

  /// Ordinary startup, including foreground, is existing-only. Set
  /// initializeNew only when the host has established this is first setup;
  /// it never overrides an initialized marker whose metadata disappeared.
  static Result<SqliteArkFundingReservations, SyncFailure> open(
    String path, {
    required bool foreground,
    bool initializeNew = false,
  }) {
    Database? opened;
    try {
      final databaseExists = File(path).existsSync();
      final marker = File('$path.initialized');
      final markerExists = marker.existsSync();
      if ((markerExists &&
              (!databaseExists ||
                  marker.readAsStringSync() != 'ark-funding:1\n')) ||
          (!markerExists && (!foreground || !initializeNew))) {
        return const Err(SyncStorageFailure());
      }
      final db = sqlite3.open(
        path,
        mode: foreground ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
      opened = db;
      db.execute('PRAGMA busy_timeout=0');
      db.execute('PRAGMA foreign_keys=ON');
      if (db.userVersion == 0 && foreground && initializeNew && !markerExists) {
        if (db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .isNotEmpty) {
          db.close();
          opened = null;
          return const Err(SyncStorageFailure());
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE IF NOT EXISTS ark_funding_operations (operation TEXT PRIMARY KEY,account TEXT NOT NULL,parent TEXT NOT NULL,wallet TEXT NOT NULL,network TEXT NOT NULL,generation INTEGER NOT NULL,revision INTEGER,context TEXT NOT NULL,state TEXT NOT NULL,psbt TEXT,txid TEXT,signed_psbt TEXT)',
          );
          db.execute(
            'CREATE TABLE IF NOT EXISTS ark_funding_inputs (operation TEXT NOT NULL REFERENCES ark_funding_operations(operation),network TEXT NOT NULL,txid TEXT NOT NULL,vout INTEGER NOT NULL,PRIMARY KEY(network,txid,vout))',
          );
          db.userVersion = 1;
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } else if (db.userVersion != 1) {
        db.close();
        opened = null;
        return const Err(SyncStorageFailure());
      }
      if (!markerExists) {
        marker.writeAsStringSync('ark-funding:1\n', flush: true);
      }
      return Ok(SqliteArkFundingReservations._(db));
    } on Exception catch (_) {
      opened?.close();
      return const Err(SyncStorageFailure());
    }
  }

  /// Journal before prepareFunding. Retrying must retain all public recovery
  /// metadata, source generation and identity. No reservation is released on Err.
  @useResult
  Future<Result<void, SyncFailure>> begin({
    required String operationId,
    required String accountIdentity,
    required Fingerprint sourceParent,
    required WalletKey key,
    required int generation,
    required String context,
  }) async {
    if (_closed) return const Err(SyncClosedFailure());
    final network = key.network;
    if (operationId.isEmpty ||
        operationId.length > 512 ||
        accountIdentity.isEmpty ||
        network is! BitcoinNetwork ||
        generation < 0 ||
        context.isEmpty ||
        utf8.encode(context).length > 4096) {
      return const Err(SyncSpendRefusedFailure());
    }
    var transaction = false;
    try {
      _db.execute('BEGIN IMMEDIATE');
      transaction = true;
      final old = _db.select(
        'SELECT * FROM ark_funding_operations WHERE operation=?',
        [operationId],
      );
      if (old.isNotEmpty) {
        final row = old.single;
        final same =
            row['account'] == accountIdentity &&
            row['parent'] == sourceParent.hex &&
            row['wallet'] == key.id &&
            row['network'] == network.name &&
            row['generation'] == generation &&
            row['context'] == context;
        _db.execute('ROLLBACK');
        transaction = false;
        return same ? const Ok(null) : const Err(SyncSpendRefusedFailure());
      }
      _db.execute(
        'INSERT INTO ark_funding_operations(operation,account,parent,wallet,network,generation,context,state) VALUES(?,?,?,?,?,?,?,?)',
        [
          operationId,
          accountIdentity,
          sourceParent.hex,
          key.id,
          network.name,
          generation,
          context,
          'requested',
        ],
      );
      _db.execute('COMMIT');
      transaction = false;
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    } finally {
      if (transaction) _db.execute('ROLLBACK');
    }
  }

  @override
  Future<Result<void, SyncFailure>> reserve({
    required WalletKey key,
    required UnsignedSpend spend,
    required String context,
  }) async {
    if (_closed) return const Err(SyncClosedFailure());
    final owner = spend.owner;
    final network = key.network;
    if (owner == null ||
        owner.protocol != 'ark' ||
        key != spend.key ||
        network is! BitcoinNetwork ||
        spend.replacing != null ||
        spend.inputs.isEmpty ||
        spend.inputs.toSet().length != spend.inputs.length ||
        utf8.encode(context).length > 4096) {
      return const Err(SyncSpendRefusedFailure());
    }
    var transaction = false;
    try {
      // Pure public codec, no wallet open. Sync independently validates actual
      // native-segwit and unfinalised PSBT inputs before invoking this boundary.
      final decoded = decodeBitcoinPsbt(spend.encoded);
      final BitcoinPsbtFacts facts;
      switch (inspectBitcoinPsbt(spend.encoded)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          facts = value;
      }
      if (facts.unsignedTxid != decoded.txid ||
          facts.inputs.any(
            (i) =>
                i.hasFinalFields ||
                i.hasPartialSignatures ||
                i.hasTaprootKeySignature ||
                i.hasTaprootScriptSignatures ||
                i.prevoutScriptPubkey.length != 22 ||
                i.prevoutScriptPubkey[0] != 0 ||
                i.prevoutScriptPubkey[1] != 20,
          ) ||
          decoded.inputDetails.any((i) => i.scriptSig.isNotEmpty)) {
        return const Err(SyncSpendRefusedFailure());
      }

      if (decoded.inputs.length != spend.inputs.length ||
          !Iterable.generate(decoded.inputs.length)
              .every((i) => decoded.inputs[i] == spend.inputs[i])) {
        return const Err(SyncSpendRefusedFailure());
      }
      _db.execute('BEGIN IMMEDIATE');
      transaction = true;
      final rows = _db.select(
        'SELECT * FROM ark_funding_operations WHERE operation=?',
        [owner.session],
      );
      if (rows.length != 1) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }
      final row = rows.single;
      final sameScope =
          row['wallet'] == key.id &&
          row['network'] == network.name &&
          row['generation'] == spend.revision.generation &&
          row['context'] == context;
      if (!sameScope) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }
      if (row['state'] == 'confirmed' || row['state'] == 'conflicted') {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }
      if (row['psbt'] != null) {
        final same =
            row['psbt'] == spend.encoded && row['txid'] == decoded.txid;
        final complete = _holdsMatch(owner.session, network.name, spend.inputs);
        _db.execute('ROLLBACK');
        transaction = false;
        return same && complete
            ? const Ok(null)
            : const Err(SyncSpendRefusedFailure());
      }
      for (final input in spend.inputs) {
        if (_db.select(
          'SELECT 1 FROM ark_funding_inputs WHERE network=? AND txid=? AND vout=?',
          [network.name, input.txId, input.vout],
        ).isNotEmpty) {
          _db.execute('ROLLBACK');
          transaction = false;
          return const Err(SyncSpendRefusedFailure());
        }
      }
      _db.execute(
        "UPDATE ark_funding_operations SET psbt=?,txid=?,revision=?,state='reserved' WHERE operation=?",
        [spend.encoded, decoded.txid, spend.revision.revision, owner.session],
      );
      for (final input in spend.inputs) {
        _db.execute(
          'INSERT INTO ark_funding_inputs(operation,network,txid,vout) VALUES(?,?,?,?)',
          [owner.session, network.name, input.txId, input.vout],
        );
      }
      _db.execute('COMMIT');
      transaction = false;
      return const Ok(null);
    } on FormatException {
      return const Err(SyncInvalidTransactionFailure());
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    } finally {
      if (transaction) _db.execute('ROLLBACK');
    }
  }

  /// Persist signatures before the host can hand them to broadcast. Native
  /// SegWit funding must keep the exact unsigned txid; never accept a bump.
  @useResult
  Future<Result<void, SyncFailure>> recordSigned(
    String operationId,
    String signedPsbt,
  ) async {
    if (_closed) return const Err(SyncClosedFailure());
    var transaction = false;
    try {
      final decoded = decodeBitcoinPsbt(signedPsbt);
      _db.execute('BEGIN IMMEDIATE');
      transaction = true;
      final rows = _db.select(
        'SELECT * FROM ark_funding_operations WHERE operation=?',
        [operationId],
      );
      if (rows.length != 1 ||
          rows.single['psbt'] == null ||
          rows.single['txid'] != decoded.txid) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }

      final row = rows.single;
      if (row['state'] == 'confirmed' || row['state'] == 'conflicted') {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }
      final original = row['psbt'];
      if (original is! String) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncStorageFailure());
      }
      final BitcoinPsbtFacts before;
      final BitcoinPsbtFacts after;
      switch (inspectBitcoinPsbt(original)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          before = value;
      }
      switch (inspectBitcoinPsbt(signedPsbt)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          after = value;
      }
      if (after.finalTransaction == null ||
          after.finalTransaction?.txid != before.unsignedTxid ||
          before.unsignedTxid != after.unsignedTxid ||
          before.feeSat != after.feeSat ||
          before.inputs.length != after.inputs.length ||
          after.inputs.any((i) => !i.hasFinalWitness) ||
          !Iterable.generate(before.inputs.length).every(
            (index) =>
                before.inputs[index].outpoint == after.inputs[index].outpoint &&
                before.inputs[index].prevoutValueSat ==
                    after.inputs[index].prevoutValueSat &&
                _equalBytes(
                  before.inputs[index].prevoutScriptPubkey,
                  after.inputs[index].prevoutScriptPubkey,
                ),
          )) {
        return const Err(SyncSpendRefusedFailure());
      }
      final previous = rows.single['signed_psbt'];
      if (previous != null && previous != signedPsbt) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }
      _db.execute(
        "UPDATE ark_funding_operations SET signed_psbt=?,state='signed' WHERE operation=?",
        [signedPsbt, operationId],
      );
      _db.execute('COMMIT');
      transaction = false;
      return const Ok(null);
    } on FormatException {
      return const Err(SyncInvalidTransactionFailure());
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    } finally {
      if (transaction) _db.execute('ROLLBACK');
    }
  }

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    if (_closed) return const Err(SyncClosedFailure());
    var transaction = false;
    try {
      // Keep the PSBT and every ownership row in the same read snapshot.
      _db.execute('BEGIN');
      transaction = true;
      for (final row in _db.select(
        "SELECT * FROM ark_funding_operations WHERE state NOT IN ('confirmed','conflicted')",
      )) {
        final state = row['state'];
        if (state != 'requested' && state != 'reserved' && state != 'signed') {
          return const Err(SyncStorageFailure());
        }
        final psbt = row['psbt'];
        if (psbt == null && state == 'requested') continue;
        if (psbt is! String) return const Err(SyncStorageFailure());
        final decoded = decodeBitcoinPsbt(psbt);
        if (decoded.txid != row['txid'] ||
            !_holdsMatch(
              row['operation'] as String,
              row['network'] as String,
              decoded.inputs,
            )) {
          return const Err(SyncStorageFailure());
        }
      }
      final held = <InputReservation>[];
      for (final row in _db.select(
        "SELECT i.*,o.wallet,o.state FROM ark_funding_inputs i JOIN ark_funding_operations o ON o.operation=i.operation WHERE o.state NOT IN ('confirmed','conflicted')",
      )) {
        final network = BitcoinNetwork.values
            .where((n) => n.name == row['network'])
            .toList();
        final txid = row['txid'];
        final vout = row['vout'];
        final operation = row['operation'];
        final wallet = row['wallet'];
        final state = row['state'];
        if (network.length != 1 ||
            txid is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(txid) ||
            vout is! int ||
            vout < 0 ||
            operation is! String ||
            operation.isEmpty ||
            wallet is! String ||
            wallet.isEmpty ||
            state is! String) {
          return const Err(SyncStorageFailure());
        }
        held.add(
          InputReservation(
            outpoint: (txId: txid, vout: vout),
            protocol: 'ark',
            session: operation,
            walletId: wallet,
            network: network.single,
            state: state,
          ),
        );
      }
      _db.execute('COMMIT');
      transaction = false;
      return Ok(List.unmodifiable(held));
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    } finally {
      if (transaction) _db.execute('ROLLBACK');
    }
  }

  bool _holdsMatch(String operation, String network, List<Outpoint> expected) {
    final rows = _db.select(
      'SELECT network,txid,vout FROM ark_funding_inputs WHERE operation=?',
      [operation],
    );
    return expected.isNotEmpty &&
        rows.length == expected.length &&
        rows.every(
          (row) =>
              row['network'] == network &&
              expected.contains((
                txId: row['txid'] as String,
                vout: row['vout'] as int,
              )),
        );
  }

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async {
    if (_closed) return const Err(SyncClosedFailure());
    try {
      final parents = <Fingerprint>{};
      for (final row in _db.select(
        "SELECT parent FROM ark_funding_operations WHERE state NOT IN ('confirmed','conflicted')",
      )) {
        final raw = row['parent'];
        final parent = raw is String ? Fingerprint.tryParse(raw) : null;
        if (parent == null) return const Err(SyncStorageFailure());
        parents.add(parent);
      }
      return Ok(parents);
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    }
  }

  /// Only a current ready native history can settle ownership. Absence and
  /// unconfirmed transactions prove nothing. Retain the original PSBT and txid.
  @useResult
  Future<Result<void, SyncFailure>> observe(
    WalletKey key,
    WalletTransactions history,
  ) async {
    if (_closed) return const Err(SyncClosedFailure());
    final stamp = history.revision;
    final data = history.data;
    final network = key.network;
    if (network is! BitcoinNetwork ||
        history.status != ValueStatus.ready ||
        stamp == null ||
        data == null ||
        stamp.key != key) {
      return const Err(SyncStorageFailure());
    }
    var transaction = false;
    try {
      _db.execute('BEGIN IMMEDIATE');
      transaction = true;
      final rows = _db.select(
        "SELECT * FROM ark_funding_operations WHERE wallet=? AND state NOT IN ('confirmed','conflicted')",
        [key.id],
      );
      for (final row in rows) {
        if ((row['revision'] is int &&
                stamp.revision < (row['revision'] as int)) ||
            row['generation'] != stamp.generation ||
            row['network'] != network.name ||
            row['txid'] == null) {
          continue;
        }
        final ownInputs = _db
            .select(
              'SELECT txid,vout FROM ark_funding_inputs WHERE operation=?',
              [row['operation']],
            )
            .map((r) => (txId: r['txid'] as String, vout: r['vout'] as int))
            .toSet();
        for (final tx in data.whereType<BitcoinTransaction>()) {
          if (tx.confirmationTime == null) continue;
          final matches = tx.txid == row['txid'];
          final conflicts = tx.inputs.any(
            (input) => ownInputs.contains(input.previousOutput),
          );
          if (matches || conflicts) {
            _db.execute(
              'UPDATE ark_funding_operations SET state=? WHERE operation=?',
              [matches ? 'confirmed' : 'conflicted', row['operation']],
            );
            break;
          }
        }
      }
      _db.execute('COMMIT');
      transaction = false;
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    } finally {
      if (transaction) _db.execute('ROLLBACK');
    }
  }

  static bool _equalBytes(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);

  void close() {
    if (_closed) return;
    _closed = true;
    _db.close();
  }
}
