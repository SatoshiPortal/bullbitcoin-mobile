import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

/// Real durable host boundary for sync's admission tests. It deliberately
/// shares no native wallet DB or mutex with sync. Production ownership lives
/// in the host protocol, not in this package.
final class SqliteFundingReservations implements FundingReservationPort {
  final Database _db;
  Future<void> Function()? beforeReserve;
  SyncFailure? readFailure;
  bool failBeforeCommit = false;
  bool failAfterCommit = false;
  int calls = 0;

  SqliteFundingReservations(String path) : _db = sqlite3.open(path) {
    _db.execute('''
CREATE TABLE IF NOT EXISTS operations (
  protocol TEXT NOT NULL, session TEXT NOT NULL, wallet TEXT NOT NULL,
  network TEXT NOT NULL, generation INTEGER NOT NULL,
  encoded TEXT NOT NULL, txid TEXT NOT NULL, context TEXT NOT NULL,
  PRIMARY KEY(protocol, session))
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS inputs (
  txid TEXT NOT NULL, vout INTEGER NOT NULL,
  protocol TEXT NOT NULL, session TEXT NOT NULL,
  PRIMARY KEY(txid, vout))
''');
  }

  @override
  Future<Result<void, SyncFailure>> reserve({
    required WalletKey key,
    required UnsignedSpend spend,
    required String context,
  }) async {
    calls++;
    await beforeReserve?.call();
    final owner = spend.owner;
    final network = key.network;
    if (owner == null || key != spend.key || network is! BitcoinNetwork) {
      return const Err(SyncSpendRefusedFailure());
    }
    final decoded = decodeBitcoinPsbt(spend.encoded);
    if (decoded.inputs.length != spend.inputs.length ||
        !Iterable.generate(decoded.inputs.length)
            .every((index) => decoded.inputs[index] == spend.inputs[index])) {
      return const Err(SyncSpendRefusedFailure());
    }
    final txid = decoded.txid;
    _db.execute('BEGIN IMMEDIATE');
    try {
      final old = _db.select(
        'SELECT * FROM operations WHERE protocol=? AND session=?',
        [owner.protocol, owner.session],
      );
      if (old.isNotEmpty) {
        final row = old.single;
        final same =
            row['wallet'] == key.id &&
            row['network'] == network.name &&
            row['generation'] == spend.revision.generation &&
            row['encoded'] == spend.encoded &&
            row['txid'] == txid &&
            row['context'] == context;
        _db.execute('ROLLBACK');
        return same ? const Ok(null) : const Err(SyncSpendRefusedFailure());
      }
      for (final input in spend.inputs) {
        if (_db.select('SELECT 1 FROM inputs WHERE txid=? AND vout=?', [
          input.txId,
          input.vout,
        ]).isNotEmpty) {
          _db.execute('ROLLBACK');
          return const Err(SyncSpendRefusedFailure());
        }
      }
      _db.execute('INSERT INTO operations VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
        owner.protocol,
        owner.session,
        key.id,
        network.name,
        spend.revision.generation,
        spend.encoded,
        txid,
        context,
      ]);
      for (final input in spend.inputs) {
        _db.execute('INSERT INTO inputs VALUES (?, ?, ?, ?)', [
          input.txId,
          input.vout,
          owner.protocol,
          owner.session,
        ]);
      }
      if (failBeforeCommit) throw const FormatException('fixture storage');
      _db.execute('COMMIT');
    } on Exception {
      _db.execute('ROLLBACK');
      return const Err(SyncStorageFailure());
    }
    return failAfterCommit ? const Err(SyncStorageFailure()) : const Ok(null);
  }

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async {
    if (readFailure case final failure?) return Err(failure);
    final rows = _db.select('''
SELECT inputs.*, wallet, network FROM inputs JOIN operations
USING(protocol, session)
''');
    return Ok([
      for (final row in rows)
        InputReservation(
          outpoint: (txId: row['txid'] as String, vout: row['vout'] as int),
          protocol: row['protocol'] as String,
          session: row['session'] as String,
          walletId: row['wallet'] as String,
          network: BitcoinNetwork.values.byName(row['network'] as String),
          state: 'prepared',
        ),
    ]);
  }

  String? get encoded =>
      _db.select('SELECT encoded FROM operations').firstOrNull?['encoded']
          as String?;

  void close() => _db.close();
}
