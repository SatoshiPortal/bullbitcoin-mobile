import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase({
    required this._bip85Repository,
    required this._walletRepository,
    required this._seedRepository,
  });

  @useResult
  Future<
    Result<
      ({String derivation, bip39.Mnemonic mnemonic, String parentFingerprint}),
      Bip85Failure
    >
  >
  execute({
    required int index,
    required String alias,
    Environment? environment,
    bip39.MnemonicLength length = bip39.MnemonicLength.words12,
  }) async {
    try {
      final wallets = await _walletRepository.getWallets(
        environment: environment,
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      if (wallets.isEmpty) {
        return const Err(Bip85NoDefaultWalletFailure());
      }

      final defaultWallet = wallets.first;
      final defaultSeed = await _seedRepository.get(
        defaultWallet.masterFingerprint,
      );
      final xprv = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        defaultWallet.network,
      );

      return await _deriveForCurrentWallet(
        xprvBase58: xprv,
        parentFingerprint: defaultWallet.masterFingerprint,
        index: index,
        alias: alias,
        length: length,
      );
    } catch (e, st) {
      log.severe(
        message: 'DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(
        Bip85UnexpectedFailure('BIP85 fixed-index derivation failed'),
      );
    }
  }

  Future<
    Result<
      ({String derivation, bip39.Mnemonic mnemonic, String parentFingerprint}),
      Bip85Failure
    >
  >
  _deriveForCurrentWallet({
    required String xprvBase58,
    required String parentFingerprint,
    required int index,
    required String alias,
    required bip39.MnemonicLength length,
  }) async {
    final previewResult = await _bip85Repository.deriveMnemonicPreview(
      xprvBase58: xprvBase58,
      length: length,
      index: index,
    );
    late final ({String derivation, bip39.Mnemonic mnemonic}) preview;
    switch (previewResult) {
      case Ok(:final value):
        preview = value;
      case Err(:final failure):
        return Err(failure);
    }

    final existingResult = await _bip85Repository.fetch(preview.derivation);
    late final Bip85DerivationEntity? existing;
    switch (existingResult) {
      case Ok(:final value):
        existing = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (existing == null) {
      return _storeMnemonic(
        xprvBase58: xprvBase58,
        parentFingerprint: parentFingerprint,
        index: index,
        alias: alias,
        length: length,
      );
    }

    final fingerprintResult = _bip85Repository.fingerprintFromXprv(xprvBase58);
    late final String currentFingerprint;
    switch (fingerprintResult) {
      case Ok(:final value):
        currentFingerprint = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (existing.xprvFingerprint != currentFingerprint) {
      return _storeMnemonic(
        xprvBase58: xprvBase58,
        parentFingerprint: parentFingerprint,
        index: index,
        alias: alias,
        length: length,
      );
    }

    final conflict = _compatibleExistingConflict(existing, alias: alias);
    return conflict == null
        ? Ok((
            derivation: preview.derivation,
            mnemonic: preview.mnemonic,
            parentFingerprint: parentFingerprint,
          ))
        : Err(conflict);
  }

  Future<
    Result<
      ({String derivation, bip39.Mnemonic mnemonic, String parentFingerprint}),
      Bip85Failure
    >
  >
  _storeMnemonic({
    required String xprvBase58,
    required String parentFingerprint,
    required int index,
    required String alias,
    required bip39.MnemonicLength length,
  }) async {
    final result = await _bip85Repository.deriveMnemonic(
      xprvBase58: xprvBase58,
      length: length,
      index: index,
      alias: alias,
    );
    return switch (result) {
      Ok(:final value) => Ok((
        derivation: value.derivation,
        mnemonic: value.mnemonic,
        parentFingerprint: parentFingerprint,
      )),
      Err(:final failure) => Err(failure),
    };
  }

  Bip85DerivationConflictFailure? _compatibleExistingConflict(
    Bip85DerivationEntity existing, {
    required String alias,
  }) {
    if (existing.application != Bip85Application.bip39) {
      return const Bip85DerivationConflictFailure(
        'BIP85 derivation belongs to a different application',
      );
    }
    if (existing.alias != alias) {
      return const Bip85DerivationConflictFailure(
        'BIP85 derivation already has a different alias',
      );
    }
    return null;
  }
}
