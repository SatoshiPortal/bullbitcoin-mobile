import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart' show ArkStorageFailure, ArkWalletFailure;
import 'package:ark/funding.dart';
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
    implements
        FundingReservationPort,
        SeedReferencePort,
        ArkFundingSigningAuthority {
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
          db.execute(_authorityDdl);
          db.execute(_ordinaryDdl);
          db.execute(_boardDdl);
          _checkAuthoritySchema(db);
          _checkHostSchema(db);
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
      // An initialized store must retain its complete signing history. A
      // missing safety table is corruption, never an implicit migration.
      _checkAuthoritySchema(db);
      _checkHostSchema(db);
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
  }) => _beginRequest(
    operationId: operationId,
    accountIdentity: accountIdentity,
    sourceParent: sourceParent,
    key: key,
    generation: generation,
    context: context,
    exclusiveAccount: false,
  );

  @useResult
  Future<Result<void, SyncFailure>> beginBoardRequest({
    required String operationId,
    required String accountIdentity,
    required Fingerprint sourceParent,
    required WalletKey key,
    required int generation,
    required String context,
  }) => _beginRequest(
    operationId: operationId,
    accountIdentity: accountIdentity,
    sourceParent: sourceParent,
    key: key,
    generation: generation,
    context: context,
    exclusiveAccount: true,
  );

  /// Claims the initial reserve request exactly once, including across restarts
  /// and terminal states. Retrying callers must read, not prepare another spend.
  @useResult
  Future<Result<void, SyncFailure>> beginExitReserveRequest({
    required String operationId,
    required String accountIdentity,
    required Fingerprint sourceParent,
    required WalletKey key,
    required int generation,
    required String context,
  }) async {
    if (operationId.isEmpty ||
        operationId.length > 512 ||
        accountIdentity.isEmpty ||
        key.id.isEmpty ||
        key.network != BitcoinNetwork.regtest ||
        generation < 0 ||
        utf8.encode(context).length > 4096 ||
        !_isExitReserveContext(context, account: accountIdentity)) {
      return const Err(SyncSpendRefusedFailure());
    }
    return _run(() {
      _inventory();
      for (final row in _db.select(
        'SELECT * FROM ark_funding_operations WHERE account=? OR operation=?',
        [accountIdentity, operationId],
      )) {
        if (row['operation'] == operationId ||
            (row['account'] == accountIdentity &&
                (_isExitReserveContext(row['context']) ||
                    !_terminal.contains(_state(row))))) {
          _refuse();
        }
      }
      _db.execute(
        'INSERT INTO ark_funding_operations(operation,account,parent,wallet,network,generation,context,state) VALUES(?,?,?,?,?,?,?,?)',
        [
          operationId,
          accountIdentity,
          sourceParent.hex,
          key.id,
          BitcoinNetwork.regtest.name,
          generation,
          context,
          'requested',
        ],
      );
      _db.execute(
        "INSERT INTO ark_funding_authority(operation,protocol,signing) VALUES(?,1,'never_started')",
        [operationId],
      );
    }, write: true);
  }

  /// Returns signed bytes for exact-byte redelivery. Confirmation requires the
  /// validated source observation receipt, not merely a terminal state label.
  @useResult
  Future<Result<ArkExitReserveRequest?, SyncFailure>> readExitReserveRequest(
    String operationId,
  ) async => _run(() {
    _inventory();
    final rows = _db.select(
      'SELECT * FROM ark_funding_operations WHERE operation=?',
      [operationId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final context = row['context'];
    if (context is! String ||
        !_isExitReserveContext(context, account: row['account'] as String)) {
      _refuse();
    }
    final state = _state(row);
    final txid = row['txid'];
    final signed = row['signed_psbt'];
    if ((txid != null && (txid is! String || !_txid.hasMatch(txid))) ||
        (signed != null && signed is! String)) {
      _storage();
    }
    final confirmed = state == 'confirmed' && _closedProof(row);
    if (state == 'confirmed' && !confirmed) _storage();
    return (
      state: state,
      signedPsbt: signed as String?,
      txid: txid as String?,
      context: context,
      confirmed: confirmed,
    );
  });

  static bool _isExitReserveContext(Object? raw, {String? account}) {
    if (raw is! String) return false;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> &&
          value['type'] == 'exitReserve' &&
          value['version'] == 1 &&
          value['account'] is String &&
          (account == null || value['account'] == account);
    } on FormatException {
      return false;
    }
  }

  Future<Result<void, SyncFailure>> _beginRequest({
    required String operationId,
    required String accountIdentity,
    required Fingerprint sourceParent,
    required WalletKey key,
    required int generation,
    required String context,
    required bool exclusiveAccount,
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
      if (exclusiveAccount) {
        _inventory();
        if (_db.select(
          "SELECT 1 FROM ark_funding_operations WHERE account=? AND operation<>? AND state NOT IN ('confirmed','conflicted','tombstoned')",
          [accountIdentity, operationId],
        ).isNotEmpty) {
          _refuse();
        }
      }
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
      if (_db.select(
        'SELECT 1 FROM ark_ordinary_signing WHERE network=? AND txid=?',
        [network.name, decoded.txid],
      ).isNotEmpty) {
        _refuse();
      }
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
      // Not final: Dart 3.14.0 AOT crashes on a switch-assigned final captured by a closure (dart-lang/sdk#64917).
      BitcoinPsbtFacts before;
      BitcoinPsbtFacts after;
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
    _checkHostSchema(_db);
    for (final row in _db.select(
      'SELECT network,txid FROM ark_ordinary_signing',
    )) {
      if (!BitcoinNetwork.values.any((n) => n.name == row['network']) ||
          row['txid'] is! String ||
          !_txid.hasMatch(row['txid'] as String)) {
        _storage();
      }
    }
    for (final row in _db.select('SELECT operation FROM ark_board_reviews')) {
      final id = row['operation'];
      if (id is! String || id.isEmpty) _storage();
      _operation(id);
      _boardReview(id);
    }
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
        // Only a fully validated neverPrepared receipt can close without a
        // prepared binding; NULL bytes alone never establish this exception.
        if (!(state == 'tombstoned' && closed && row['psbt'] == null)) {
          _binding(row);
        }
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

  /// Data-local request facts, never a signing or absence capability.
  @useResult
  Future<Result<ArkFundingRequest?, SyncFailure>> readUnpreparedRequest(
    String operationId,
  ) async => _run(() {
    _inventory();
    final row = _operation(operationId);
    if (_state(row) != 'requested') return null;
    if (_authority(row)?['signing'] != 'never_started') _refuse();
    return _requestFacts(row);
  });

  /// The actor supplies admission from the configured source gate. Both this
  /// tombstone and reserve take BEGIN IMMEDIATE: a late reserve cannot win too.
  @useResult
  Future<Result<void, SyncFailure>> closeNeverPrepared({
    required ArkFundingRequest expected,
    required WalletRevision admittedRevision,
  }) async => _run(() {
    _inventory();
    final row = _operation(expected.operationId);
    if (_isExitReserveContext(row['context']) ||
        _state(row) != 'requested' ||
        _authority(row)?['signing'] != 'never_started' ||
        _authority(row)?['settlement'] != null ||
        _requestFacts(row) != expected ||
        admittedRevision.key != expected.key ||
        admittedRevision.generation != expected.generation ||
        admittedRevision.revision < 0) {
      _refuse();
    }
    final receipt = jsonEncode({
      'version': 1,
      'kind': 'neverPrepared',
      'closed': true,
      'request': _requestJson(expected),
      'signingBefore': 'never_started',
      'admitted': {
        'wallet': admittedRevision.key.id,
        'network': _networkName(admittedRevision.key),
        'generation': admittedRevision.generation,
        'revision': admittedRevision.revision,
      },
    });
    _db.execute(
      "UPDATE ark_funding_authority SET signing='tombstoned',settlement=? WHERE operation=?",
      [receipt, expected.operationId],
    );
    _db.execute(
      "UPDATE ark_funding_operations SET state='tombstoned' WHERE operation=?",
      [expected.operationId],
    );
    // No input DELETE or immutable request-payload mutation: no hold was owned.
    if (!_closedProof(_operation(expected.operationId))) _storage();
  }, write: true);

  ArkFundingRequest _requestFacts(Row row) {
    final operation = row['operation'],
        account = row['account'],
        parent = row['parent'],
        wallet = row['wallet'],
        generation = row['generation'],
        context = row['context'];
    final parsedParent = parent is String ? Fingerprint.tryParse(parent) : null;
    final network = row['network'] is String
        ? BitcoinNetwork.tryFromName(row['network'] as String)
        : null;
    if (operation is! String ||
        operation.isEmpty ||
        operation.length > 512 ||
        account is! String ||
        account.isEmpty ||
        parsedParent == null ||
        wallet is! String ||
        wallet.isEmpty ||
        network == null ||
        generation is! int ||
        generation < 0 ||
        context is! String ||
        context.isEmpty ||
        utf8.encode(context).length > 4096 ||
        row['revision'] != null ||
        row['psbt'] != null ||
        row['txid'] != null ||
        row['signed_psbt'] != null ||
        _db.select('SELECT 1 FROM ark_funding_inputs WHERE operation=?', [
          operation,
        ]).isNotEmpty ||
        _db.select('SELECT 1 FROM ark_board_reviews WHERE operation=?', [
          operation,
        ]).isNotEmpty) {
      _storage();
    }
    return (
      operationId: operation,
      accountIdentity: account,
      sourceParent: parsedParent,
      key: WalletKey(id: wallet, network: network),
      generation: generation,
      context: context,
    );
  }

  Map<String, Object> _requestJson(ArkFundingRequest request) => {
    'operation': request.operationId,
    'account': request.accountIdentity,
    'parent': request.sourceParent.hex,
    'wallet': request.key.id,
    'network': _networkName(request.key),
    'generation': request.generation,
    'context': request.context,
  };

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
  }) async => _run(() => _classifySigning(key, unsignedPsbt));

  @override
  Future<Result<void, ArkWalletFailure>> recordOrdinarySigning({
    required String walletId,
    required BitcoinNetwork network,
    required String unsignedPsbt,
  }) async => (await admitOrdinarySigning(
    key: WalletKey(id: walletId, network: network),
    unsignedPsbt: unsignedPsbt,
  )).mapErr((_) => const ArkStorageFailure());

  // Publishes irreversible possible signer handoff before Secrets. This is an
  // EXACT network/unsigned-txid fence, not a blacklist of unrelated input reuse.
  @useResult
  Future<Result<void, SyncFailure>> admitOrdinarySigning({
    required WalletKey key,
    required String unsignedPsbt,
  }) async => _run(() {
    if (_classifySigning(key, unsignedPsbt) != null) _refuse();
    final decoded = decodeBitcoinPsbt(unsignedPsbt);
    _db.execute(
      'INSERT INTO ark_ordinary_signing(network,txid) VALUES(?,?) ON CONFLICT DO NOTHING',
      [_networkName(key), decoded.txid],
    );
  }, write: true);

  ArkFundingBinding? _classifySigning(WalletKey key, String unsignedPsbt) {
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
  }

  @useResult
  Future<Result<void, SyncFailure>> beginSigning({
    required ArkFundingBinding expected,
    required WalletRevision admittedRevision,
  }) async => _run(() {
    final row = _match(expected, admittedRevision);
    if (_isExitReserveContext(row['context']) ||
        _terminal.contains(_state(row))) {
      _refuse();
    }
    final signing = _authority(row)?['signing'];
    if (signing != 'never_started' && signing != 'started') _refuse();
    _db.execute(
      "UPDATE ark_funding_authority SET signing='started' WHERE operation=?",
      [expected.operationId],
    );
  }, write: true);

  /// A single signer admission under the source spend gate. Once sealed, a
  /// crash is ambiguous and may only be recovered using existing signed bytes.
  @useResult
  Future<Result<void, SyncFailure>> admitExitReserveSigning({
    required ArkFundingBinding expected,
    required WalletRevision admittedRevision,
  }) async => _run(() {
    final row = _match(expected, admittedRevision);
    if (!_isExitReserveContext(
          row['context'],
          account: expected.accountIdentity,
        ) ||
        _state(row) != 'reserved' ||
        _authority(row)?['signing'] != 'never_started') {
      _refuse();
    }
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
    if (_isExitReserveContext(row['context']) ||
        _terminal.contains(_state(row)) ||
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

  @useResult
  Future<Result<String?, SyncFailure>> pendingForAccount(
    String account,
  ) async => _run(() {
    _inventory();
    final rows = _db.select(
      "SELECT operation FROM ark_funding_operations WHERE account=? AND state NOT IN ('confirmed','conflicted','tombstoned') ORDER BY operation",
      [account],
    );
    if (rows.isEmpty) return null;
    final id = rows.first['operation'];
    if (id is! String || id.isEmpty) _storage();
    return id;
  });

  /// Immutable review facts are separate from the untouched funding journal.
  @useResult
  Future<Result<void, SyncFailure>> saveBoardReview(
    String operationId,
    String payload,
  ) async => _run(() {
    _inventory();
    if (payload.isEmpty || utf8.encode(payload).length > 8192) _refuse();
    _reviewPayload(payload);
    final row = _operation(operationId);
    _binding(row);
    if (_state(row) != 'reserved' ||
        _authority(row)?['signing'] != 'never_started') {
      _refuse();
    }
    final previous = _db.select(
      'SELECT * FROM ark_board_reviews WHERE operation=?',
      [operationId],
    );
    if (previous.isNotEmpty) {
      if (previous.single['payload'] != payload ||
          previous.single['phase'] != 'prepared') {
        _refuse();
      }
      return;
    }
    _db.execute(
      'INSERT INTO ark_board_reviews(operation,payload,phase) VALUES(?,?,?)',
      [operationId, payload, 'prepared'],
    );
  }, write: true);

  @useResult
  Future<Result<ArkBoardJournalEntry, SyncFailure>> readBoardReview(
    String operationId,
  ) async => _run(() {
    _inventory();
    final row = _operation(operationId);
    final review = _boardReview(operationId);
    if (_terminal.contains(_state(row)) && review['phase'] != 'broadcast') {
      _refuse();
    }
    if (review['phase'] == 'prepared' &&
        (_state(row) != 'reserved' ||
            _authority(row)?['signing'] != 'never_started')) {
      _storage();
    }
    final signed = row['signed_psbt'];
    if (signed != null && signed is! String) _storage();
    return ArkBoardJournalEntry(
      binding: _binding(row),
      payload: review['payload'] as String,
      phase: review['phase'] as String,
      signedPsbt: signed is String ? signed : null,
    );
  });

  /// Read-only evidence for one exact abandoned external Board. A terminal
  /// label, missing row or unrelated closure never supplies this attestation.
  @useResult
  Future<Result<ArkNeverSignedBoardFacts?, SyncFailure>> readNeverSignedBoard({
    required String accountIdentity,
    required Fingerprint sourceParent,
    required BitcoinNetwork network,
    required String operationId,
    required String fundingTxid,
  }) async => _run(() {
    if (network != BitcoinNetwork.regtest ||
        operationId.isEmpty ||
        operationId.length > 512 ||
        !_txid.hasMatch(fundingTxid)) {
      _refuse();
    }
    _inventory();
    final rows = _db.select(
      'SELECT * FROM ark_funding_operations WHERE operation=?',
      [operationId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row['account'] != accountIdentity ||
        row['parent'] != sourceParent.hex ||
        row['network'] != network.name ||
        row['txid'] != fundingTxid) {
      _refuse();
    }
    if (!_closedProof(row)) return null;
    final raw = _authority(row)?['settlement'];
    if (raw is! String) _storage();
    final receipt = jsonDecode(raw);
    if (receipt is! Map<String, dynamic> || receipt['kind'] != 'neverSigned') {
      return null;
    }
    final binding = _binding(row);
    final review = _boardReview(operationId);
    if (review['phase'] != 'prepared' || row['signed_psbt'] != null) _storage();
    final payload = jsonDecode(review['payload'] as String);
    final context = jsonDecode(binding.context);
    if (payload is! Map<String, dynamic> ||
        context is! Map<String, dynamic> ||
        payload['request'] != binding.context ||
        context['version'] is! int ||
        (context['version'] != 1 && context['version'] != 2) ||
        context['account'] != accountIdentity) {
      _storage();
    }
    // The Bark-specific abandonment proof contains a derivation index. A
    // Scuttle reservation can be safely released by the same host CAS, but
    // cannot be translated into this package-facing proof.
    if (context['version'] == 2) return null;
    final address = payload['address'],
        index = payload['keypairIndex'],
        expiry = payload['expiryHeight'],
        minerFee = payload['minerFee'];
    if (address is! String ||
        address.isEmpty ||
        address.length > 512 ||
        address.trim() != address ||
        index is! int ||
        index < 0 ||
        index > 0xffffffff ||
        expiry is! int ||
        expiry < 0 ||
        expiry > 0xffffffff ||
        minerFee is! int ||
        minerFee < 0) {
      _storage();
    }
    final gross = _boardSats(context['amount']),
        net = _boardSats(context['net']),
        fee = _boardSats(context['arkFee']);
    if (gross <= BigInt.zero || net <= BigInt.zero || gross != net + fee) {
      _storage();
    }
    final facts = switch (inspectBitcoinPsbt(binding.unsignedPsbt)) {
      Ok(:final value) => value,
      Err() => _storage(),
    };
    if (facts.unsignedTxid != fundingTxid || facts.feeSat != minerFee) {
      _storage();
    }
    var outputs = 0;
    for (final output in facts.outputs) {
      if (bitcoinScriptAddress(output.scriptPubkey, network)
          case Ok(:final value) when value == address) {
        if (BigInt.from(output.valueSat) != gross) _storage();
        outputs++; // The exact funding vout must be unique, not guessed as zero.
      }
    }
    if (outputs != 1) _storage();
    return (
      operationId: binding.operationId,
      fundingTxid: binding.unsignedTxid,
      address: address,
      keypairIndex: index,
      expiryHeight: expiry,
      grossAmount: Sats(gross),
      netAmount: Sats(net),
    );
  });

  BigInt _boardSats(Object? value) {
    final amount = value is String ? BigInt.tryParse(value) : null;
    if (amount == null ||
        amount < BigInt.zero ||
        amount > BigInt.from(2100000000000000)) {
      _storage();
    }
    return amount;
  }

  /// A positive prepared/never-started journal plus an expired review, never
  /// an inference from native absence. The subsequent existing CAS rechecks the
  /// complete immutable binding and irreversible seal under source admission.
  @useResult
  Future<Result<bool, SyncFailure>> expiredUnsignedBoardReview(
    String operationId,
    DateTime now,
  ) async => _run(() {
    _inventory();
    final row = _operation(operationId);
    if (_state(row) != 'reserved' ||
        _authority(row)?['signing'] != 'never_started' ||
        row['signed_psbt'] != null) {
      return false;
    }
    final reviews = _db.select(
      'SELECT 1 FROM ark_board_reviews WHERE operation=?',
      [operationId],
    );
    if (reviews.isEmpty) return false; // Legacy has no positive Board review.
    final review = _boardReview(operationId);
    if (review['phase'] != 'prepared') return false;
    final binding = _binding(
      row,
    ); // Reapplies all unsigned/native-SegWit facts.
    final request = jsonDecode(binding.context);
    final payload = jsonDecode(review['payload'] as String);
    if (request is! Map<String, dynamic> ||
        payload is! Map<String, dynamic> ||
        request['version'] is! int ||
        (request['version'] != 1 && request['version'] != 2) ||
        request['account'] != binding.accountIdentity ||
        payload['request'] != binding.context ||
        request['validUntil'] is! String) {
      _storage();
    }
    final until = DateTime.tryParse(request['validUntil'] as String);
    if (until == null || !until.isUtc || !now.isUtc) _storage();
    return !now.isBefore(until);
  });

  /// A reserved Board that stopped before its review was saved: Ark never
  /// registered it, so it has no review, and signing needs one. It can never
  /// be signed, so holding its inputs protects nothing. The caller releases
  /// it through the same never-signed CAS, which loses to any signing-start.
  @useResult
  Future<Result<bool, SyncFailure>> unregisteredNeverSignedBoard(
    String operationId,
  ) async => _run(() {
    _inventory();
    final row = _operation(operationId);
    if (_isExitReserveContext(row['context']) ||
        _state(row) != 'reserved' ||
        _authority(row)?['signing'] != 'never_started' ||
        row['signed_psbt'] != null) {
      return false;
    }
    _binding(row); // Reapplies all unsigned/native-SegWit facts.
    return _db.select('SELECT 1 FROM ark_board_reviews WHERE operation=?', [
      operationId,
    ]).isEmpty;
  });

  /// CAS claims the one signer, and seals the source in the SAME transaction.
  @useResult
  Future<Result<void, SyncFailure>> admitBoardSigning({
    required ArkFundingBinding expected,
    required WalletRevision admittedRevision,
  }) async => _run(() {
    final row = _match(expected, admittedRevision);
    if (_isExitReserveContext(row['context']) ||
        _state(row) != 'reserved' ||
        _authority(row)?['signing'] != 'never_started' ||
        _boardReview(expected.operationId)['phase'] != 'prepared') {
      _refuse();
    }
    _db.execute(
      "UPDATE ark_funding_authority SET signing='started' WHERE operation=?",
      [expected.operationId],
    );
    _db.execute(
      "UPDATE ark_board_reviews SET phase='signing' WHERE operation=?",
      [expected.operationId],
    );
  }, write: true);

  @useResult
  Future<Result<void, SyncFailure>> advanceBoardDelivery(
    String operationId, {
    required String expectedPhase,
    required String nextPhase,
  }) async => _run(() {
    _inventory();
    final row = _operation(operationId);
    _binding(row);
    if (_state(row) != 'signed' ||
        row['signed_psbt'] is! String ||
        _authority(row)?['signing'] != 'started' ||
        _boardReview(operationId)['phase'] != expectedPhase ||
        !const {
          ('signing', 'signed'),
          ('signed', 'broadcasting'),
        }.contains((expectedPhase, nextPhase))) {
      _refuse();
    }
    _db.execute('UPDATE ark_board_reviews SET phase=? WHERE operation=?', [
      nextPhase,
      operationId,
    ]);
  }, write: true);

  @useResult
  Future<Result<void, SyncFailure>> finishBoardBroadcast(
    String operationId,
    SpendReceipt receipt,
  ) async => _run(() {
    _inventory();
    final row = _operation(operationId),
        binding = _binding(_operation(operationId));
    final phase = _boardReview(operationId)['phase'];
    if (!receipt.guarded ||
        !receipt.durable ||
        receipt.txid != binding.unsignedTxid ||
        _state(row) != 'signed' ||
        row['signed_psbt'] is! String ||
        _authority(row)?['signing'] != 'started' ||
        (phase != 'broadcasting' && phase != 'broadcast')) {
      _refuse();
    }
    _db.execute(
      "UPDATE ark_board_reviews SET phase='broadcast' WHERE operation=?",
      [operationId],
    );
  }, write: true);

  Row _boardReview(String operationId) {
    final rows = _db.select(
      'SELECT * FROM ark_board_reviews WHERE operation=?',
      [operationId],
    );
    if (rows.length != 1) _refuse();
    final row = rows.single;
    final payload = row['payload'], phase = row['phase'];
    if (payload is! String ||
        payload.isEmpty ||
        utf8.encode(payload).length > 8192 ||
        !const [
          'prepared',
          'signing',
          'signed',
          'broadcasting',
          'broadcast',
        ].contains(phase)) {
      _storage();
    }
    _reviewPayload(payload);
    return row;
  }

  void _reviewPayload(String payload) {
    try {
      if (jsonDecode(payload) is! Map<String, dynamic>) _storage();
    } on FormatException {
      _storage();
    }
  }

  static const _ordinaryDdl =
      'CREATE TABLE IF NOT EXISTS ark_ordinary_signing(network TEXT NOT NULL,txid TEXT NOT NULL,PRIMARY KEY(network,txid))';
  static const _boardDdl =
      "CREATE TABLE IF NOT EXISTS ark_board_reviews(operation TEXT PRIMARY KEY REFERENCES ark_funding_operations(operation),payload TEXT NOT NULL,phase TEXT NOT NULL CHECK(phase IN ('prepared','signing','signed','broadcasting','broadcast')))";
  static void _checkHostSchema(Database db) {
    for (final spec in const {
      'ark_ordinary_signing': [
        ('network', 'TEXT', 1, 1),
        ('txid', 'TEXT', 1, 2),
      ],
      'ark_board_reviews': [
        ('operation', 'TEXT', 0, 1),
        ('payload', 'TEXT', 1, 0),
        ('phase', 'TEXT', 1, 0),
      ],
    }.entries) {
      final columns = db.select('PRAGMA table_info(${spec.key})');
      if (columns.length != spec.value.length) throw const FormatException();
      for (var i = 0; i < columns.length; i++) {
        final expected = spec.value[i], actual = columns[i];
        if (actual['name'] != expected.$1 ||
            actual['type'] != expected.$2 ||
            actual['notnull'] != expected.$3 ||
            actual['pk'] != expected.$4) {
          throw const FormatException();
        }
      }
    }
  }

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
      if (value is Map<String, dynamic> && value['kind'] == 'neverPrepared') {
        return _neverPreparedProof(row, value);
      }
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

  bool _neverPreparedProof(Row row, Map<String, dynamic> receipt) {
    final request = _requestFacts(row);
    final admitted = receipt['admitted'];
    if (_state(row) != 'tombstoned' ||
        _authority(row)?['signing'] != 'tombstoned' ||
        receipt.length != 6 ||
        receipt['version'] is! int ||
        receipt['version'] != 1 ||
        receipt['closed'] != true ||
        receipt['signingBefore'] != 'never_started' ||
        jsonEncode(receipt['request']) != jsonEncode(_requestJson(request)) ||
        admitted is! Map<String, dynamic> ||
        admitted.length != 4 ||
        admitted['wallet'] != request.key.id ||
        admitted['network'] != _networkName(request.key) ||
        admitted['generation'] is! int ||
        admitted['generation'] != request.generation ||
        admitted['revision'] is! int ||
        (admitted['revision'] as int) < 0) {
      _storage();
    }
    return true;
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

/// Wallet-data-only journal: never exported through the Ark feature port.
final class ArkBoardJournalEntry {
  final ArkFundingBinding binding;
  final String payload;
  final String phase;
  final String? signedPsbt;
  const ArkBoardJournalEntry({
    required this.binding,
    required this.payload,
    required this.phase,
    required this.signedPsbt,
  });
}

/// Exact immutable request metadata; deliberately has no PSBT or unsigned txid.
/// Its data equality is checked again under the source-admitted SQL CAS.
typedef ArkFundingRequest = ({
  String operationId,
  String accountIdentity,
  Fingerprint sourceParent,
  WalletKey key,
  int generation,
  String context,
});

typedef ArkExitReserveRequest = ({
  String state,
  String? signedPsbt,
  String? txid,
  String context,
  bool confirmed,
});

/// Wallet-data evidence only; neither PSBTs nor a source signing capability.
typedef ArkNeverSignedBoardFacts = ({
  String operationId,
  String fundingTxid,
  String address,
  int keypairIndex,
  int expiryHeight,
  Sats grossAmount,
  Sats netAmount,
});
