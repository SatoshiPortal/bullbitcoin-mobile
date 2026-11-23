import 'dart:io';

import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'boltz_swaps_database.dart';

const _columns =
    'id,type,direction,status,is_testnet,key_index,creation_time,'
    'completion_time,receive_wallet_id,send_wallet_id,invoice,payment_address,'
    'payment_amount,receive_address,receive_txid,send_txid,preimage,'
    'refund_address,refund_txid,boltz_fees,lockup_fees,claim_fees,refund_fees,'
    'server_network_fees,was_direct_payment,recovered';
const _standaloneColumns =
    '$_columns,pending_lockup_tx,pending_lockup_txid,provider';
const _autoSwap = OwnerTableCopy(
  'auto_swap',
  'id,enabled,balance_threshold_sats,trigger_balance_sats,fee_threshold_percent,'
      'block_till_next_execution,always_block,recipient_wallet_id,show_warning',
  orderBy: 'id',
);

final class BoltzCutover {
  static int get schema => BoltzSwapsDatabase.schema;

  final File file;
  final File standalone;
  final bool regtest;
  final void Function(String message)? warning;
  final Future<Result<QueryExecutor, LegacyImportFailure>> Function() Function(
    bool existing,
  )
  executor;

  const BoltzCutover({
    required this.file,
    required this.standalone,
    required this.regtest,
    required this.executor,
    this.warning,
  });

  String get ownerId => regtest ? 'swaps_regtest' : 'swaps';

  LegacyImportParticipant get participant => ProjectedOwner(
    ownerId: ownerId,
    file: file,
    tables: regtest ? const [] : const [_autoSwap],
    open: _open,
    standalone: true,
    onRejected: _warnRejected,
    complete: (root, destination) => importStandaloneSource(
      standalone,
      destination,
      ownerId,
      (source) => _complete(
        regtest ? null : root,
        source,
        destination,
        seedAutoSwap: !regtest && root == null,
        reject: _reject,
      ),
      onRejected: _warnRejected,
    ),
  );

  void _warnRejected(String reason) =>
      warning?.call('storage.cutover.rejected owner=$ownerId reason=$reason');

  bool _reject(String reason) {
    _warnRejected(reason);
    return false;
  }

  Future<Result<OwnerDatabase<BoltzSwapsDatabase>, LegacyImportFailure>> open(
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

  Future<Result<OwnerDatabase<BoltzSwapsDatabase>, LegacyImportFailure>> _open(
    LifecycleAdmission admission, {
    required bool existing,
  }) => OwnerDatabase.open(
    admission: admission,
    openExecutor: executor(existing),
    create: BoltzSwapsDatabase.new,
  );
}

Future<bool> _complete(
  Database? root,
  Database? standalone,
  BoltzSwapsDatabase destination, {
  required bool seedAutoSwap,
  required bool Function(String) reject,
}) async {
  if (standalone != null) {
    final version = standalone.userVersion;
    if (version != 1 && version != 2) {
      return reject('standalone_schema_unsupported');
    }
    final projection = version == 1
        ? "$_columns,NULL,NULL,'boltz'"
        : _standaloneColumns;
    final swaps = OwnerTableCopy(
      'swaps',
      _standaloneColumns,
      orderBy: 'id',
      sourceQuery: 'SELECT $projection FROM swaps ORDER BY id',
    );
    const markers = OwnerTableCopy(
      'swap_data_migrations',
      'name,completed_at',
      orderBy: 'name',
    );
    if (!await swaps.copyAndVerify(standalone, destination) ||
        !await markers.copyAndVerify(standalone, destination)) {
      return reject('standalone_projection_mismatch');
    }
  }
  if (root == null) {
    if (seedAutoSwap) {
      for (final id in [1, 2]) {
        await destination
            .into(destination.autoSwap)
            .insert(
              AutoSwapCompanion.insert(
                id: Value(id),
                balanceThresholdSats: 250000,
                triggerBalanceSats: 500000,
                feeThresholdPercent: 1,
              ),
            );
      }
    }
    return true;
  }
  if (!await copySequence(root, destination, 'auto_swap')) {
    return reject('root_auto_swap_sequence_mismatch');
  }

  final historical = root.select('SELECT $_columns FROM swaps ORDER BY id');
  for (final row in historical) {
    final id = row['id'];
    Future<QueryRow?> current() => destination
        .customSelect(
          'SELECT $_columns FROM swaps WHERE id = ?',
          variables: [Variable(id as String)],
        )
        .getSingleOrNull();
    final existing = await current();
    if (existing != null) {
      // A later swap state is authoritative, but only for the same swap
      // identity. Never overwrite an existing signed/broadcast lockup.
      const identity = [
        'id',
        'type',
        'direction',
        'is_testnet',
        'key_index',
        'creation_time',
      ];
      if (identity.any((column) => row[column] != existing.data[column])) {
        return reject('root_swap_identity_mismatch');
      }
    } else {
      // The old receipt did not certify coverage: its importer could skip
      // incomplete rows, and older runtimes deleted expired recovery data.
      // Preserve the raw row without marking it usable or replacing live data.
      final values = row.values;
      final placeholders = List.filled(values.length, '?').join(',');
      await destination.customStatement(
        'INSERT INTO swaps ($_columns) VALUES ($placeholders)',
        values,
      );
      final copied = await current();
      if (copied == null ||
          !sameSqliteValues(values, copied.data.values.toList())) {
        return reject('root_swap_copy_mismatch');
      }
    }
  }
  return true;
}
