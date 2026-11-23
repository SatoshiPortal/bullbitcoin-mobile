import 'dart:io';

import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show Database, ResultSet, Row;

import 'payjoin_database.dart';
import 'payjoin_migration.dart';
import 'payjoin_policy_store.dart';
import '../domain/payjoin_ports.dart';

const _senders =
    'uri,is_testnet,sender,wallet_id,original_psbt,original_tx_id,'
    'amount_sat,created_at,expire_after_sec,proposal_psbt,tx_id,is_expired,'
    'is_completed';
const _receivers =
    'id,address,is_testnet,receiver,wallet_id,pj_uri,max_fee_rate_sat_per_vb,'
    'created_at,expire_after_sec,original_tx_bytes,original_tx_id,amount_sat,'
    'proposal_psbt,tx_id,is_expired,is_completed';
const _version3Sender = '($_unfinished AND is_aborted = 0)';
const _unfinished = 'is_expired = 0 AND is_completed = 0';
const _policies =
    'id,enabled,send_enabled,buy_enabled,sell_enabled,minimum_amount_sat,'
    'session_lifetime_seconds';

/// A payjoin file's owner configuration. The supplied executor is keyed in
/// the worker by the host without exposing any keys to Payjoin.
final class PayjoinCutover {
  final File file;
  final File standalone;
  final bool regtest;
  final void Function(String message)? warning;
  final Future<Result<QueryExecutor, LegacyImportFailure>> Function() Function(
    bool existing,
  )
  executor;

  const PayjoinCutover({
    required this.file,
    required this.standalone,
    required this.regtest,
    required this.executor,
    this.warning,
  });

  String get ownerId => regtest ? 'payjoin_regtest' : 'payjoin';

  static int get schema => PayjoinDatabase.schema;

  LegacyImportParticipant get participant => ProjectedOwner(
    ownerId: ownerId,
    file: file,
    tables: const <OwnerTableCopy>[],
    open: _open,
    standalone: true,
    onRejected: _warnRejected,
    complete: (root, destination) => importStandaloneSource(
      standalone,
      destination,
      ownerId,
      (source) => _complete(regtest ? null : root, source, destination, this),
      onRejected: _warnRejected,
    ),
  );

  void _warnRejected(String reason) =>
      warning?.call('storage.cutover.rejected owner=$ownerId reason=$reason');

  bool _reject(String reason) {
    _warnRejected(reason);
    return false;
  }

  Future<Result<OwnerDatabase<PayjoinDatabase>, LegacyImportFailure>> open(
    RuntimeAdmission admission,
  ) async {
    final opened = await _open(admission, existing: true);
    if (opened case Ok(:final value)) {
      final readiness = await ownerReadiness(
        value.database,
        ownerId,
        standalone: true,
      );
      if (readiness case Ok(
        value: OwnerReadiness.imported || OwnerReadiness.initialized,
      )) {
        return opened;
      }
      await value.handle.close();
      if (readiness case Err(:final failure)) return Err(failure);
      return const Err(LegacyImportDeferred());
    }
    return opened;
  }

  Future<Result<OwnerDatabase<PayjoinDatabase>, LegacyImportFailure>> _open(
    LifecycleAdmission admission, {
    required bool existing,
  }) => OwnerDatabase.open(
    admission: admission,
    openExecutor: executor(existing),
    create: PayjoinDatabase.fromExecutor,
  );
}

