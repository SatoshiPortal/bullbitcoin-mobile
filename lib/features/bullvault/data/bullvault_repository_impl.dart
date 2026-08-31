import 'dart:async';

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
  Future<void> _metadataLock = Future.value();

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
  ) => _withMetadataLock(() async {
    try {
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
      )) {
        return const Err(BullVaultRenewalFailure());
      }
      await _datasource.saveGenerationReservations(current.lineageId, {
        ...reservations,
        generation,
      });
      return Ok(generation);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to reserve the next BullVault generation',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  @override
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  }) => _withMetadataLock(() async {
    try {
      final reservations = await _datasource.loadGenerationReservations(
        lineageId,
      );
      if (!reservations.remove(generation)) return const Ok(null);
      await _datasource.saveGenerationReservations(lineageId, reservations);
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to release a BullVault generation',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) => _withMetadataLock(() async {
    try {
      var model = await _datasource.load(walletId);
      if (model != null) {
        await _repairInterruptedRestoredLink(model.lineageId);
        model = await _datasource.load(walletId);
      }
      return Ok(model == null ? null : _recordMapper.toEntity(model));
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to load BullVault metadata',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  @override
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  ) => _withMetadataLock(() async {
    try {
      await _repairInterruptedRestoredLink(lineageId);
      final records = await _datasource.loadLineage(lineageId);
      return Ok([for (final record in records) _recordMapper.toEntity(record)]);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to load BullVault lineage',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  ) async {
    try {
      final records = await _datasource.loadAll();
      final matches = records
          .map(_recordMapper.toEntity)
          .where(
            (record) =>
                record.vaultGeneration == 0 &&
                (record.status == BullVaultLifecycleStatus.pending ||
                    record.status == BullVaultLifecycleStatus.activating) &&
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
      _withMetadataLock(() async {
        try {
          final stored = await _datasource.load(record.walletId);
          if (stored != null) {
            final current = _recordMapper.toEntity(stored);
            if (!_canSaveLifecycleTransition(current.status, record.status)) {
              return const Err(BullVaultRenewalFailure());
            }
          }
          final lineage = await _datasource.loadLineage(record.lineageId);
          final otherRecords = lineage.where(
            (candidate) => candidate.walletId != record.walletId,
          );
          if (otherRecords.any(
                (candidate) =>
                    candidate.vaultGeneration == record.vaultGeneration,
              ) ||
              (record.status == BullVaultLifecycleStatus.active &&
                  otherRecords.any(
                    (candidate) =>
                        candidate.status ==
                        BullVaultLifecycleStatus.active.name,
                  ))) {
            return const Err(BullVaultRenewalFailure());
          }
          await _datasource.save(_recordMapper.toModel(record));
          return const Ok(null);
        } on Exception catch (error, stackTrace) {
          log.warning(
            'Failed to persist BullVault metadata',
            error: error.runtimeType,
            trace: stackTrace,
          );
          return const Err(BullVaultCreationFailure());
        }
      });

  bool _canSaveLifecycleTransition(
    BullVaultLifecycleStatus current,
    BullVaultLifecycleStatus next,
  ) =>
      current == next ||
      (current == BullVaultLifecycleStatus.pending &&
          next == BullVaultLifecycleStatus.activating) ||
      (current == BullVaultLifecycleStatus.activating &&
          (next == BullVaultLifecycleStatus.pending ||
              next == BullVaultLifecycleStatus.active)) ||
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
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) => _withMetadataLock(() async {
    try {
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
      if (currentReplacement.status != BullVaultLifecycleStatus.activating ||
          currentReplacement.previousVaultId != currentPrevious.walletId ||
          currentReplacement.lineageId != currentPrevious.lineageId ||
          currentReplacement.vaultGeneration <=
              currentPrevious.vaultGeneration ||
          (currentPrevious.status != BullVaultLifecycleStatus.active &&
              (currentPrevious.status != BullVaultLifecycleStatus.migrating ||
                  currentPrevious.successorWalletId !=
                      currentReplacement.walletId)) ||
          !currentReplacement.hardwareSetupComplete ||
          !currentReplacement.recoveryPackageConfirmed) {
        return const Err(BullVaultRenewalFailure());
      }
      final migrating = currentPrevious.copyWith(
        successorWalletId: currentReplacement.walletId,
        status: BullVaultLifecycleStatus.migrating,
      );
      final active = currentReplacement.copyWith(
        status: BullVaultLifecycleStatus.active,
      );
      await _datasource.save(_recordMapper.toModel(migrating));
      try {
        await _datasource.save(_recordMapper.toModel(active));
      } on Exception {
        await _datasource.save(_recordMapper.toModel(currentPrevious));
        rethrow;
      }
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to activate a BullVault renewal',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  @override
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  }) => _withMetadataLock(() async {
    try {
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
          (!isLinkedSuccessor && currentSuccessor.recoveryPackageConfirmed) ||
          currentSuccessor.recoveryPackage.policy.descriptor !=
              successor.recoveryPackage.policy.descriptor ||
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
      final migrating = currentPrevious.copyWith(
        successorWalletId: successor.walletId,
        status: BullVaultLifecycleStatus.migrating,
      );
      if (!isLinkedSuccessor) {
        await _datasource.save(_recordMapper.toModel(successor));
      }
      try {
        await _datasource.save(_recordMapper.toModel(migrating));
      } on Exception {
        if (!isLinkedSuccessor) {
          await _datasource.save(_recordMapper.toModel(currentSuccessor));
        }
        rethrow;
      }
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to link a restored BullVault renewal',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  @override
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
  }) => _withMetadataLock(() async {
    try {
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
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to cancel a BullVault renewal',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  });

  Future<void> _repairInterruptedRestoredLink(String lineageId) async {
    final lineage = [
      for (final model in await _datasource.loadLineage(lineageId))
        _recordMapper.toEntity(model),
    ];
    final active = lineage
        .where((record) => record.status == BullVaultLifecycleStatus.active)
        .toList();
    if (active.length <= 1) return;
    if (active.length != 2) {
      throw StateError('Multiple active BullVault generations');
    }
    final stagedSuccessors = active.where((successor) {
      final predecessors = active.where(
        (candidate) => candidate.walletId == successor.previousVaultId,
      );
      if (predecessors.length != 1 || !successor.recoveryPackageConfirmed) {
        return false;
      }
      final previous = predecessors.single;
      return successor.vaultGeneration > previous.vaultGeneration &&
          successor.mobileAccount == previous.mobileAccount &&
          successor.recoveryPackage.policy.hasSameSignerConfigurationAs(
            previous.recoveryPackage.policy,
          );
    }).toList();
    if (stagedSuccessors.length != 1) {
      throw StateError('Invalid active BullVault lineage');
    }
    final successor = stagedSuccessors.single;
    final previous = active.singleWhere(
      (candidate) => candidate.walletId == successor.previousVaultId,
    );
    await _datasource.save(
      _recordMapper.toModel(
        previous.copyWith(
          successorWalletId: successor.walletId,
          status: BullVaultLifecycleStatus.migrating,
        ),
      ),
    );
  }

  Future<T> _withMetadataLock<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _metadataLock;
    _metadataLock = completer.future;
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }

  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage) =>
      _recoveryPackageCodec.encode(recoveryPackage);
}
