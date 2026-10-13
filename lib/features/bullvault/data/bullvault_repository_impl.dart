import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bull_logger/bull_logger.dart';

final class BullVaultRepositoryImpl implements BullVaultRepository {
  final BullVaultMetadataDatasource _datasource;
  final BullVaultRecordMapper _recordMapper;
  final BullVaultRecoveryPackageCodec _recoveryPackageCodec;

  BullVaultRepositoryImpl(
    this._datasource,
    this._recordMapper,
    this._recoveryPackageCodec,
  );

  @override
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) {
    try {
      return Ok(_recoveryPackageCodec.decode(source));
    } on FormatException catch (error, stackTrace) {
      log.warning(
        'Invalid BullVault recovery package',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultInvalidRecoveryFailure());
    }
  }

  @override
  Future<Result<int, BullVaultFailure>> reserveNextGeneration(
    BullVaultRecord current,
  ) => _transaction(() async {
    final stored = await _datasource.load(current.walletId);
    if (stored == null || stored.lineageId != current.lineageId) {
      return const Err(BullVaultRenewalFailure());
    }
    final lineage = await _datasource.loadLineage(current.lineageId);
    final reservations = await _datasource.loadGenerationReservations(
      current.lineageId,
    );
    final latestGeneration =
        [
          ...lineage.map((record) => record.vaultGeneration),
          ...reservations,
        ].fold(
          current.vaultGeneration,
          (latest, generation) => generation > latest ? generation : latest,
        );
    final generation = latestGeneration + 1;
    final policy = current.recoveryPackage.policy;
    if (!BullVaultPolicy.isValidGeneration(
      generation,
      protection: policy.protection,
      includesInheritance: policy.inheritanceKey != null,
      includesLastResort: policy.lastResortActivationTimestamp != null,
    )) {
      return const Err(BullVaultRenewalFailure());
    }
    await _datasource.saveGenerationReservations(current.lineageId, {
      ...reservations,
      generation,
    });
    return Ok(generation);
  });

  @override
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  }) => _transaction(() async {
    final reservations = await _datasource.loadGenerationReservations(
      lineageId,
    );
    if (!reservations.remove(generation)) return const Ok(null);
    await _datasource.saveGenerationReservations(lineageId, reservations);
    return const Ok(null);
  });

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) => _transaction(() async {
    final model = await _datasource.load(walletId);
    if (model == null) return const Ok(null);
    return Ok(_recordMapper.toEntity(model));
  });

  @override
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  ) => _transaction(() async {
    final records = await _datasource.loadLineage(lineageId);
    return Ok(records.map(_recordMapper.toEntity).toList());
  });

  @override
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getWalletLineage(
    String walletId, {
    String? memberWalletId,
  }) => _transaction(() async {
    final model = await _datasource.load(walletId);
    if (model == null) return const Ok([]);
    if (memberWalletId != null && memberWalletId != walletId) {
      final member = await _datasource.load(memberWalletId);
      if (member?.lineageId != model.lineageId) return const Ok([]);
    }
    final records = await _datasource.loadLineage(model.lineageId);
    return Ok(records.map(_recordMapper.toEntity).toList());
  });

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  ) async {
    try {
      final records = await _datasource.loadPendingInitial();
      final matches = records
          .map(_recordMapper.toEntity)
          .where(
            (record) =>
                record.vaultGeneration == 0 &&
                record.status == BullVaultLifecycleStatus.pending &&
                record.recoveryPackage.policy.network == network,
          )
          .toList();
      if (matches.length > 1) {
        throw StateError('Multiple incomplete BullVault setups');
      }
      return Ok(matches.firstOrNull);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to load incomplete BullVault setup',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultCreationFailure());
    }
  }

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) =>
      _transaction(
        () => _save(record),
        failure: const BullVaultCreationFailure(),
      );

  Future<Result<void, BullVaultFailure>> _save(BullVaultRecord record) async {
    final stored = await _datasource.load(record.walletId);
    if (stored != null) {
      final current = _recordMapper.toEntity(stored);
      if (!_canSaveLifecycleTransition(current.status, record.status)) {
        return const Err(BullVaultRenewalFailure());
      }
      if (!await _canChangeLineage(current, record)) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
    }
    final lineage = await _datasource.loadLineage(record.lineageId);
    final otherRecords = lineage.where(
      (candidate) => candidate.walletId != record.walletId,
    );
    if (otherRecords.any(
          (candidate) => candidate.vaultGeneration == record.vaultGeneration,
        ) ||
        (record.status == BullVaultLifecycleStatus.active &&
            otherRecords.any(
              (candidate) =>
                  candidate.status == BullVaultLifecycleStatus.active.name,
            ))) {
      return const Err(BullVaultRenewalFailure());
    }
    await _datasource.save(_recordMapper.toModel(record));
    return const Ok(null);
  }

  Future<bool> _canChangeLineage(
    BullVaultRecord current,
    BullVaultRecord next,
  ) async {
    if (current.lineageId == next.lineageId) return true;
    final family = await _datasource.loadLineage(current.lineageId);
    final reservations = await _datasource.loadGenerationReservations(
      current.lineageId,
    );
    return family.every((member) => member.walletId == current.walletId) &&
        reservations.isEmpty;
  }

  @override
  Future<Result<void, BullVaultFailure>> publishRestored(
    BullVaultRecord record,
  ) => _transaction(() async {
    if (record.status != BullVaultLifecycleStatus.active) {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    final saved = await _save(record);
    if (saved case Err()) return saved;
    await _datasource.setWalletHidden(record.walletId, false);
    return const Ok(null);
  }, failure: const BullVaultInvalidRecoveryFailure());

  bool _canSaveLifecycleTransition(
    BullVaultLifecycleStatus current,
    BullVaultLifecycleStatus next,
  ) =>
      current == next ||
      (current == BullVaultLifecycleStatus.active &&
          next == BullVaultLifecycleStatus.migrating);

  @override
  Future<Result<void, BullVaultFailure>> delete(String walletId) async {
    try {
      await _datasource.delete(walletId);
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to delete BullVault metadata',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultCreationFailure());
    }
  }

  @override
  Future<Result<void, BullVaultFailure>> activateInitial(
    BullVaultRecord record,
  ) => _transaction(() async {
    final model = await _datasource.load(record.walletId);
    if (model == null) return const Err(BullVaultCreationFailure());
    final stored = _recordMapper.toEntity(model);
    if (stored.status == BullVaultLifecycleStatus.active) return const Ok(null);
    if (stored.status != BullVaultLifecycleStatus.pending ||
        stored.vaultGeneration != 0 ||
        !stored.recoveryPackageConfirmed ||
        (!record.hardwareSetupComplete && !record.hardwareSetupDeferred) ||
        !stored.completedHardwareSignerIds.containsAll(
          record.completedHardwareSignerIds,
        )) {
      return const Err(BullVaultCreationFailure());
    }
    await _datasource.save(
      _recordMapper.toModel(
        stored.copyWith(
          status: BullVaultLifecycleStatus.active,
          hardwareSetupComplete: record.hardwareSetupComplete,
          hardwareSetupDeferred: record.hardwareSetupDeferred,
          mobileBackupDeferred: record.mobileBackupDeferred,
        ),
      ),
    );
    await _datasource.setWalletHidden(record.walletId, false);
    return const Ok(null);
  }, failure: const BullVaultCreationFailure());

  @override
  Future<Result<Map<String, String>, BullVaultFailure>>
  getMigrationDestinations(Set<String> walletIds) => _transaction(
    () async => Ok(await _datasource.migrationDestinations(walletIds)),
  );

  @override
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) => _transaction(() async {
    final storedPrevious = await _datasource.load(previous.walletId);
    final storedReplacement = await _datasource.load(replacement.walletId);
    if (storedPrevious == null || storedReplacement == null) {
      return const Err(BullVaultRenewalFailure());
    }
    final currentPrevious = _recordMapper.toEntity(storedPrevious);
    final currentReplacement = _recordMapper.toEntity(storedReplacement);
    if (currentPrevious.status == BullVaultLifecycleStatus.migrating &&
        currentPrevious.successorWalletId == currentReplacement.walletId &&
        currentReplacement.status == BullVaultLifecycleStatus.active) {
      return const Ok(null);
    }
    if (currentReplacement.status != BullVaultLifecycleStatus.pending ||
        currentReplacement.previousVaultId != currentPrevious.walletId ||
        currentReplacement.lineageId != currentPrevious.lineageId ||
        currentReplacement.vaultGeneration <= currentPrevious.vaultGeneration ||
        (currentPrevious.status != BullVaultLifecycleStatus.active &&
            (currentPrevious.status != BullVaultLifecycleStatus.migrating ||
                currentPrevious.successorWalletId !=
                    currentReplacement.walletId)) ||
        !replacement.hardwareSetupComplete ||
        !currentReplacement.completedHardwareSignerIds.containsAll(
          replacement.completedHardwareSignerIds,
        ) ||
        !currentReplacement.recoveryPackageConfirmed) {
      return const Err(BullVaultRenewalFailure());
    }
    final migrating = currentPrevious.copyWith(
      successorWalletId: currentReplacement.walletId,
      status: BullVaultLifecycleStatus.migrating,
    );
    final active = currentReplacement.copyWith(
      status: BullVaultLifecycleStatus.active,
      hardwareSetupComplete: true,
    );
    await _datasource.save(_recordMapper.toModel(migrating));
    await _datasource.save(_recordMapper.toModel(active));
    await _datasource.setWalletHidden(previous.walletId, true);
    await _datasource.setWalletHidden(replacement.walletId, false);
    return const Ok(null);
  });

  @override
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  }) => _transaction(() async {
    final storedPrevious = await _datasource.load(previous.walletId);
    final storedSuccessor = await _datasource.load(successor.walletId);
    if (storedPrevious == null || storedSuccessor == null) {
      return const Err(BullVaultRenewalFailure());
    }
    final currentPrevious = _recordMapper.toEntity(storedPrevious);
    final currentSuccessor = _recordMapper.toEntity(storedSuccessor);
    final lineage = await _datasource.loadLineage(successor.lineageId);
    final isLinkedSuccessor =
        currentSuccessor.status == BullVaultLifecycleStatus.active &&
        currentSuccessor.recoveryPackageConfirmed &&
        currentSuccessor.lineageId == successor.lineageId &&
        currentSuccessor.previousVaultId == currentPrevious.walletId &&
        currentSuccessor.recoveryPackage.policy.descriptor ==
            successor.recoveryPackage.policy.descriptor;
    if (isLinkedSuccessor &&
        currentPrevious.status == BullVaultLifecycleStatus.migrating &&
        currentPrevious.successorWalletId == currentSuccessor.walletId) {
      return const Ok(null);
    }
    if (currentPrevious.status != BullVaultLifecycleStatus.active ||
        currentSuccessor.status != BullVaultLifecycleStatus.active ||
        !currentSuccessor.recoveryPackage.canBeEnrichedBy(
          successor.recoveryPackage,
        ) ||
        successor.status != BullVaultLifecycleStatus.active ||
        !successor.recoveryPackageConfirmed ||
        successor.previousVaultId != currentPrevious.walletId ||
        successor.lineageId != currentPrevious.lineageId ||
        successor.mobileAccount != currentPrevious.mobileAccount ||
        !successor.recoveryPackage.policy.hasSameSignerConfigurationAs(
          currentPrevious.recoveryPackage.policy,
        ) ||
        lineage.any(
          (candidate) =>
              candidate.walletId != successor.walletId &&
              candidate.vaultGeneration == successor.vaultGeneration,
        ) ||
        successor.vaultGeneration <= currentPrevious.vaultGeneration) {
      return const Err(BullVaultRenewalFailure());
    }
    if (!await _canChangeLineage(currentSuccessor, successor)) {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    final migrating = currentPrevious.copyWith(
      successorWalletId: successor.walletId,
      status: BullVaultLifecycleStatus.migrating,
    );
    if (!isLinkedSuccessor) {
      await _datasource.save(_recordMapper.toModel(successor));
    }
    await _datasource.save(_recordMapper.toModel(migrating));
    await _datasource.setWalletHidden(previous.walletId, true);
    await _datasource.setWalletHidden(successor.walletId, false);
    return const Ok(null);
  });

  @override
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
  }) => _transaction(() async {
    final storedPrevious = await _datasource.load(previousWalletId);
    final storedReplacement = await _datasource.load(replacementWalletId);
    if (storedPrevious == null || storedReplacement == null) {
      return const Err(BullVaultRenewalFailure());
    }
    final previous = _recordMapper.toEntity(storedPrevious);
    final replacement = _recordMapper.toEntity(storedReplacement);
    if (previous.status != BullVaultLifecycleStatus.active ||
        replacement.status != BullVaultLifecycleStatus.pending ||
        replacement.previousVaultId != previous.walletId ||
        replacement.lineageId != previous.lineageId ||
        replacement.vaultGeneration <= previous.vaultGeneration) {
      return const Err(BullVaultRenewalFailure());
    }
    await _datasource.save(
      _recordMapper.toModel(
        replacement.copyWith(status: BullVaultLifecycleStatus.cancelled),
      ),
    );
    return const Ok(null);
  });

  Future<Result<T, BullVaultFailure>> _transaction<T>(
    Future<Result<T, BullVaultFailure>> Function() action, {
    BullVaultFailure failure = const BullVaultRenewalFailure(),
  }) async {
    try {
      return await _datasource.transaction(action);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'BullVault persistence failed',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return Err(failure);
    }
  }

  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage) =>
      _recoveryPackageCodec.encode(recoveryPackage);
}
