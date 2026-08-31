import 'dart:async';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class RenewBullVaultUsecase {
  final BullVaultRepository _repository;
  final BitcoinDescriptorPort _descriptorPort;
  final GetWalletUsecase _getWalletUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final ResumeBullVaultRenewalUsecase _resumeBullVaultRenewalUsecase;
  final PrepareBullVaultTimeReferenceUsecase _prepareTimeReferenceUsecase;
  Future<void> _renewalLock = Future.value();

  RenewBullVaultUsecase(
    this._repository,
    this._descriptorPort,
    this._getWalletUsecase,
    this._deleteWalletUsecase,
    this._resumeBullVaultRenewalUsecase,
    this._prepareTimeReferenceUsecase,
  );

  @useResult
  Future<Result<BullVaultRenewResult, BullVaultFailure>> execute(
    BullVaultRenewRequest request,
  ) => _serialized(() => _execute(request));

  Future<Result<BullVaultRenewResult, BullVaultFailure>> _execute(
    BullVaultRenewRequest request,
  ) async {
    Wallet? importedWallet;
    BullVaultRecord? current;
    int? reservedGeneration;
    try {
      if (request.label.trim().isEmpty) {
        return const Err(BullVaultRenewalFailure());
      }
      switch (await _resumeBullVaultRenewalUsecase.execute(request.walletId)) {
        case Ok(value: final renewal?):
          return Ok(renewal);
        case Ok(value: null):
          break;
        case Err(:final failure):
          return Err(failure);
      }
      final currentResult = await _repository.getByWalletId(request.walletId);
      late final BullVaultRecord loadedCurrent;
      switch (currentResult) {
        case Ok(value: final record?):
          loadedCurrent = record;
        case Ok(value: null):
          return const Err(BullVaultRenewalFailure());
        case Err(:final failure):
          return Err(failure);
      }
      current = loadedCurrent;
      if (current.status != BullVaultLifecycleStatus.active &&
          current.status != BullVaultLifecycleStatus.migrating) {
        return const Err(BullVaultRenewalFailure());
      }
      final currentWallet = await _getWalletUsecase.execute(current.walletId);
      if (currentWallet == null) {
        return const Err(BullVaultRenewalFailure());
      }
      final currentRecovery = current.recoveryPackage;
      if (currentRecovery.policy.lineageId != current.lineageId ||
          currentRecovery.policy.vaultGeneration != current.vaultGeneration ||
          currentRecovery.policy.descriptor != currentWallet.publicDescriptor) {
        return const Err(BullVaultRenewalFailure());
      }
      if (current.status == BullVaultLifecycleStatus.migrating) {
        return const Err(BullVaultRenewalFailure());
      }
      if (!request.schedule.isValid(
        protection: currentRecovery.policy.protection,
        includesInheritance: currentRecovery.policy.inheritanceKey != null,
      )) {
        return const Err(BullVaultRenewalFailure());
      }
      final timeReferenceResult = await _prepareTimeReferenceUsecase.execute(
        isTestnet: currentRecovery.policy.network.isTestnet,
      );
      late final BullVaultTimeReference timeReference;
      switch (timeReferenceResult) {
        case Ok(:final value):
          if (!request.timeReference.isFreshComparedTo(value)) {
            return const Err(BullVaultReviewExpiredFailure());
          }
          timeReference = request.timeReference;
        case Err(:final failure):
          return Err(failure);
      }

      final everyday = _signerKey(
        currentWallet,
        currentRecovery.policy.everydayKey,
      );
      final cold = _signerKey(currentWallet, currentRecovery.policy.coldKey);
      final secondCold = currentRecovery.policy.secondColdKey == null
          ? null
          : _signerKey(currentWallet, currentRecovery.policy.secondColdKey!);
      final inheritance = currentRecovery.policy.inheritanceKey == null
          ? null
          : _signerKey(currentWallet, currentRecovery.policy.inheritanceKey!);
      if (BullVaultPolicy.reusesSignerKey([
        everyday,
        cold,
        ?secondCold,
        ?inheritance,
      ])) {
        return const Err(BullVaultSignerReuseFailure());
      }

      final generationResult = await _repository.reserveNextGeneration(current);
      late final int generation;
      switch (generationResult) {
        case Ok(:final value):
          generation = value;
          reservedGeneration = value;
        case Err(:final failure):
          return Err(failure);
      }
      final template = BullVaultPolicy.descriptorTemplate(
        vaultGeneration: generation,
        network: currentRecovery.policy.network,
        protection: currentRecovery.policy.protection,
        everydayKey: everyday,
        coldKey: cold,
        secondColdKey: secondCold,
        inheritanceKey: inheritance,
        schedule: request.schedule,
        referenceTime: timeReference.deviceTime,
      );
      final parsed = _descriptorPort.parseBitcoinDescriptor(
        descriptor: template,
        network: currentRecovery.policy.network,
      );
      final policy = BullVaultPolicy.build(
        lineageId: current.lineageId,
        vaultGeneration: generation,
        network: currentRecovery.policy.network,
        descriptor: parsed.descriptor,
        protection: currentRecovery.policy.protection,
        everydayKey: everyday,
        coldKey: cold,
        secondColdKey: secondCold,
        inheritanceKey: inheritance,
        schedule: request.schedule,
        timeReference: timeReference,
      );
      final annotations = _signerAnnotations(parsed.descriptorKeys, [
        everyday,
        cold,
        ?secondCold,
        ?inheritance,
      ]);
      if (annotations == null) {
        await _releaseGeneration(current, generation);
        return const Err(BullVaultRenewalFailure());
      }

      importedWallet = await _descriptorPort.importDescriptor(
        descriptor: parsed.descriptor,
        network: policy.network,
        label: request.label.trim(),
        signers: annotations,
        isHidden: true,
      );
      final recovery = BullVaultRecoveryPackage(
        previousVaultId: current.walletId,
        policy: policy,
      );
      final replacement = BullVaultRecord(
        walletId: importedWallet.id,
        lineageId: current.lineageId,
        vaultGeneration: generation,
        mobileAccount: current.mobileAccount,
        birthHeight: timeReference.chainHeight,
        recoveryPackage: recovery,
        previousVaultId: current.walletId,
        successorWalletId: null,
        status: BullVaultLifecycleStatus.pending,
        hardwareSetupComplete: false,
        recoveryPackageConfirmed: false,
        createdAt: timeReference.deviceTime,
      );
      final saved = await _repository.save(replacement);
      if (saved case Err(:final failure)) {
        if (await _rollback(importedWallet.id)) {
          await _releaseGeneration(current, generation);
        }
        return Err(failure);
      }
      reservedGeneration = null;
      final created = BullVaultCreateResult(
        wallet: importedWallet,
        policy: policy,
        record: replacement,
        recoveryPackage: recovery,
      );
      return Ok(BullVaultRenewResult(previous: current, replacement: created));
    } on Exception catch (error, stackTrace) {
      var rolledBack = true;
      if (importedWallet case final wallet?) {
        rolledBack = await _rollback(wallet.id);
      }
      final generation = reservedGeneration;
      final loadedCurrent = current;
      if (rolledBack && generation != null && loadedCurrent != null) {
        await _releaseGeneration(loadedCurrent, generation);
      }
      log.warning(
        'BullVault renewal failed',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultRenewalFailure());
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _renewalLock;
    _renewalLock = completer.future;
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }

  BullVaultSignerKey _signerKey(
    Wallet wallet,
    BullVaultSignerKey policySigner,
  ) {
    final signer = wallet.signers.singleWhere(
      (value) => value.descriptorKeys.any(
        (key) => _sameXpub(key.xpub, policySigner.accountKey.xpub),
      ),
    );
    final accountKey = signer.descriptorKeys.firstWhere(
      (key) => _sameXpub(key.xpub, policySigner.accountKey.xpub),
    );
    return BullVaultSignerKey(
      role: policySigner.role,
      accountKey: WalletDescriptorKey(
        id: '${policySigner.role.name}-account',
        signerId: policySigner.role.name,
        masterFingerprint: accountKey.masterFingerprint,
        xpubFingerprint: accountKey.xpubFingerprint,
        xpub: accountKey.xpub,
        derivationPath: accountKey.derivationPath,
      ),
      signer: signer.signer,
      signerDevice: signer.signerDevice,
    );
  }

  List<WalletSigner>? _signerAnnotations(
    List<WalletDescriptorKey> descriptorKeys,
    List<BullVaultSignerKey> signers,
  ) {
    final annotations = <WalletSigner>[];
    for (final signer in signers) {
      final keys = [
        for (final key in descriptorKeys)
          if (_sameXpub(key.xpub, signer.accountKey.xpub))
            key.copyWith(signerId: signer.role.name),
      ];
      if (keys.isEmpty) return null;
      annotations.add(
        WalletSigner(
          id: signer.role.name,
          signer: signer.signer,
          signerDevice: signer.signerDevice,
          descriptorKeys: keys,
        ),
      );
    }
    return annotations;
  }

  bool _sameXpub(String first, String second) =>
      Bip32Derivation.getBip32Xpub(first).toBase58() ==
      Bip32Derivation.getBip32Xpub(second).toBase58();

  Future<bool> _rollback(String walletId) async {
    try {
      await _deleteWalletUsecase.execute(walletId: walletId);
      return true;
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to roll back incomplete BullVault renewal',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _releaseGeneration(
    BullVaultRecord current,
    int generation,
  ) async {
    final released = await _repository.releaseGeneration(
      lineageId: current.lineageId,
      generation: generation,
    );
    if (released case Err(:final failure)) {
      log.severe(
        message: 'Failed to release an unused BullVault generation',
        error: failure.runtimeType,
        trace: StackTrace.current,
      );
    }
  }
}
