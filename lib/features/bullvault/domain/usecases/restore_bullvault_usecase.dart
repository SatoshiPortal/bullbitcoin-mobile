import 'dart:async';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bip48_account_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

enum BullVaultRestoreInputKind { recoveryPackage, descriptor }

class RestoreBullVaultUsecase {
  final BullVaultRepository _repository;
  final BitcoinDescriptorPort _descriptorPort;
  final BullVaultDescriptorService _descriptorService;
  final GetSettingsUsecase _getSettingsUsecase;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final GetAllSeedsUsecase _getAllSeedsUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final ReserveBip48AccountUsecase _reserveBip48AccountUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final SetWalletHiddenUsecase _setWalletHiddenUsecase;
  final WalletSignerOwnershipPort _walletSignerOwnershipPort;
  static Future<void> _restoreLock = Future.value();

  RestoreBullVaultUsecase(
    this._repository,
    this._descriptorPort,
    this._descriptorService,
    this._getSettingsUsecase,
    this._getDefaultSeedUsecase,
    this._getWalletUsecase,
    this._reserveBip48AccountUsecase,
    this._deleteWalletUsecase,
    this._setWalletHiddenUsecase,
    this._walletSignerOwnershipPort,
    this._getAllSeedsUsecase,
  );

  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>> execute({
    required BullVaultRestoreInputKind kind,
    required String source,
    required String label,
    String? mobilePassphrase,
  }) => _serialized(
    () => _execute(
      kind: kind,
      source: source,
      label: label,
      mobilePassphrase: mobilePassphrase,
    ),
  );

