import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:convert/convert.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CreateBullVaultUsecase {
  static const _fixedNumsInternalKey =
      '0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';
  final BullVaultRepository _repository;
  final BitcoinDescriptorPort _descriptorPort;
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
  );

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
          timeReference = request.timeReference;
        case Err(:final failure):
          return Err(failure);
      }

      final seed = await _getDefaultSeedUsecase.execute(
        environment: settings.environment,
      );
      seedFingerprint = seed.masterFingerprint;
      coinType = network.coinType;
      late final int mobileAccount;
      switch (await _bip48AccountRepository.claimNext(
        seedFingerprint: seed.masterFingerprint,
        coinType: network.coinType,
      )) {
        case Ok(:final value):
          accountClaim = value;
          mobileAccount = value.account;
        case Err():
          return const Err(BullVaultCreationFailure());
      }
      final everydayResult = _localEverydayKey(seed, mobileAccount, network);
      late final BullVaultSignerKey everyday;
      switch (everydayResult) {
        case Ok(:final value):
          everyday = value;
        case Err(:final failure):
          return Err(failure);
      }

      final coldResult = _externalKey(
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
        final secondColdResult = _externalKey(
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
        final inheritanceResult = _externalKey(
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
        coldKey: cold,
        secondColdKey: secondCold,
        inheritanceKey: inheritance,
        schedule: request.schedule,
        timeReference: timeReference,
      );
      final signerAnnotations = _signerAnnotations(parsed.descriptorKeys, [
        everyday,
        cold,
        ?secondCold,
        ?inheritance,
      ]);
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
      final reserved = await _bip48AccountRepository.commitClaim(
        seedFingerprint: seed.masterFingerprint,
        coinType: network.coinType,
        claim: accountClaim,
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
      return Ok(
        BullVaultCreateResult(
          wallet: wallet,
          policy: policy,
          record: record,
          recoveryPackage: recoveryPackage,
        ),
      );
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
    return previous
        .catchError((_) {})
        .then((_) => action())
        .whenComplete(completer.complete);
  }

  Result<BullVaultSignerKey, BullVaultFailure> _localEverydayKey(
    Seed seed,
    int account,
    Network network,
  ) {
    try {
      final derivationPath = Bip48Derivation.path(
        coinType: network.coinType,
        account: account,
      );
      final xpub = Bip32Derivation.deriveXpub(
        seedBytes: seed.bytes,
        derivationPath: derivationPath,
        network: network,
      );
      return Ok(
        BullVaultSignerKey(
          role: BullVaultSignerRole.everyday,
          accountKey: WalletDescriptorKey(
            id: 'everyday-account',
            signerId: 'everyday',
            masterFingerprint: seed.masterFingerprint.toLowerCase(),
            xpubFingerprint: Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
            xpub: xpub,
            derivationPath: derivationPath,
          ),
          signer: SignerEntity.local,
          signerDevice: null,
        ),
      );
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to derive the BullVault mobile key',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return const Err(BullVaultCreationFailure());
    }
  }

  Result<BullVaultSignerKey, BullVaultFailure> _externalKey(
    BullVaultSignerRequest request,
    BullVaultSignerRole role, {
    required Network network,
  }) {
    if (request.genericExternal) {
      if (request.device != null) {
        return const Err(BullVaultInvalidSignerFailure());
      }
    } else if (request.device?.supportsComplexTaprootRegistration != true) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    return _parseAccountKey(
      request.input,
      role: role,
      network: network,
      signer: SignerEntity.remote,
      signerDevice: request.device,
    );
  }

  Result<BullVaultSignerKey, BullVaultFailure> _parseAccountKey(
    String input, {
    required BullVaultSignerRole role,
    required Network network,
    required SignerEntity signer,
    required SignerDeviceEntity? signerDevice,
  }) {
    final normalized = input.trim();
    if (normalized.isEmpty ||
        normalized.contains('*') ||
        normalized.contains('<') ||
        normalized.contains('(')) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    try {
      final synthetic = 'tr($_fixedNumsInternalKey,pk($normalized/<0;1>/*))';
      final parsed = _descriptorPort.parseBitcoinDescriptor(
        descriptor: synthetic,
        network: network,
      );
      if (parsed.descriptorKeys.length != 1) {
        return const Err(BullVaultInvalidSignerFailure());
      }
      final key = parsed.descriptorKeys.single;
      if (hex.encode(Bip32Derivation.getBip32Xpub(key.xpub).public) ==
          _fixedNumsInternalKey) {
        return const Err(BullVaultInvalidSignerFailure());
      }
      final xpub = Bip32Derivation.getBip32Xpub(key.xpub);
      if (key.masterFingerprint.isEmpty ||
          _normalizePath(key.derivationPath) !=
              Bip48Derivation.path(coinType: network.coinType, account: 0) ||
          xpub.depth != 4 ||
          xpub.index != 0x80000002) {
        return const Err(BullVaultInvalidSignerFailure());
      }
      return Ok(
        BullVaultSignerKey(
          role: role,
          accountKey: WalletDescriptorKey(
            id: '${role.name}-account',
            signerId: role.name,
            masterFingerprint: key.masterFingerprint,
            xpubFingerprint: key.xpubFingerprint,
            xpub: key.xpub,
            derivationPath: key.derivationPath,
          ),
          signer: signer,
          signerDevice: signerDevice,
        ),
      );
    } on Exception {
      return const Err(BullVaultInvalidSignerFailure());
    }
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

  String? _normalizePath(String? path) =>
      path?.replaceAll('h', "'").replaceAll('H', "'");

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
