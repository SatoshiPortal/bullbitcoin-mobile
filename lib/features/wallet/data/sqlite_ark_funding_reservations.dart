import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SeedReferencePort;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

/// Immutable journal data, not a caller-created signing capability.
final class ArkFundingBinding {
  final String operationId;
  final String accountIdentity;
  final Fingerprint sourceParent;
  final WalletKey key;
  final WalletRevision revision;
  final String context;
  final String unsignedPsbt;
  final String unsignedTxid;
  final List<Outpoint> inputs;
  ArkFundingBinding({
    required this.operationId,
    required this.accountIdentity,
    required this.sourceParent,
    required this.key,
    required this.revision,
    required this.context,
    required this.unsignedPsbt,
    required this.unsignedTxid,
    required List<Outpoint> inputs,
  }) : inputs = List.unmodifiable(inputs);
}

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
      if (foreground) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(_authorityDdl);
          _checkAuthoritySchema(db);
          db.execute('COMMIT');
        } finally {
          if (!db.autocommit) db.execute('ROLLBACK');
        }
      } else {
        _checkAuthoritySchema(db);
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
            !_terminal.contains(_state(row)) &&
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
      _db.execute(
        "INSERT INTO ark_funding_authority(operation,protocol,signing) VALUES(?,1,'never_started')",
        [operationId],
      );
      _db.execute('COMMIT');
      transaction = false;
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(SyncStorageFailure());
    } finally {
      if (transaction && !_db.autocommit) _db.execute('ROLLBACK');
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
      if (!_unsignedFundingFacts(
        facts,
        decodedTxid: decoded.txid,
        hasScriptSig: decoded.inputDetails.any((i) => i.scriptSig.isNotEmpty),
      )) {
        return const Err(SyncSpendRefusedFailure());
      }

      if (decoded.inputs.length != spend.inputs.length ||
          !Iterable.generate(decoded.inputs.length)
              .every((i) => decoded.inputs[i] == spend.inputs[i])) {
        return const Err(SyncSpendRefusedFailure());
      }
      _db.execute('BEGIN IMMEDIATE');
      transaction = true;
      _inventory();
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
      if (_terminal.contains(_state(row))) {
        _db.execute('ROLLBACK');
        transaction = false;
        return const Err(SyncSpendRefusedFailure());
      }
      if (_db.select(
        'SELECT 1 FROM ark_funding_operations WHERE network=? AND txid=? AND operation<>?',
        [network.name, decoded.txid, owner.session],
      ).isNotEmpty) {
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
      if (transaction && !_db.autocommit) _db.execute('ROLLBACK');
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
      if (_authority(row)?['signing'] != 'started') {
        return const Err(SyncSpendRefusedFailure());
      }
      _inventory();
      if (_terminal.contains(_state(row))) {
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
      if (transaction && !_db.autocommit) _db.execute('ROLLBACK');
    }
  }

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      _run(_inventory);

  List<InputReservation> _inventory() {
    final held = <InputReservation>[];
    for (final row in _db.select('SELECT * FROM ark_funding_operations')) {
      final state = _state(row);
      final authority = _authority(row);
      final closed = _closedProof(row);
      final inputs = _db.select(
        'SELECT * FROM ark_funding_inputs WHERE operation=?',
        [row['operation']],
      );
      if (_terminal.contains(state)) {
        if (inputs.isNotEmpty || (state == 'tombstoned' && !closed)) _storage();
        _binding(row); // Corrupt terminal PSBT/txid cannot hide an old binding.
        continue; // Legacy terminal pins are unresolved; never recreate holds.
      }
      if (closed || authority?['signing'] == 'tombstoned') _storage();
      if (state == 'requested') {
        final operation = row['operation'],
            account = row['account'],
            parent = row['parent'],
            wallet = row['wallet'],
            network = row['network'],
            generation = row['generation'],
            context = row['context'];
        if (operation is! String ||
            operation.isEmpty ||
            operation.length > 512 ||
            account is! String ||
            account.isEmpty ||
            parent is! String ||
            Fingerprint.tryParse(parent) == null ||
            wallet is! String ||
            wallet.isEmpty ||
            !BitcoinNetwork.values.any((n) => n.name == network) ||
            generation is! int ||
            generation < 0 ||
            context is! String ||
            context.isEmpty ||
            utf8.encode(context).length > 4096) {
          _storage();
        }
        if (row['psbt'] != null ||
            row['txid'] != null ||
            row['signed_psbt'] != null ||
            inputs.isNotEmpty ||
            authority?['signing'] == 'started') {
          _storage();
        }
        continue;
      }
      final binding = _binding(row);
      final network = binding.key.network;
      if (network is! BitcoinNetwork) _storage();
      if (!_holdsMatch(
        binding.operationId,
        _networkName(binding.key),
        binding.inputs,
      )) {
        _storage();
      }
      if ((state == 'signed' &&
              (row['signed_psbt'] is! String ||
                  authority?['signing'] == 'never_started')) ||
          (state == 'reserved' && row['signed_psbt'] != null)) {
        _storage();
      }
      for (final input in binding.inputs) {
        held.add(
          InputReservation(
            outpoint: input,
            protocol: 'ark',
            session: binding.operationId,
            walletId: binding.key.id,
            network: network,
            state: state,
          ),
        );
      }
    }
    // Orphan rows cannot become an apparently unrelated/empty inventory.
    if (_db
        .select(
          'SELECT 1 FROM ark_funding_authority a LEFT JOIN ark_funding_operations o ON o.operation=a.operation WHERE o.operation IS NULL',
        )
        .isNotEmpty) {
      _storage();
    }
    if (_db
        .select(
          'SELECT 1 FROM ark_funding_inputs i LEFT JOIN ark_funding_operations o ON o.operation=i.operation WHERE o.operation IS NULL',
        )
        .isNotEmpty) {
      _storage();
    }
    return List.unmodifiable(held);
  }

  bool _holdsMatch(String operation, String network, List<Outpoint> expected) {
    final rows = _db.select(
      'SELECT network,txid,vout FROM ark_funding_inputs WHERE operation=?',
      [operation],
    );
    return expected.isNotEmpty &&
        rows.length == expected.length &&
        rows.every((row) {
          final txid = row['txid'];
          final vout = row['vout'];
          return row['network'] == network &&
              txid is String &&
              _txid.hasMatch(txid) &&
              vout is int &&
              vout >= 0 &&
              vout <= 0xffffffff &&
              expected.contains((txId: txid, vout: vout));
        });
  }

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async =>
      _run(() {
        _inventory();
        final parents = <Fingerprint>{};
        for (final row in _db.select('SELECT * FROM ark_funding_operations')) {
          if (_closedProof(row)) continue;
          final raw = row['parent'];
          final parent = raw is String ? Fingerprint.tryParse(raw) : null;
          if (parent == null) _storage();
          parents.add(parent);
        }
        return parents;
      });

  /// The actor supplies fresh native history after obtaining the SAME source
  /// admission stamp. Value equality alone does not establish native origin.
  @useResult
  Future<Result<void, SyncFailure>> observe(
    WalletKey key,
    WalletTransactions history, {
    required WalletRevision admittedRevision,
  }) async {
    final stamp = history.revision;
    final data = history.data;
    if (key.network is! BitcoinNetwork ||
        history.status != ValueStatus.ready ||
        stamp == null ||
        data == null ||
        stamp.key != key ||
        stamp != admittedRevision) {
      return const Err(SyncStorageFailure());
    }
    return _run(() {
      _inventory();
      for (final row in _db.select(
        'SELECT * FROM ark_funding_operations WHERE wallet=?',
        [key.id],
      )) {
        if (_closedProof(row) ||
            row['state'] == 'requested' ||
            row['psbt'] == null) {
          continue;
        }
        final binding = _binding(row);
        if (binding.key != key ||
            binding.revision.generation != stamp.generation ||
            stamp.revision < binding.revision.revision) {
          continue;
        }
        for (final tx in data.whereType<BitcoinTransaction>()) {
          final time = tx.confirmationTime;
          if (time == null || time <= 0) continue;
          final matches = tx.txid == binding.unsignedTxid;
          Outpoint? matched;
          for (final input in tx.inputs) {
            if (binding.inputs.contains(input.previousOutput)) {
              matched = input.previousOutput;
              break;
            }
          }
          if (!matches && matched == null) continue;
          if (!_txid.hasMatch(tx.txid)) _storage();
          _db.execute(
            'UPDATE ark_funding_operations SET state=? WHERE operation=?',
            [matches ? 'confirmed' : 'conflicted', binding.operationId],
          );
          _db.execute('DELETE FROM ark_funding_inputs WHERE operation=?', [
            binding.operationId,
          ]);
          _closeSource(
            row,
            binding,
            stamp,
            matches ? 'confirmedFunding' : 'confirmedConflict',
            tx: tx,
            matched: matches ? null : matched,
          );
          break;
        }
      }
    }, write: true);
  }

  @useResult
  Future<Result<ArkFundingBinding, SyncFailure>> readBinding(
    String operationId,
  ) async => _run(() {
    _inventory();
    return _binding(_operation(operationId));
  });

  /// A negative lookup is NOT a signing lease. Host neverSigned activation
  /// additionally requires complete durable generic/export coverage.
  @useResult
  Future<Result<ArkFundingBinding?, SyncFailure>> bindingForSigning({
    required WalletKey key,
    required String unsignedPsbt,
  }) async => _run(() {
    if (key.network is! BitcoinNetwork) _refuse();
    final decoded = decodeBitcoinPsbt(unsignedPsbt);
    final held = _inventory();
    final rows = _db.select(
      'SELECT * FROM ark_funding_operations WHERE network=? AND txid=?',
      [_networkName(key), decoded.txid],
    );
    if (rows.isNotEmpty) {
      if (rows.length != 1 || _terminal.contains(_state(rows.single))) {
        _refuse();
      }
      final binding = _binding(rows.single);
      if (binding.key != key || binding.unsignedPsbt != unsignedPsbt) _refuse();
      return binding;
    }
    if (held.any(
      (r) => r.network == key.network && decoded.inputs.contains(r.outpoint),
    )) {
      _refuse();
    }
    return null;
  });

  @useResult
  Future<Result<void, SyncFailure>> beginSigning({
    required ArkFundingBinding expected,
    required WalletRevision admittedRevision,
  }) async => _run(() {
    final row = _match(expected, admittedRevision);
    if (_terminal.contains(_state(row))) _refuse();
    final signing = _authority(row)?['signing'];
    if (signing != 'never_started' && signing != 'started') _refuse();
    _db.execute(
      "UPDATE ark_funding_authority SET signing='started' WHERE operation=?",
      [expected.operationId],
    );
  }, write: true);

  @useResult
  Future<Result<void, SyncFailure>> tombstoneNeverSigned({
    required ArkFundingBinding expected,
    required WalletRevision admittedRevision,
  }) async => _run(() {
    final row = _match(expected, admittedRevision);
    if (_state(row) == 'tombstoned' && _closedProof(row)) return;
    if (_terminal.contains(_state(row)) ||
        _authority(row)?['signing'] != 'never_started' ||
        row['signed_psbt'] != null) {
      _refuse();
    }
    _db.execute(
      "UPDATE ark_funding_authority SET signing='tombstoned' WHERE operation=?",
      [expected.operationId],
    );
    _db.execute(
      "UPDATE ark_funding_operations SET state='tombstoned' WHERE operation=?",
      [expected.operationId],
    );
    _db.execute('DELETE FROM ark_funding_inputs WHERE operation=?', [
      expected.operationId,
    ]);
    _closeSource(row, expected, admittedRevision, 'neverSigned');
  }, write: true);

  Row _match(ArkFundingBinding expected, WalletRevision admitted) {
    _inventory();
    if (expected.revision.key != expected.key) _refuse();
    final row = _operation(expected.operationId);
    final actual = _binding(row);
    if (jsonEncode(_bindingJson(actual)) !=
            jsonEncode(_bindingJson(expected)) ||
        admitted.key != actual.key ||
        admitted.generation != actual.revision.generation ||
        admitted.revision < actual.revision.revision) {
      _refuse();
    }
    return row;
  }

  static const _terminal = ['confirmed', 'conflicted', 'tombstoned'];
  static final _txid = RegExp(r'^[0-9a-f]{64}$');
  static const _authorityDdl =
      "CREATE TABLE IF NOT EXISTS ark_funding_authority(operation TEXT PRIMARY KEY REFERENCES ark_funding_operations(operation),protocol INTEGER NOT NULL CHECK(protocol=1),signing TEXT NOT NULL CHECK(signing IN ('unknown','never_started','started','tombstoned')),settlement TEXT)";

  static void _checkAuthoritySchema(Database db) {
    final type = db.select(
      "SELECT type FROM sqlite_master WHERE name='ark_funding_authority'",
    );
    final columns = db.select('PRAGMA table_info(ark_funding_authority)');
    const names = ['operation', 'protocol', 'signing', 'settlement'];
    if (type.length != 1 ||
        type.single['type'] != 'table' ||
        columns.length != 4) {
      throw const FormatException();
    }
    for (var i = 0; i < names.length; i++) {
      if (columns[i]['name'] != names[i] ||
          columns[i]['type'] != (i == 1 ? 'INTEGER' : 'TEXT') ||
          columns[i]['pk'] != (i == 0 ? 1 : 0) ||
          columns[i]['notnull'] != ((i == 1 || i == 2) ? 1 : 0)) {
        throw const FormatException();
      }
    }
  }

  Row _operation(String id) {
    final rows = _db.select(
      'SELECT * FROM ark_funding_operations WHERE operation=?',
      [id],
    );
    if (rows.length != 1) _refuse();
    return rows.single;
  }

  String _state(Row row) {
    final value = row['state'];
    if (value is! String ||
        !['requested', 'reserved', 'signed', ..._terminal].contains(value)) {
      _storage();
    }
    return value;
  }

  Row? _authority(Row row) {
    final rows = _db.select(
      'SELECT * FROM ark_funding_authority WHERE operation=?',
      [row['operation']],
    );
    if (rows.isEmpty) {
      return null; // Explicit legacy/unknown, never never_started.
    }
    final value = rows.single;
    if (value['protocol'] is! int ||
        value['protocol'] != 1 ||
        ![
          'unknown',
          'never_started',
          'started',
          'tombstoned',
        ].contains(value['signing']) ||
        (value['settlement'] != null && value['settlement'] is! String)) {
      _storage();
    }
    return value;
  }

  ArkFundingBinding _binding(Row row) {
    try {
      final operation = row['operation'],
          account = row['account'],
          parent = row['parent'],
          wallet = row['wallet'],
          network = row['network'],
          generation = row['generation'],
          revision = row['revision'],
          context = row['context'],
          psbt = row['psbt'],
          txid = row['txid'];
      final parsedParent = parent is String
          ? Fingerprint.tryParse(parent)
          : null;
      final networks = BitcoinNetwork.values
          .where((n) => n.name == network)
          .toList();
      if (operation is! String ||
          operation.isEmpty ||
          account is! String ||
          account.isEmpty ||
          parsedParent == null ||
          wallet is! String ||
          wallet.isEmpty ||
          networks.length != 1 ||
          generation is! int ||
          generation < 0 ||
          revision is! int ||
          revision < 0 ||
          context is! String ||
          context.isEmpty ||
          utf8.encode(context).length > 4096 ||
          psbt is! String ||
          txid is! String) {
        _storage();
      }
      final decoded = decodeBitcoinPsbt(psbt);
      final facts = switch (inspectBitcoinPsbt(psbt)) {
        Ok(:final value) => value,
        Err() => _storage(),
      };
      if (!_unsignedFundingFacts(
        facts,
        decodedTxid: decoded.txid,
        hasScriptSig: decoded.inputDetails.any((i) => i.scriptSig.isNotEmpty),
      )) {
        _storage();
      }
      if (decoded.txid != txid ||
          decoded.inputs.isEmpty ||
          decoded.inputs.toSet().length != decoded.inputs.length) {
        _storage();
      }
      final key = WalletKey(id: wallet, network: networks.single);
      return ArkFundingBinding(
        operationId: operation,
        accountIdentity: account,
        sourceParent: parsedParent,
        key: key,
        revision: WalletRevision(
          key: key,
          generation: generation,
          revision: revision,
        ),
        context: context,
        unsignedPsbt: psbt,
        unsignedTxid: txid,
        inputs: decoded.inputs,
      );
    } on Exception {
      _storage();
    }
  }

  Map<String, Object?> _bindingJson(ArkFundingBinding b) => {
    'operationId': b.operationId,
    'accountIdentity': b.accountIdentity,
    'sourceParent': b.sourceParent.hex,
    'key': {'id': b.key.id, 'network': _networkName(b.key)},
    'revision': {
      'generation': b.revision.generation,
      'revision': b.revision.revision,
    },
    'context': b.context,
    'unsignedPsbt': b.unsignedPsbt,
    'unsignedTxid': b.unsignedTxid,
    'inputs': [
      for (final i in b.inputs) [i.txId, i.vout],
    ],
  };

  void _closeSource(
    Row row,
    ArkFundingBinding binding,
    WalletRevision admitted,
    String kind, {
    BitcoinTransaction? tx,
    Outpoint? matched,
  }) {
    final receipt = jsonEncode({
      'version': 1,
      'kind': kind,
      'closed': true,
      'binding': _bindingJson(binding),
      'admitted': {
        'wallet': admitted.key.id,
        'network': _networkName(admitted.key),
        'generation': admitted.generation,
        'revision': admitted.revision,
      },
      'observedTxid': tx?.txid,
      'confirmationTime': tx?.confirmationTime,
      'matchedInput': matched == null ? null : [matched.txId, matched.vout],
    });
    final signing = _authority(row)?['signing'] ?? 'unknown';
    _db.execute(
      'INSERT INTO ark_funding_authority(operation,protocol,signing,settlement) VALUES(?,1,?,?) ON CONFLICT(operation) DO UPDATE SET settlement=excluded.settlement',
      [binding.operationId, signing, receipt],
    );
    if (!_closedProof(_operation(binding.operationId))) _storage();
  }

  bool _closedProof(Row row) {
    final raw = _authority(row)?['settlement'];
    if (raw == null) return false;
    try {
      if (raw is! String) _storage();
      final value = jsonDecode(raw);
      final b = _binding(row);
      if (value is! Map<String, dynamic> ||
          value.length != 8 ||
          value['version'] is! int ||
          value['version'] != 1 ||
          value['closed'] != true ||
          jsonEncode(value['binding']) != jsonEncode(_bindingJson(b))) {
        _storage();
      }
      final admitted = value['admitted'];
      if (admitted is! Map<String, dynamic> ||
          admitted.length != 4 ||
          admitted['wallet'] != b.key.id ||
          admitted['network'] != _networkName(b.key) ||
          admitted['generation'] != b.revision.generation ||
          admitted['generation'] is! int ||
          admitted['revision'] is! int ||
          (admitted['revision'] as int) < b.revision.revision ||
          _db.select('SELECT 1 FROM ark_funding_inputs WHERE operation=?', [
            b.operationId,
          ]).isNotEmpty) {
        _storage();
      }
      final kind = value['kind'],
          txid = value['observedTxid'],
          time = value['confirmationTime'],
          matched = value['matchedInput'];
      if (kind == 'neverSigned') {
        if (_state(row) != 'tombstoned' ||
            _authority(row)?['signing'] != 'tombstoned' ||
            row['signed_psbt'] != null ||
            txid != null ||
            time != null ||
            matched != null) {
          _storage();
        }
      } else {
        if (txid is! String ||
            !_txid.hasMatch(txid) ||
            time is! int ||
            time <= 0) {
          _storage();
        }
        if (kind == 'confirmedFunding') {
          if (_state(row) != 'confirmed' ||
              txid != b.unsignedTxid ||
              matched != null) {
            _storage();
          }
        } else if (kind == 'confirmedConflict') {
          if (_state(row) != 'conflicted' ||
              txid == b.unsignedTxid ||
              matched is! List ||
              matched.length != 2 ||
              matched[0] is! String ||
              matched[1] is! int ||
              !b.inputs.any(
                (i) => i.txId == matched[0] && i.vout == matched[1],
              )) {
            _storage();
          }
        } else {
          _storage();
        }
      }
      return true;
    } on Exception {
      _storage();
    }
  }

  Result<T, SyncFailure> _run<T>(T Function() action, {bool write = false}) {
    if (_closed) return const Err(SyncClosedFailure());
    try {
      _db.execute(write ? 'BEGIN IMMEDIATE' : 'BEGIN');
      final value = action();
      _db.execute('COMMIT');
      return Ok(value);
    } on _FundingRefusal catch (error) {
      return Err(error.failure);
    } on FormatException {
      return const Err(SyncInvalidTransactionFailure());
    } on Exception {
      return const Err(SyncStorageFailure());
    } finally {
      if (!_db.autocommit) {
        try {
          _db.execute('ROLLBACK');
        } on Exception {
          _closed = true;
          _db.close();
        }
      }
    }
  }

  String _networkName(WalletKey key) {
    final network = key.network;
    if (network is! BitcoinNetwork) _refuse();
    return network.name;
  }

  Never _refuse() => throw const _FundingRefusal(SyncSpendRefusedFailure());
  Never _storage() => throw const _FundingRefusal(SyncStorageFailure());

  // The same pure prepared-funding facts guard at admission and reconstruction.
  // Persisted contradictions map to StorageFailure; this checks presence/shape,
  // not cryptographic signature validity or native ownership/provenance.
  static bool _unsignedFundingFacts(
    BitcoinPsbtFacts facts, {
    required String decodedTxid,
    required bool hasScriptSig,
  }) =>
      facts.unsignedTxid == decodedTxid &&
      !hasScriptSig &&
      !facts.inputs.any(
        (i) =>
            i.hasFinalFields ||
            i.hasPartialSignatures ||
            i.hasTaprootKeySignature ||
            i.hasTaprootScriptSignatures ||
            i.prevoutScriptPubkey.length != 22 ||
            i.prevoutScriptPubkey[0] != 0 ||
            i.prevoutScriptPubkey[1] != 20,
      );

  static bool _equalBytes(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);

  void close() {
    if (_closed) return;
    _closed = true;
    _db.close();
  }
}

final class _FundingRefusal implements Exception {
  final SyncFailure failure;
  const _FundingRefusal(this.failure);
}