  Future<Result<BullVaultRestoreResult, BullVaultFailure>> _execute({
    required BullVaultRestoreInputKind kind,
    required String source,
    required String label,
    required String? mobilePassphrase,
  }) async {
    if (source.trim().isEmpty || label.trim().isEmpty) {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    Wallet? importedWallet;
    var importedNewWallet = false;
    var shouldMarkEverydaySignerLocal = false;
    String? importedSeedFingerprint;
    int? importedCoinType;
    int? importedMobileAccount;

    Future<void> rollbackImportedWallet() async {
      final wallet = importedWallet;
      if (wallet == null || !importedNewWallet) return;
      try {
        await _deleteWalletUsecase.execute(walletId: wallet.id);
      } on Exception catch (error, stackTrace) {
        log.severe(
          message: 'Failed to roll back BullVault restoration',
          error: error.runtimeType,
          trace: stackTrace,
        );
        final fingerprint = importedSeedFingerprint;
        final coinType = importedCoinType;
        final account = importedMobileAccount;
        if (fingerprint == null || coinType == null || account == null) return;
        final reserved = await _reserveBip48AccountUsecase.execute(
          seedFingerprint: fingerprint,
          coinType: coinType,
          account: account,
        );
        if (reserved case Err(:final failure)) {
          log.severe(
            message: 'Failed to preserve a restored BullVault BIP48 account',
            error: failure.runtimeType,
            trace: StackTrace.current,
          );
        }
      }
    }

    try {
      final settings = await _getSettingsUsecase.execute();
      final network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
      final packageResult = kind == BullVaultRestoreInputKind.recoveryPackage
          ? _repository.decodeRecoveryPackage(source)
          : null;
      final BullVaultRecoveryPackage decodedPackage;
      if (packageResult != null) {
        switch (packageResult) {
          case Ok(:final value):
            decodedPackage = value;
          case Err(:final failure):
            return Err(failure);
        }
      } else {
        final policy = _descriptorService.recognizeStructure(source, network);
        if (policy == null) {
          return const Err(BullVaultInvalidRecoveryFailure());
        }
        decodedPackage = BullVaultRecoveryPackage(policy: policy);
      }
      final seed = await _getDefaultSeedUsecase.execute(
        environment: settings.environment,
      );
      Seed? verifiedSeed;
      var policy = decodedPackage.policy.withEverydayOwnership(
        SignerEntity.none,
      );
      var matchesPassphrase = mobilePassphrase?.isNotEmpty != true;
      void verifySeed(Seed candidate) {
        if (mobilePassphrase?.isNotEmpty == true) {
          if (!_descriptorService.matchesEverydaySeed(
            decodedPackage.policy,
            candidate,
            passphrase: mobilePassphrase,
          )) {
            return;
          }
          matchesPassphrase = true;
        }
        final verified = _descriptorService.withVerifiedMobileSeed(
          decodedPackage.policy,
          candidate,
          passphrase: mobilePassphrase,
        );
        if (verified != null) {
          verifiedSeed = candidate;
          policy = verified;
        }
      }

      verifySeed(seed);
      if (verifiedSeed == null) {
        switch (await _getAllSeedsUsecase.execute()) {
          case Err():
            return const Err(BullVaultInvalidRecoveryFailure());
          case Ok(:final value):
            for (final candidate in value) {
              verifySeed(candidate);
              if (verifiedSeed != null) break;
            }
        }
      }
      if (!matchesPassphrase) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      final package = BullVaultRecoveryPackage(
        previousVaultId: decodedPackage.previousVaultId,
        policy: policy,
      );
      if (policy.network != network ||
          !_descriptorService.matchesPolicyDescriptor(policy) ||
          (policy.vaultGeneration == 0 && package.previousVaultId != null) ||
          (policy.vaultGeneration > 0 &&
              policy.hasKnownOriginalSchedule &&
              package.previousVaultId == null)) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      final mobileAccount = policy.everydayKey.signer == SignerEntity.local
          ? Bip48Derivation.account(
              policy.everydayKey.accountKey.derivationPath,
              coinType: network.coinType,
            )
          : null;
      final mobileSeedFingerprint = mobileAccount == null
          ? null
          : _descriptorService.canonicalSeedFingerprint(verifiedSeed!);
      importedSeedFingerprint = mobileSeedFingerprint;
      importedCoinType = mobileAccount == null ? null : network.coinType;
      importedMobileAccount = mobileAccount;
      final parsed = _descriptorPort.parseBitcoinDescriptor(
        descriptor: policy.descriptor,
        network: network,
      );
      final annotations =
          BullVaultSignerKey.assignDescriptorKeys(parsed.descriptorKeys, [
            policy.everydayKey,
            ?policy.delayedMobileRecoveryKey,
            policy.coldKey,
            ?policy.secondColdKey,
            ?policy.inheritanceKey,
          ], localSeedFingerprint: mobileSeedFingerprint);
      if (annotations == null) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      try {
        importedWallet = await _descriptorPort.importDescriptor(
          descriptor: parsed.descriptor,
          network: network,
          label: label.trim(),
          signers: annotations,
          isHidden: true,
        );
        importedNewWallet = true;
      } on WalletAlreadyExistsException catch (error) {
        importedWallet = await _getWalletUsecase.execute(error.walletId);
        if (importedWallet == null ||
            !_descriptorService.matchesExistingWalletConfiguration(
              importedWallet,
              policy,
            )) {
          return const Err(BullVaultInvalidRecoveryFailure());
        }
        if (policy.everydayKey.signer == SignerEntity.local) {
          shouldMarkEverydaySignerLocal = !_descriptorService
              .matchesEverydaySignerOwnership(importedWallet, policy);
        } else if (!_descriptorService.matchesExistingWallet(
          importedWallet,
          policy,
        )) {
          return const Err(BullVaultInvalidRecoveryFailure());
        }
      }
      var wallet = importedWallet;
      final existingRecord = await _repository.getByWalletId(wallet.id);
      switch (existingRecord) {
        case Ok(value: final existing?):
          if (existing.status != BullVaultLifecycleStatus.active ||
              existing.recoveryPackage.policy.descriptor != policy.descriptor) {
            await rollbackImportedWallet();
            return const Err(BullVaultInvalidRecoveryFailure());
          }
          var restoredRecord = existing;
          var shouldSaveRestoredRecord = false;
          BullVaultRecord? predecessorToLink;
          if (kind == BullVaultRestoreInputKind.recoveryPackage) {
            if (!existing.recoveryPackage.canBeEnrichedBy(package)) {
              return const Err(BullVaultInvalidRecoveryFailure());
            }
            if (existing.recoveryPackageConfirmed &&
                _repository.encodeRecoveryPackage(existing.recoveryPackage) ==
                    _repository.encodeRecoveryPackage(package)) {
              final predecessorResult = await _validatedLocalPredecessor(
                package: package,
                successorWalletId: wallet.id,
              );
              switch (predecessorResult) {
                case Err(:final failure):
                  return Err(failure);
                case Ok(:final value):
                  predecessorToLink = value;
              }
            } else {
              final predecessorResult = await _validatedLocalPredecessor(
                package: package,
                successorWalletId: wallet.id,
              );
              late final BullVaultRecord? predecessor;
              switch (predecessorResult) {
                case Err(:final failure):
                  return Err(failure);
                case Ok(:final value):
                  predecessor = value;
              }
              final activeRecords = await _otherActiveRecords(
                lineageId: policy.lineageId,
                walletId: wallet.id,
              );
              switch (activeRecords) {
                case Err(:final failure):
                  return Err(failure);
                case Ok(:final value):
                  final canLinkPredecessor =
                      value.length == 1 &&
                      predecessor?.status == BullVaultLifecycleStatus.active &&
                      value.single.walletId == predecessor?.walletId;
                  if (value.isNotEmpty && !canLinkPredecessor) {
                    return const Err(BullVaultInvalidRecoveryFailure());
                  }
                  if (canLinkPredecessor) predecessorToLink = predecessor;
              }
              restoredRecord = BullVaultRecord(
                walletId: wallet.id,
                lineageId: policy.lineageId,
                vaultGeneration: policy.vaultGeneration,
                mobileAccount: mobileAccount,
                mobileSeedFingerprint: mobileSeedFingerprint,
                birthHeight: policy.birthHeight,
                recoveryPackage: package,
                previousVaultId: package.previousVaultId,
                successorWalletId: existing.successorWalletId,
                status: existing.status,
                hardwareSetupComplete: existing.hardwareSetupComplete,
                hardwareSetupDeferred: existing.hardwareSetupDeferred,
                completedHardwareSignerIds: existing.completedHardwareSignerIds,
                recoveryPackageConfirmed: true,
                mobileBackupDeferred: existing.mobileBackupDeferred,
                createdAt: policy.createdAt ?? existing.createdAt,
              );
              shouldSaveRestoredRecord = true;
            }
          }
          if (shouldMarkEverydaySignerLocal) {
            wallet = await _markEverydaySignerLocal(
              wallet,
              policy,
              seedFingerprint: mobileSeedFingerprint!,
            );
            if (!_descriptorService.matchesEverydaySignerOwnership(
              wallet,
              policy,
            )) {
              return const Err(BullVaultInvalidRecoveryFailure());
            }
          }
          if (mobileAccount != null && restoredRecord.mobileAccount == null) {
            final restoredPolicy = restoredRecord.recoveryPackage.policy
                .withEverydayOwnership(
                  SignerEntity.local,
                  requiresPassphrase:
                      policy.everydayKey.accountKey.requiresPassphrase,
                );
            restoredRecord = BullVaultRecord(
              walletId: restoredRecord.walletId,
              lineageId: restoredRecord.lineageId,
              vaultGeneration: restoredRecord.vaultGeneration,
              mobileAccount: mobileAccount,
              mobileSeedFingerprint: mobileSeedFingerprint,
              birthHeight: restoredRecord.birthHeight,
              recoveryPackage: BullVaultRecoveryPackage(
                previousVaultId: restoredRecord.recoveryPackage.previousVaultId,
                policy: restoredPolicy,
              ),
              previousVaultId: restoredRecord.previousVaultId,
              successorWalletId: restoredRecord.successorWalletId,
              status: restoredRecord.status,
              hardwareSetupComplete: restoredRecord.hardwareSetupComplete,
              hardwareSetupDeferred: restoredRecord.hardwareSetupDeferred,
              completedHardwareSignerIds:
                  restoredRecord.completedHardwareSignerIds,
              recoveryPackageConfirmed: restoredRecord.recoveryPackageConfirmed,
              mobileBackupDeferred: restoredRecord.mobileBackupDeferred,
              createdAt: restoredRecord.createdAt,
            );
            shouldSaveRestoredRecord = true;
          }
          if (restoredRecord.mobileAccount != null &&
              restoredRecord.mobileSeedFingerprint != null) {
            final reserved = await _reserveBip48AccountUsecase.execute(
              seedFingerprint: restoredRecord.mobileSeedFingerprint!,
              coinType: network.coinType,
              account: restoredRecord.mobileAccount!,
            );
            if (reserved case Err()) {
              return const Err(BullVaultInvalidRecoveryFailure());
            }
          }
          if (shouldSaveRestoredRecord) {
            final saved = predecessorToLink == null
                ? await _repository.save(restoredRecord)
                : await _repository.linkRestoredRenewal(
                    previous: predecessorToLink,
                    successor: restoredRecord,
                  );
            switch (saved) {
              case Ok():
                break;
              case Err(:final failure):
                return Err(failure);
            }
          }
          if (wallet.isHidden) {
            await _setWalletHiddenUsecase.execute(
              walletId: wallet.id,
              isHidden: false,
            );
          }
          final linkedPredecessor = predecessorToLink;
          if (linkedPredecessor != null) {
            await _setWalletHiddenUsecase.execute(
              walletId: linkedPredecessor.walletId,
              isHidden: true,
            );
          }
          return Ok(
            BullVaultRestoreResult(wallet: wallet, record: restoredRecord),
          );
        case Err(:final failure):
          await rollbackImportedWallet();
          return Err(failure);
        case Ok(value: null):
          break;
      }
      final activeRecords = await _otherActiveRecords(
        lineageId: policy.lineageId,
        walletId: wallet.id,
      );
      switch (activeRecords) {
        case Err(:final failure):
          await rollbackImportedWallet();
          return Err(failure);
        case Ok(:final value):
          if (value.isNotEmpty) {
            await rollbackImportedWallet();
            return const Err(BullVaultInvalidRecoveryFailure());
          }
      }
      final predecessorResult = await _validatedLocalPredecessor(
        package: package,
        successorWalletId: wallet.id,
      );
      switch (predecessorResult) {
        case Err(:final failure):
          await rollbackImportedWallet();
          return Err(failure);
        case Ok(value: final predecessor?)
            when predecessor.status == BullVaultLifecycleStatus.active:
          await rollbackImportedWallet();
          return const Err(BullVaultInvalidRecoveryFailure());
        case Ok():
          break;
      }
      if (shouldMarkEverydaySignerLocal) {
        wallet = await _markEverydaySignerLocal(
          wallet,
          policy,
          seedFingerprint: mobileSeedFingerprint!,
        );
        if (!_descriptorService.matchesEverydaySignerOwnership(
          wallet,
          policy,
        )) {
          await rollbackImportedWallet();
          return const Err(BullVaultInvalidRecoveryFailure());
        }
      }
      final restoredPackage = BullVaultRecoveryPackage(
        previousVaultId: package.previousVaultId,
        policy: policy,
      );
      final record = BullVaultRecord(
        walletId: wallet.id,
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: mobileAccount,
        mobileSeedFingerprint: mobileSeedFingerprint,
        birthHeight: policy.birthHeight,
        recoveryPackage: restoredPackage,
        previousVaultId: package.previousVaultId,
        status: BullVaultLifecycleStatus.active,
        hardwareSetupComplete: false,
        recoveryPackageConfirmed:
            kind == BullVaultRestoreInputKind.recoveryPackage,
        createdAt: DateTime.now().toUtc(),
      );
      switch (await _repository.save(record)) {
        case Ok():
          break;
        case Err(:final failure):
          await rollbackImportedWallet();
          return Err(failure);
      }
      final reservation = mobileAccount == null || mobileSeedFingerprint == null
          ? null
          : await _reserveBip48AccountUsecase.execute(
              seedFingerprint: mobileSeedFingerprint,
              coinType: network.coinType,
              account: mobileAccount,
            );
      if (reservation case Err()) {
        final metadataDeleted = await _repository.delete(wallet.id);
        switch (metadataDeleted) {
          case Ok():
            await rollbackImportedWallet();
          case Err(:final failure):
            log.severe(
              message: 'Failed to roll back BullVault metadata',
              error: failure.runtimeType,
              trace: StackTrace.current,
            );
        }
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      importedNewWallet = false;
      await _setWalletHiddenUsecase.execute(
        walletId: wallet.id,
        isHidden: false,
      );
      return Ok(BullVaultRestoreResult(wallet: wallet, record: record));
    } on Exception catch (error, stackTrace) {
      await rollbackImportedWallet();
      log.warning(
        'Failed to restore BullVault',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultInvalidRecoveryFailure());
    }
  }

  Future<Wallet> _markEverydaySignerLocal(
    Wallet wallet,
    BullVaultPolicy policy, {
    required String seedFingerprint,
  }) async {
    final everydayXpub = _canonicalXpub(policy.everydayKey.accountKey.xpub);
    final matchingSigners = wallet.signers.where(
      (signer) => signer.descriptorKeys.any(
        (key) => _canonicalXpub(key.xpub) == everydayXpub,
      ),
    );
    if (matchingSigners.length != 1) {
      throw const WalletSignerOwnershipUpdateException();
    }
    final signer = matchingSigners.single;
    if (signer.signer == SignerEntity.local) return wallet;
    final passphraseProtectedKeyIds =
        policy.everydayKey.accountKey.requiresPassphrase
        ? {
            for (final key in signer.descriptorKeys)
              if (_canonicalXpub(key.xpub) == everydayXpub) key.id,
          }
        : const <String>{};
    return _walletSignerOwnershipPort.markSignerLocal(
      walletId: wallet.id,
      signerId: signer.id,
      seedFingerprint: seedFingerprint,
      passphraseProtectedKeyIds: passphraseProtectedKeyIds,
    );
  }

  String _canonicalXpub(String xpub) =>
      Bip32Derivation.getBip32Xpub(xpub).toBase58();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _restoreLock;
    _restoreLock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  Future<Result<List<BullVaultRecord>, BullVaultFailure>> _otherActiveRecords({
    required String lineageId,
    required String walletId,
  }) async {
    final lineage = await _repository.getLineage(lineageId);
    return switch (lineage) {
      Ok(:final value) => Ok(
        value
            .where(
              (record) =>
                  record.walletId != walletId &&
                  record.status == BullVaultLifecycleStatus.active,
            )
            .toList(),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<BullVaultRecord?, BullVaultFailure>>
  _validatedLocalPredecessor({
    required BullVaultRecoveryPackage package,
    required String successorWalletId,
  }) async {
    final predecessorId = package.previousVaultId;
    if (predecessorId == null) return const Ok(null);
    final policy = package.policy;
    final mobileAccount = policy.everydayKey.signer == SignerEntity.local
        ? Bip48Derivation.account(
            policy.everydayKey.accountKey.derivationPath,
            coinType: policy.network.coinType,
          )
        : null;
    final result = await _repository.getByWalletId(predecessorId);
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Ok(null),
      Ok(value: final predecessor?) =>
        predecessor.lineageId != policy.lineageId ||
                predecessor.vaultGeneration >= policy.vaultGeneration ||
                predecessor.mobileAccount != mobileAccount ||
                !predecessor.recoveryPackage.policy
                    .hasSameSignerConfigurationAs(policy) ||
                switch (predecessor.status) {
                  BullVaultLifecycleStatus.active => false,
                  BullVaultLifecycleStatus.migrating =>
                    predecessor.successorWalletId != successorWalletId,
                  _ => true,
                }
            ? const Err(BullVaultInvalidRecoveryFailure())
            : Ok(predecessor),
    };
  }
}
