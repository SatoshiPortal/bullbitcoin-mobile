import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'recoverbull_database.dart';

final class RecoverBullCutover {
  final File file;
  final File standalone;
  final bool regtest;

  const RecoverBullCutover({
    required this.file,
    required this.standalone,
    required this.regtest,
  });

  String get ownerId => regtest ? 'recoverbull_regtest' : 'recoverbull';

  LegacyImportParticipant get participant => ProjectedOwner(
    ownerId: ownerId,
    file: file,
    tables: const <OwnerTableCopy>[],
    open: _open,
    standalone: !regtest,
    onRejected: _warnRejected,
    complete: (_, destination) async {
      // Regtest deliberately starts with fresh settings and monitoring data.
      if (!regtest &&
          !await importStandaloneSource(standalone, destination, ownerId, (
            source,
          ) async {
            if (source == null) return true;
            if (source.userVersion != 1) {
              return _reject('standalone_schema_unsupported');
            }
            for (final table in _tables) {
              if (!await table.copyAndVerify(source, destination)) {
                return _reject('standalone_projection_mismatch');
              }
            }
            for (final table in [
              'recoverbull_own_operations',
              'recoverbull_alerts',
            ]) {
              if (!await copySequence(source, destination, table)) {
                return _reject('standalone_sequence_mismatch');
              }
            }
            return true;
          }, onRejected: _warnRejected)) {
        return false;
      }
      final states = await destination
          .select(destination.recoverbullState)
          .get();
      if (states.length > 1 || states.any((state) => state.id != 1)) {
        return _reject('invalid_state');
      }
      if (states.isEmpty) {
        await destination
            .into(destination.recoverbullState)
            .insert(const RecoverbullStateCompanion(id: Value(1)));
      }
      return true;
    },
  );

  void _warnRejected(String reason) =>
      log.warning('storage.cutover.rejected owner=$ownerId reason=$reason');

  bool _reject(String reason) {
    _warnRejected(reason);
    return false;
  }

  Future<Result<OwnerDatabase<RecoverBullDatabase>, LegacyImportFailure>> open(
    RuntimeAdmission admission,
  ) => _openReady(admission);

  Future<Result<OwnerDatabase<RecoverBullDatabase>, LegacyImportFailure>>
  openForInventory(ExclusiveAdmission admission) => _openReady(admission);

  Future<Result<OwnerDatabase<RecoverBullDatabase>, LegacyImportFailure>>
  _openReady(LifecycleAdmission admission) async {
    final opened = await _open(admission, existing: true);
    if (opened case Ok(:final value)) {
      final readiness = await ownerReadiness(
        value.database,
        ownerId,
        standalone: !regtest,
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

  Future<Result<OwnerDatabase<RecoverBullDatabase>, LegacyImportFailure>> _open(
    LifecycleAdmission admission, {
    required bool existing,
  }) => OwnerDatabase.open(
    admission: admission,
    openExecutor: Secrets.databaseOpener<LegacyImportFailure>(
      module: ownerId,
      name: 'main',
      file: file,
      schema: RecoverBullDatabase.schema,
      deferred: const LegacyImportDeferred(),
      unavailable: const LegacyImportUnavailable(),
    )(existing),
    create: RecoverBullDatabase.new,
  );
}

const _tables = [
  // The old configuration URL is not selected. The historical permission
  // column remains intact until Preferences takes over its live access.
  OwnerTableCopy(
    'recoverbull_state',
    'id,permission_granted,monitoring_enabled,legacy_import_complete,'
        'monitoring_revision,generation',
    orderBy: 'id',
    sourceQuery:
        'SELECT id,permission_granted,monitoring_enabled,legacy_import_complete,'
        'monitoring_revision,generation FROM recoverbull_state ORDER BY id',
  ),
  OwnerTableCopy(
    'recoverbull_backup_status',
    'network,fingerprint,vault_digest,stored_at,verified_at',
    orderBy: 'network,fingerprint,vault_digest',
  ),
  OwnerTableCopy(
    'recoverbull_monitored_vaults',
    'server,digest,anchor_requests,observed_requests,window,collection,'
        'exact_window,own_requests,unknown',
    orderBy: 'server,digest',
  ),
  OwnerTableCopy(
    'recoverbull_own_operations',
    'id,server,digest',
    orderBy: 'id',
  ),
  OwnerTableCopy(
    'recoverbull_alerts',
    'id,server,digest,window,kind,acknowledged',
    orderBy: 'id',
  ),
];
