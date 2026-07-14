import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_seed_material.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';
import 'package:meta/meta.dart';

typedef DeterministicWalletMetadataDeriver =
    Future<WalletMetadataModel> Function({
      required Seed seed,
      required Network network,
      required ScriptType scriptType,
      String? label,
      required bool isDefault,
    });

class DeterministicWalletRepositoryImpl
    implements DeterministicWalletRepository {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final DeterministicWalletMetadataDeriver _deriveWalletMetadata;

  DeterministicWalletRepositoryImpl({
    required this._walletRepository,
    required this._seedRepository,
    DeterministicWalletMetadataDeriver? deriveWalletMetadata,
  }) : _deriveWalletMetadata =
           deriveWalletMetadata ?? WalletMetadataService.deriveFromSeed;

  @override
  @useResult
  Future<Result<PreparedDeterministicWallet?, DeterministicWalletFailure>>
  getMatchingWallet({
    required DeterministicWalletSeedMaterial seedMaterial,
    required DeterministicWalletSpec spec,
  }) async {
    try {
      final expectedMetadata = await _deriveWalletMetadata(
        seed: _toCoreSeed(seedMaterial),
        network: spec.network,
        scriptType: spec.scriptType,
        label: spec.label,
        isDefault: spec.isDefault,
      );
      final existing = await _walletRepository.getWallet(expectedMetadata.id);
      if (existing == null) return const Ok(null);
      if (!_matchesExpected(
        wallet: existing,
        spec: spec,
        expectedMetadata: expectedMetadata,
      )) {
        return const Err(DeterministicWalletMismatchFailure());
      }
      return Ok(
        _toPreparedWallet(spec: spec, wallet: existing, created: false),
      );
    } catch (error, trace) {
      log.warning(
        'Deterministic wallet lookup failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletOperationFailure());
    }
  }

  @override
  @useResult
  Future<Result<bool, DeterministicWalletFailure>> childSeedExists(
    String fingerprint,
  ) async {
    try {
      return Ok(await _seedRepository.exists(fingerprint));
    } catch (error, trace) {
      log.warning(
        'Deterministic child-seed lookup failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletStorageFailure());
    }
  }

  @override
  @useResult
  Future<Result<void, DeterministicWalletFailure>> storeChildSeed(
    DeterministicWalletSeedMaterial seedMaterial,
  ) async {
    try {
      await _seedRepository.createFromMnemonic(
        mnemonicWords: seedMaterial.mnemonicWords,
      );
      return const Ok(null);
    } catch (error, trace) {
      log.warning(
        'Deterministic child-seed storage failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletStorageFailure());
    }
  }

  @override
  @useResult
  Future<Result<PreparedDeterministicWallet, DeterministicWalletFailure>>
  createWallet({
    required DeterministicWalletSeedMaterial seedMaterial,
    required DeterministicWalletSpec spec,
  }) async {
    try {
      final created = await _walletRepository.createWallet(
        seed: _toCoreSeed(seedMaterial),
        network: spec.network,
        scriptType: spec.scriptType,
        isDefault: spec.isDefault,
        sync: spec.sync,
        label: spec.label,
      );
      return Ok(_toPreparedWallet(spec: spec, wallet: created, created: true));
    } catch (error, trace) {
      log.warning(
        'Deterministic wallet creation failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletOperationFailure());
    }
  }

  @override
  @useResult
  Future<Result<void, DeterministicWalletFailure>> deleteWallet(
    String walletId,
  ) async {
    try {
      await _walletRepository.deleteWallet(walletId: walletId);
      return const Ok(null);
    } catch (error, trace) {
      log.warning(
        'Deterministic wallet rollback failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletRollbackFailure());
    }
  }

  @override
  @useResult
  Future<Result<void, DeterministicWalletFailure>> deleteChildSeed(
    String fingerprint,
  ) async {
    try {
      final result = await _seedRepository.delete(fingerprint);
      return switch (result) {
        Ok() => const Ok(null),
        Err() => const Err(DeterministicWalletRollbackFailure()),
      };
    } catch (error, trace) {
      log.warning(
        'Deterministic child-seed rollback failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletRollbackFailure());
    }
  }

  MnemonicSeed _toCoreSeed(DeterministicWalletSeedMaterial material) {
    return Seed.mnemonic(
          mnemonicWords: material.mnemonicWords,
          bytes: material.seedBytes,
          masterFingerprint: material.masterFingerprint,
        )
        as MnemonicSeed;
  }

  bool _matchesExpected({
    required Wallet wallet,
    required DeterministicWalletSpec spec,
    required WalletMetadataModel expectedMetadata,
  }) {
    return wallet.network == spec.network &&
        wallet.scriptType == spec.scriptType &&
        wallet.externalPublicDescriptor ==
            expectedMetadata.externalPublicDescriptor &&
        wallet.internalPublicDescriptor ==
            expectedMetadata.internalPublicDescriptor;
  }

  PreparedDeterministicWallet _toPreparedWallet({
    required DeterministicWalletSpec spec,
    required Wallet wallet,
    required bool created,
  }) {
    return PreparedDeterministicWallet(
      specId: spec.id,
      walletId: wallet.id,
      network: wallet.network,
      scriptType: wallet.scriptType,
      label: wallet.label,
      externalPublicDescriptor: wallet.externalPublicDescriptor,
      internalPublicDescriptor: wallet.internalPublicDescriptor,
      created: created,
    );
  }
}