Future<bool> _complete(
  Database? root,
  Database? standalone,
  PayjoinDatabase destination,
  PayjoinCutover cutover,
) async {
  final version = standalone?.userVersion;
  if (standalone != null) {
    if (version != 1 && version != 2 && version != 3) {
      return cutover._reject('standalone_schema_unsupported');
    }
    final networkEvidence = version == 3
        ? 'has_network_evidence'
        : _version3Sender;
    final trade = version == 1 ? '0' : 'is_trade';
    final policies = version == 1
        ? 'id,enabled,enabled,1,1,minimum_amount_sat,session_lifetime_seconds'
        : _policies;
    for (final table in [
      OwnerTableCopy(
        'payjoin_senders',
        '$_senders,is_aborted,has_network_evidence',
        orderBy: 'uri',
        sourceQuery:
            'SELECT $_senders,is_aborted,$networkEvidence FROM payjoin_senders ORDER BY uri',
      ),
      OwnerTableCopy(
        'payjoin_receivers',
        '$_receivers,is_aborted,is_trade',
        orderBy: 'id',
        sourceQuery:
            'SELECT $_receivers,is_aborted,$trade FROM payjoin_receivers ORDER BY id',
      ),
      OwnerTableCopy(
        'payjoin_policies',
        _policies,
        orderBy: 'id',
        sourceQuery: 'SELECT $policies FROM payjoin_policies ORDER BY id',
      ),
      const OwnerTableCopy(
        'payjoin_migrations',
        'name,completed_at,source_schema_version,sender_count,receiver_count,'
            'verification_digest',
        orderBy: 'name',
      ),
    ]) {
      if (!await table.copyAndVerify(standalone, destination)) {
        return cutover._reject('standalone_projection_mismatch');
      }
    }
  }

  if (root != null && !await _reconcileRoot(root, destination, cutover)) {
    return false;
  }
  final policies = await destination.select(destination.payjoinPolicies).get();
  if (policies.isEmpty) {
    await PayjoinPolicyStore(destination).ensureDefaults();
  }
  final policy = await destination.select(destination.payjoinPolicies).get();
  return (policy.length == 1 && policy.single.id == 1) ||
      cutover._reject('invalid_policy');
}

