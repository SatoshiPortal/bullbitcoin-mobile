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
  final Bip85Repository _bip85;
  final WalletRepository _wallets;
  final SeedRepository _seeds;

  const DeriveBip85MnemonicAtIndexFromDefaultWalletUsecase({
    required Bip85Repository bip85Repository,
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _bip85 = bip85Repository,
       _wallets = walletRepository,
       _seeds = seedRepository;

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
  }) async {
    if (index < 0 || alias.trim().isEmpty) {
      return const Err(Bip85DerivationFailure('Invalid BIP85 reservation'));
    }
    try {
      final defaults = await _wallets.getWallets(
        environment: environment,
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      if (defaults.isEmpty) return const Err(Bip85NoDefaultWalletFailure());
      if (defaults.length > 1) {
        return const Err(Bip85DefaultWalletAmbiguousFailure());
      }

      final wallet = defaults.first;
      final seed = await _seeds.get(wallet.masterFingerprint);
      final xprv = Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes);
      final preview = await _bip85.deriveMnemonicPreview(
        xprvBase58: xprv,
        length: bip39.MnemonicLength.words12,
        index: index,
      );
      final ({String derivation, bip39.Mnemonic mnemonic}) value;
      switch (preview) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final result):
          value = result;
      }

      final existingResult = await _bip85.fetch(value.derivation);
      final Bip85DerivationEntity? existing;
      switch (existingResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final result):
          existing = result;
      }

      if (existing != null &&
          existing.xprvFingerprint == wallet.masterFingerprint.toLowerCase()) {
        if (existing.status != Bip85Status.active) {
          return const Err(
            Bip85DerivationConflictFailure('Reserved BIP85 path is not active'),
          );
        }
        if (existing.application != Bip85Application.bip39 ||
            existing.alias != alias) {
          return const Err(
            Bip85DerivationConflictFailure(
              'Reserved BIP85 path already has a different owner',
            ),
          );
        }
        return Ok((
          derivation: value.derivation,
          mnemonic: value.mnemonic,
          parentFingerprint: wallet.masterFingerprint,
        ));
      }

      return switch (await _bip85.deriveMnemonic(
        xprvBase58: xprv,
        length: bip39.MnemonicLength.words12,
        index: index,
        alias: alias,
      )) {
        Err(:final failure) => Err(failure),
        Ok(value: final derived) => Ok((
          derivation: derived.derivation,
          mnemonic: derived.mnemonic,
          parentFingerprint: wallet.masterFingerprint,
        )),
      };
    } catch (error, trace) {
      log.severe(
        message: 'Fixed BIP85 mnemonic derivation failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(
        Bip85UnexpectedFailure('BIP85 fixed-index derivation failed'),
      );
    }
  }
}
