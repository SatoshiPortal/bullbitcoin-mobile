import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_seed_material.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class PrepareDeterministicWalletsUsecase {
  final DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase _deriveBip85;
  final DeterministicWalletRepository _walletRepository;

  PrepareDeterministicWalletsUsecase({
    required this._deriveBip85,
    required this._walletRepository,
  });

  @useResult
  Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
  execute(DeterministicWalletsRequest request) async {
    if (!_isValid(request)) {
      return const Err(InvalidDeterministicWalletRequestFailure());
    }

    final derivedResult = await _deriveBip85.execute(
      index: request.bip85Index,
      alias: request.bip85Alias,
      environment: request.environment,
    );
    final ({
      String derivation,
      bip39.Mnemonic mnemonic,
      String parentFingerprint,
    })
    derived;
    switch (derivedResult) {
      case Ok(:final value):
        derived = value;
      case Err(:final failure):
        return Err(_mapBip85Failure(failure));
    }

    final DeterministicWalletSeedMaterial seedMaterial;
    try {
      seedMaterial = _seedFromMnemonic(derived.mnemonic);
    } catch (error, trace) {
      log.warning(
        'Could not construct deterministic child-seed material',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DeterministicWalletUnexpectedFailure());
    }

    final prepared = <PreparedDeterministicWallet>[];
    var seedChecked = false;
    var seedStoredDuringAttempt = false;

    for (final spec in request.walletSpecs) {
      final matchingResult = await _walletRepository.getMatchingWallet(
        seedMaterial: seedMaterial,
        spec: spec,
      );
      switch (matchingResult) {
        case Ok(:final value):
          if (value != null) {
            prepared.add(value);
            continue;
          }
        case Err(:final failure):
          return Err(
            await _rollbackAfterFailure(
              originalFailure: failure,
              prepared: prepared,
              seedMaterial: seedMaterial,
              seedStoredDuringAttempt: seedStoredDuringAttempt,
            ),
          );
      }

      if (!seedChecked) {
        final existsResult = await _walletRepository.childSeedExists(
          seedMaterial.masterFingerprint,
        );
        switch (existsResult) {
          case Ok(:final value):
            seedChecked = true;
            if (!value) {
              // Mark this before the storage call. If storage commits and its
              // completion path fails, rollback still attempts deletion.
              seedStoredDuringAttempt = true;
              final storeResult = await _walletRepository.storeChildSeed(
                seedMaterial,
              );
              if (storeResult case Err(:final failure)) {
                return Err(
                  await _rollbackAfterFailure(
                    originalFailure: failure,
                    prepared: prepared,
                    seedMaterial: seedMaterial,
                    seedStoredDuringAttempt: seedStoredDuringAttempt,
                  ),
                );
              }
            }
          case Err(:final failure):
            return Err(
              await _rollbackAfterFailure(
                originalFailure: failure,
                prepared: prepared,
                seedMaterial: seedMaterial,
                seedStoredDuringAttempt: seedStoredDuringAttempt,
              ),
            );
        }
      }

      final createResult = await _walletRepository.createWallet(
        seedMaterial: seedMaterial,
        spec: spec,
      );
      switch (createResult) {
        case Ok(:final value):
          prepared.add(value);
        case Err(:final failure):
          return Err(
            await _rollbackAfterFailure(
              originalFailure: failure,
              prepared: prepared,
              seedMaterial: seedMaterial,
              seedStoredDuringAttempt: seedStoredDuringAttempt,
            ),
          );
      }
    }

    return Ok(
      PreparedDeterministicWallets(
        wallets: List.unmodifiable(prepared),
        derivationPath: derived.derivation,
        parentFingerprint: derived.parentFingerprint,
        childSeedFingerprint: seedMaterial.masterFingerprint,
        childSeedStoredDuringAttempt: seedStoredDuringAttempt,
      ),
    );
  }

  @useResult
  Future<Result<void, DeterministicWalletFailure>> rollbackCreatedWallets(
    PreparedDeterministicWallets result,
  ) async {
    final walletsDeleted = await _deleteCreatedWallets(result.wallets);
    if (!walletsDeleted) {
      return const Err(DeterministicWalletRollbackFailure());
    }
    if (result.shouldDeleteChildSeedOnRollback) {
      final seedResult = await _walletRepository.deleteChildSeed(
        result.childSeedFingerprint,
      );
      if (seedResult case Err()) {
        return const Err(DeterministicWalletRollbackFailure());
      }
    }
    return const Ok(null);
  }

  bool _isValid(DeterministicWalletsRequest request) {
    if (request.bip85Index < 0 ||
        request.bip85Alias.trim().isEmpty ||
        request.walletSpecs.isEmpty) {
      return false;
    }
    final specIds = <String>{};
    for (final spec in request.walletSpecs) {
      final id = spec.id.trim();
      if (id.isEmpty || !specIds.add(id)) return false;
    }
    return true;
  }

  DeterministicWalletFailure _mapBip85Failure(Bip85Failure failure) {
    return switch (failure) {
      Bip85DerivationConflictFailure() =>
        const DeterministicWalletDerivationConflictFailure(),
      _ => const DeterministicWalletDerivationFailure(),
    };
  }

  Future<DeterministicWalletFailure> _rollbackAfterFailure({
    required DeterministicWalletFailure originalFailure,
    required List<PreparedDeterministicWallet> prepared,
    required DeterministicWalletSeedMaterial seedMaterial,
    required bool seedStoredDuringAttempt,
  }) async {
    final walletsDeleted = await _deleteCreatedWallets(prepared);
    if (!walletsDeleted) {
      return const DeterministicWalletRollbackFailure();
    }

    final hasReusedWallet = prepared.any((wallet) => !wallet.created);
    if (seedStoredDuringAttempt && !hasReusedWallet) {
      final seedResult = await _walletRepository.deleteChildSeed(
        seedMaterial.masterFingerprint,
      );
      if (seedResult case Err()) {
        return const DeterministicWalletRollbackFailure();
      }
    }
    return originalFailure;
  }

  Future<bool> _deleteCreatedWallets(
    List<PreparedDeterministicWallet> wallets,
  ) async {
    var allDeleted = true;
    for (final wallet in wallets.where((wallet) => wallet.created)) {
      final result = await _walletRepository.deleteWallet(wallet.walletId);
      if (result case Err()) allDeleted = false;
    }
    return allDeleted;
  }

  DeterministicWalletSeedMaterial _seedFromMnemonic(bip39.Mnemonic mnemonic) {
    final seedBytes = Uint8List.fromList(mnemonic.seed);
    return DeterministicWalletSeedMaterial(
      mnemonicWords: mnemonic.words,
      seedBytes: seedBytes,
      masterFingerprint: bip32.Bip32Keys.fromSeed(
        seedBytes,
      ).fingerprint.toHexString(),
    );
  }
}
