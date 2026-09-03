import 'dart:async';

import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_key_service.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CreateBullVaultUsecase {
  final BullVaultRepository _repository;
  final BitcoinDescriptorPort _descriptorPort;
  final BullVaultKeyService _keyService;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final Bip48AccountRepository _bip48AccountRepository;
  final PrepareBullVaultTimeReferenceUsecase _prepareTimeReferenceUsecase;
  static Future<void> _creationLock = Future.value();

  CreateBullVaultUsecase(
    this._repository,
    this._descriptorPort,
    this._getDefaultSeedUsecase,
    this._getSettingsUsecase,
    this._deleteWalletUsecase,
    this._bip48AccountRepository,
    this._prepareTimeReferenceUsecase,
  ) : _keyService = BullVaultKeyService(_descriptorPort);

  @useResult
  Future<Result<BullVaultCreateResult, BullVaultFailure>> execute(
    BullVaultCreateRequest request,
  ) => _serialized(() => _execute(request));

  Future<Result<BullVaultCreateResult, BullVaultFailure>> _execute(
    BullVaultCreateRequest request,
  ) async {
    Wallet? importedWallet;
    Bip48AccountClaim? accountClaim;
    String? seedFingerprint;
    int? coinType;
    var accountCommitted = false;
    var keepAccountReserved = false;
    try {
      final settings = await _getSettingsUsecase.execute();
      final network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
      if (request.label.trim().isEmpty) {
        return const Err(BullVaultCreationFailure());
      }
      switch (await _repository.getIncompleteInitial(network)) {
        case Ok(value: null):
          break;
        case Ok():
          return const Err(BullVaultCreationFailure());
        case Err(:final failure):
          return Err(failure);
      }
      if (!request.schedule.isValid(
            protection: request.protection,
            includesInheritance: request.inheritance != null,
          ) ||
          request.protection.usesTwoColdKeys != (request.secondCold != null)) {
        return const Err(BullVaultInvalidScheduleFailure());
      }
      final timeReferenceResult = await _prepareTimeReferenceUsecase.execute(
        isTestnet: network.isTestnet,
      );
      late final BullVaultTimeReference timeReference;
      switch (timeReferenceResult) {
        case Ok(:final value):
          if (!request.timeReference.isFreshComparedTo(value)) {
            return const Err(BullVaultReviewExpiredFailure());
          }
          if (!request.schedule.activatesAfterChainTime(
            referenceTime: request.timeReference.deviceTime,
            medianTimePast: value.medianTimePast,
            protection: request.protection,
            includesInheritance: request.inheritance != null,
          )) {
            return const Err(BullVaultClockMismatchFailure());
          }
          timeReference = request.timeReference;
        case Err(:final failure):
          return Err(failure);
      }

      coinType = network.coinType;
      late final BullVaultSignerKey everyday;
      BullVaultSignerKey? delayedMobileRecovery;
      int? mobileAccount;
      String? mobileSeedFingerprint;
      if (request.everydayKeySource == BullVaultEverydayKeySource.bullMobile) {
        if (request.everydayHardware != null ||
            (request.passphraseFreeRecovery &&
                (request.mobilePassphrase?.isEmpty ?? true))) {
          return const Err(BullVaultInvalidSignerFailure());
        }
        final storedSeed = await _getDefaultSeedUsecase.execute(
          environment: settings.environment,
        );
        final canonicalSeed = _keyService.canonicalSeed(storedSeed);
        if (canonicalSeed == null) {
          return const Err(BullVaultCreationFailure());
        }
        seedFingerprint = canonicalSeed.masterFingerprint;
        mobileSeedFingerprint = canonicalSeed.masterFingerprint;
        switch (await _bip48AccountRepository.claimNext(
          seedFingerprint: canonicalSeed.masterFingerprint,
          coinType: network.coinType,
        )) {
          case Ok(:final value):
            accountClaim = value;
            mobileAccount = value.account;
          case Err():
            return const Err(BullVaultCreationFailure());
        }
        final mobileSeed = _keyService.seedWithPassphrase(
          canonicalSeed,
          request.mobilePassphrase,
        );
        if (mobileSeed == null) {
          return const Err(BullVaultCreationFailure());
        }
        final everydayResult = _keyService.localKey(
          mobileSeed,
          mobileAccount,
          network,
          role: BullVaultSignerRole.everyday,
          requiresPassphrase: request.mobilePassphrase?.isNotEmpty == true,
        );
        switch (everydayResult) {
          case Ok(:final value):
            everyday = value;
          case Err(:final failure):
            return Err(failure);
        }
        if (request.passphraseFreeRecovery) {
          final recoveryResult = _keyService.localKey(
            canonicalSeed,
            mobileAccount,
            network,
            role: BullVaultSignerRole.delayedMobileRecovery,
          );
          switch (recoveryResult) {
            case Ok(:final value):
              delayedMobileRecovery = value;
            case Err(:final failure):
              return Err(failure);
          }
        }
      } else {
        final hardware = request.everydayHardware;
        if (hardware == null ||
            request.mobilePassphrase != null ||
            request.passphraseFreeRecovery) {
          return const Err(BullVaultInvalidSignerFailure());
        }
        final everydayResult = _keyService.externalKey(
          hardware,
          BullVaultSignerRole.everyday,
          network: network,
        );
        switch (everydayResult) {
          case Ok(:final value):
            everyday = value;
          case Err(:final failure):
            return Err(failure);
        }
      }

      final coldResult = _keyService.externalKey(
        request.cold,
        BullVaultSignerRole.cold,
        network: network,
      );
      late final BullVaultSignerKey cold;
      switch (coldResult) {
        case Ok(:final value):
          cold = value;
        case Err(:final failure):
          return Err(failure);
      }

      BullVaultSignerKey? secondCold;
      if (request.secondCold case final secondColdRequest?) {
        final secondColdResult = _keyService.externalKey(
          secondColdRequest,
          BullVaultSignerRole.secondCold,
          network: network,
        );
        switch (secondColdResult) {
          case Ok(:final value):
            secondCold = value;
          case Err(:final failure):
            return Err(failure);
        }
      }

      BullVaultSignerKey? inheritance;
      if (request.inheritance case final inheritanceRequest?) {
        final inheritanceResult = _keyService.externalKey(
          inheritanceRequest,
          BullVaultSignerRole.inheritance,
          network: network,
        );
        switch (inheritanceResult) {
          case Ok(:final value):
            inheritance = value;
          case Err(:final failure):
            return Err(failure);
        }
      }

      if (BullVaultPolicy.reusesSignerKey([
        everyday,
        ?delayedMobileRecovery,
        cold,
        ?secondCold,
        ?inheritance,
      ])) {
        return const Err(BullVaultSignerReuseFailure());
      }

      final template = BullVaultPolicy.descriptorTemplate(
        vaultGeneration: 0,
        network: network,
        protection: request.protection,
        everydayKey: everyday,
        delayedMobileRecoveryKey: delayedMobileRecovery,
        coldKey: cold,
        secondColdKey: secondCold,
        inheritanceKey: inheritance,
        schedule: request.schedule,
        referenceTime: timeReference.deviceTime,
      );
      final parsed = _descriptorPort.parseBitcoinDescriptor(
        descriptor: template,
        network: network,
      );
      final policy = BullVaultPolicy.build(
        vaultGeneration: 0,
        network: network,
        descriptor: parsed.descriptor,
        protection: request.protection,
        everydayKey: everyday,
        delayedMobileRecoveryKey: delayedMobileRecovery,
        coldKey: cold,
        secondColdKey: secondCold,
        inheritanceKey: inheritance,
        schedule: request.schedule,
        timeReference: timeReference,
      );
      final signerAnnotations = BullVaultSignerKey.assignDescriptorKeys(
        parsed.descriptorKeys,
        [everyday, ?delayedMobileRecovery, cold, ?secondCold, ?inheritance],
        localSeedFingerprint: mobileSeedFingerprint,
      );
      if (signerAnnotations == null) {
        return const Err(BullVaultCreationFailure());
      }

      final wallet = await _descriptorPort.importDescriptor(
        descriptor: parsed.descriptor,
        network: network,
        label: request.label.trim(),
        signers: signerAnnotations,
        isHidden: true,
      );
      importedWallet = wallet;
      final recoveryPackage = BullVaultRecoveryPackage(
        previousVaultId: null,
        policy: policy,
      );
      final record = BullVaultRecord(
        walletId: wallet.id,
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: mobileAccount,
        mobileSeedFingerprint: mobileSeedFingerprint,
        birthHeight: timeReference.chainHeight,
        recoveryPackage: recoveryPackage,
        previousVaultId: null,
        successorWalletId: null,
        status: BullVaultLifecycleStatus.pending,
        hardwareSetupComplete: false,
        recoveryPackageConfirmed: false,
        createdAt: timeReference.deviceTime,
      );
      final saved = await _repository.save(record);
      if (saved case Err(:final failure)) {
        keepAccountReserved = !await _rollback(wallet.id);
        return Err(failure);
      }
      final claim = accountClaim;
      if (claim != null) {
        final reserved = await _bip48AccountRepository.commitClaim(
          seedFingerprint: mobileSeedFingerprint!,
          coinType: network.coinType,
          claim: claim,
        );
        if (reserved case Err()) {
          final metadataDeleted = await _repository.delete(wallet.id);
          if (metadataDeleted case Err(:final failure)) {
            keepAccountReserved = true;
            log.severe(
              message: 'Failed to roll back BullVault metadata',
              error: failure.runtimeType,
              trace: StackTrace.current,
            );
          } else {
            keepAccountReserved = !await _rollback(wallet.id);
          }
          return const Err(BullVaultCreationFailure());
        }
        accountCommitted = true;
      }
      return Ok(BullVaultCreateResult(wallet: wallet, record: record));
    } on Exception catch (error, stackTrace) {
      if (importedWallet case final wallet?) {
        keepAccountReserved = !await _rollback(wallet.id);
      }
      log.warning(
        'BullVault creation failed',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultCreationFailure());
    } finally {
      final claim = accountClaim;
      final fingerprint = seedFingerprint;
      final networkCoinType = coinType;
      if (!accountCommitted &&
          claim != null &&
          fingerprint != null &&
          networkCoinType != null) {
        if (keepAccountReserved) {
          final committed = await _bip48AccountRepository.commitClaim(
            seedFingerprint: fingerprint,
            coinType: networkCoinType,
            claim: claim,
          );
          if (committed case Err(:final failure)) {
            log.severe(
              message: 'Failed to preserve a BullVault BIP48 account',
              error: failure.runtimeType,
              trace: StackTrace.current,
            );
          }
        } else {
          final released = await _bip48AccountRepository.releaseClaim(
            seedFingerprint: fingerprint,
            coinType: networkCoinType,
            claim: claim,
          );
          if (released case Err()) {
            log.warning('Failed to release an unused BIP48 account claim');
          }
        }
      }
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _creationLock;
    _creationLock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  Future<bool> _rollback(String walletId) async {
    try {
      await _deleteWalletUsecase.execute(walletId: walletId);
      return true;
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to roll back incomplete BullVault creation',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return false;
    }
  }
}