Future<bool> _reconcileRoot(
  Database root,
  PayjoinDatabase destination,
  PayjoinCutover cutover,
) async {
  final marker = await (destination.select(
    destination.payjoinMigrations,
  )..where((row) => row.name.equals('root-payjoin-v1'))).getSingleOrNull();
  if (marker == null) {
    // With no prior receipt there is no authoritative interpretation of a
    // conflicting row. Merge disjoint IDs and accept an existing ID only
    // when its complete projected values match.
    const senderCopy = OwnerTableCopy(
      'payjoin_senders',
      '$_senders,is_aborted,has_network_evidence',
      orderBy: 'uri',
      mergeBy: 'uri',
      sourceQuery:
          'SELECT $_senders,0,($_unfinished) FROM payjoin_senders ORDER BY uri',
    );
    const receiverCopy = OwnerTableCopy(
      'payjoin_receivers',
      '$_receivers,is_aborted,is_trade',
      orderBy: 'id',
      mergeBy: 'id',
      sourceQuery: 'SELECT $_receivers,0,0 FROM payjoin_receivers ORDER BY id',
    );
    var skippedSenders = 0;
    var skippedReceivers = 0;
    if (!await senderCopy.copyAndVerify(
      root,
      destination,
      filter: (rows) {
        final accepted = _validRootRows(rows, 'uri');
        skippedSenders = rows.length - accepted.length;
        return accepted;
      },
    )) {
      return cutover._reject('root_sender_conflict');
    }
    if (!await receiverCopy.copyAndVerify(
      root,
      destination,
      filter: (rows) {
        final accepted = _validRootRows(rows, 'id');
        skippedReceivers = rows.length - accepted.length;
        return accepted;
      },
    )) {
      return cutover._reject('root_receiver_conflict');
    }
    if (skippedSenders != 0 || skippedReceivers != 0) {
      await destination.customStatement(
        'INSERT INTO legacy_import_receipts (id) VALUES (?)',
        ['root-payjoin-quarantine/${skippedSenders}s/${skippedReceivers}r'],
      );
      cutover.warning?.call(
        'storage.cutover.root_payjoin_quarantined '
        'senders=$skippedSenders receivers=$skippedReceivers',
      );
    }
    return true;
  }

  // The published receipt was computed after quarantine. Verify exactly that
  // subset before trusting the standalone file as the runtime's authority.
  final senders = _validRootRows(
    root.select('SELECT $_senders FROM payjoin_senders ORDER BY uri'),
    'uri',
  );
  final receivers = _validRootRows(
    root.select('SELECT $_receivers FROM payjoin_receivers ORDER BY id'),
    'id',
  );
  if (senders.length != marker.senderCount ||
      receivers.length != marker.receiverCount) {
    return cutover._reject('root_receipt_count_mismatch');
  }
  final snapshot = PayjoinLegacySnapshot(
    sourceSchemaVersion: root.userVersion,
    senders: [
      for (final row in senders)
        PayjoinLegacySender(
          uri: row['uri'] as String,
          isTestnet: row['is_testnet'] == 1,
          protocolState: row['sender'] as String,
          walletId: row['wallet_id'] as String,
          originalPsbt: row['original_psbt'] as String,
          originalTransactionId: row['original_tx_id'] as String,
          amountSat: row['amount_sat'] as int,
          createdAt: row['created_at'] as int,
          expireAfterSec: row['expire_after_sec'] as int,
          proposalPsbt: row['proposal_psbt'] as String?,
          transactionId: row['tx_id'] as String?,
          isExpired: row['is_expired'] == 1,
          isCompleted: row['is_completed'] == 1,
        ),
    ],
    receivers: [
      for (final row in receivers)
        PayjoinLegacyReceiver(
          id: row['id'] as String,
          address: row['address'] as String,
          isTestnet: row['is_testnet'] == 1,
          protocolState: row['receiver'] as String,
          walletId: row['wallet_id'] as String,
          payjoinUri: row['pj_uri'] as String,
          maximumFeeRateSatPerVbyte: BigInt.from(
            row['max_fee_rate_sat_per_vb'] as int,
          ),
          createdAt: row['created_at'] as int,
          expireAfterSec: row['expire_after_sec'] as int,
          originalTransaction: row['original_tx_bytes'] as Uint8List?,
          originalTransactionId: row['original_tx_id'] as String?,
          amountSat: row['amount_sat'] as int?,
          proposalPsbt: row['proposal_psbt'] as String?,
          transactionId: row['tx_id'] as String?,
          isExpired: row['is_expired'] == 1,
          isCompleted: row['is_completed'] == 1,
        ),
    ],
  );
  if (legacyPayjoinSnapshotDigest(snapshot) != marker.verificationDigest) {
    return cutover._reject('root_receipt_digest_mismatch');
  }
  for (final row in senders) {
    final current =
        await (destination.select(destination.payjoinSenders)
              ..where((table) => table.uri.equals(row['uri'] as String)))
            .getSingleOrNull();
    if (current == null) return cutover._reject('root_sender_missing');
    if (current.isTestnet != (row['is_testnet'] == 1) ||
        current.walletId != row['wallet_id'] ||
        current.originalTxId != row['original_tx_id'] ||
        current.createdAt != row['created_at']) {
      return cutover._reject('root_sender_identity_mismatch');
    }
  }
  for (final row in receivers) {
    final current =
        await (destination.select(destination.payjoinReceivers)
              ..where((table) => table.id.equals(row['id'] as String)))
            .getSingleOrNull();
    if (current == null) {
      // Match deleteIdleReceiver. Historical root rows had no is_aborted
      // column and were imported as un-aborted. Never resurrect this session.
      if (row['original_tx_bytes'] == null &&
          row['proposal_psbt'] == null &&
          row['is_completed'] == 0) {
        continue;
      }
      return cutover._reject('root_receiver_missing');
    }
    if (current.isTestnet != (row['is_testnet'] == 1) ||
        current.walletId != row['wallet_id'] ||
        current.address != row['address'] ||
        current.createdAt != row['created_at']) {
      return cutover._reject('root_receiver_identity_mismatch');
    }
  }
  return true;
}

List<Row> _validRootRows(ResultSet rows, String idColumn) {
  final seen = <String>{};
  return [
    for (final row in rows)
      if (isValidLegacyPayjoinSession(
        row[idColumn] as String,
        row['wallet_id'] as String,
        row['expire_after_sec'] as int,
        seen,
      ))
        row,
  ];
}
