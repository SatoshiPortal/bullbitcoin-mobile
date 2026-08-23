import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/derive_bip85_mnemonic_at_index_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallet_failure.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/deterministic_wallets.dart';
import 'package:bb_mobile/features/deterministic_wallets/domain/repositories/deterministic_wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class PrepareDeterministicWalletsUsecase {
  final DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase _derive;
  final DeterministicWalletRepository _repository;

  const PrepareDeterministicWalletsUsecase(this._derive, this._repository);

  @useResult
  Future<Result<PreparedDeterministicWallets, DeterministicWalletFailure>>
  execute(DeterministicWalletsRequest request) async {
    if (!_valid(request)) {
      return const Err(InvalidDeterministicWalletRequestFailure());
    }

    final derived = await _derive.execute(
      index: request.bip85Index,
      alias: request.bip85Alias,
      environment: request.environment,
    );
    final ({
      String derivation,
      bip39.Mnemonic mnemonic,
      String parentFingerprint,
    })
    value;
    switch (derived) {
      case Err(failure: Bip85DerivationConflictFailure()):
        return const Err(DeterministicWalletDerivationConflictFailure());
      case Err():
        return const Err(DeterministicWalletDerivationFailure());
      case Ok(value: final result):
        value = result;
    }

    final seed = _seed(value.mnemonic);
    final prepared = <PreparedDeterministicWallet>[];
    var storedSeed = false;
    var seedReady = false;
    try {
      for (final spec in request.walletSpecs) {
        final existing = await _repository.findMatchingWallet(
          seed: seed,
          spec: spec,
        );
        if (existing != null) {
          prepared.add(existing);
          continue;
        }
        if (!seedReady) {
          if (!await _repository.seedExists(seed.masterFingerprint)) {
            storedSeed = true;
            await _repository.storeSeed(seed);
          }
          seedReady = true;
        }
        prepared.add(await _repository.createWallet(seed: seed, spec: spec));
      }
    } on DeterministicWalletMismatchException {
      return Err(
        await _rollbackFailure(
          const DeterministicWalletMismatchFailure(),
          prepared,
          seed.masterFingerprint,
          storedSeed,
        ),
      );
    } on Exception catch (error, trace) {
      log.warning(
        'Deterministic wallet preparation failed',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(
        await _rollbackFailure(
          const DeterministicWalletOperationFailure(),
          prepared,
          seed.masterFingerprint,
          storedSeed,
        ),
      );
    }

    return Ok(
      PreparedDeterministicWallets(
        wallets: List.unmodifiable(prepared),
        derivationPath: value.derivation,
        parentFingerprint: value.parentFingerprint,
        childSeedFingerprint: seed.masterFingerprint,
        childSeedStoredDuringAttempt: storedSeed,
      ),
    );
  }

  @useResult
  Future<Result<void, DeterministicWalletFailure>> rollbackCreatedWallets(
    PreparedDeterministicWallets result,
  ) async =>
      await _rollback(
        result.wallets,
        result.childSeedFingerprint,
        result.shouldDeleteChildSeedOnRollback,
      )
      ? const Ok(null)
      : const Err(DeterministicWalletRollbackFailure());

  bool _valid(DeterministicWalletsRequest request) {
    if (request.bip85Index < 0 ||
        request.bip85Alias.trim().isEmpty ||
        request.walletSpecs.isEmpty) {
      return false;
    }
    final ids = <String>{};
    return request.walletSpecs.every(
      (spec) => spec.id.trim().isNotEmpty && ids.add(spec.id),
    );
  }

  MnemonicSeed _seed(bip39.Mnemonic mnemonic) {
    final bytes = Uint8List.fromList(mnemonic.seed);
    return Seed.mnemonic(
          mnemonicWords: mnemonic.words,
          bytes: bytes,
          masterFingerprint: bip32.Bip32Keys.fromSeed(
            bytes,
          ).fingerprint.toHexString(),
        )
        as MnemonicSeed;
  }

  Future<DeterministicWalletFailure> _rollbackFailure(
    DeterministicWalletFailure failure,
    List<PreparedDeterministicWallet> wallets,
    String fingerprint,
    bool storedSeed,
  ) async =>
      await _rollback(
        wallets,
        fingerprint,
        storedSeed && wallets.every((wallet) => wallet.created),
      )
      ? failure
      : const DeterministicWalletRollbackFailure();

  Future<bool> _rollback(
    List<PreparedDeterministicWallet> wallets,
    String fingerprint,
    bool deleteSeed,
  ) async {
    try {
      for (final wallet in wallets.where((wallet) => wallet.created)) {
        await _repository.deleteWallet(wallet.walletId);
      }
      if (deleteSeed) await _repository.deleteSeed(fingerprint);
      return true;
    } on Exception catch (error, trace) {
      log.warning(
        'Deterministic wallet rollback failed',
        error: error.runtimeType,
        trace: trace,
      );
      return false;
    }
  }
}
