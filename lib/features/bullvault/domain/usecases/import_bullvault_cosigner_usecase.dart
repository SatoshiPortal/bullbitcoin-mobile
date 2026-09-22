import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/ensure_canonical_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

/// Attaches a verified seed through Ben's existing owners. The vault descriptor,
/// mobile origin and default wallet are never changed by this action.
class ImportBullVaultCosignerUsecase {
  final BullVaultRepository _vaults;
  final GetWalletUsecase _getWallet;
  final EnsureCanonicalSeedUsecase _ensureSeed;
  final WalletSignerOwnershipPort _ownership;

  const ImportBullVaultCosignerUsecase(
    this._vaults,
    this._getWallet,
    this._ensureSeed,
    this._ownership,
  );

  @useResult
  Future<Result<Wallet, BullVaultFailure>> execute({
    required String walletId,
    required List<String> words,
    String? passphrase,
  }) async {
    if (words.join(' ').length > 2048 || (passphrase?.length ?? 0) > 1024) {
      return const Err(BullVaultCosignerMismatchFailure());
    }
    Uint8List? canonicalBytes, protectedBytes;
    try {
      final recordResult = await _vaults.getByWalletId(walletId);
      if (recordResult case Err(:final failure)) return Err(failure);
      final record =
          (recordResult as Ok<BullVaultRecord?, BullVaultFailure>).value;
      if (record == null) return const Err(BullVaultCosignerImportFailure());
      final wallet = await _getWallet.execute(walletId);
      if (wallet == null ||
          !wallet.isBitcoin ||
          wallet.network != record.recoveryPackage.policy.network) {
        return const Err(BullVaultCosignerImportFailure());
      }
      final bip39.Mnemonic mnemonic;
      try {
        mnemonic = bip39.Mnemonic.fromWords(words: words);
      } on Exception {
        return const Err(BullVaultCosignerMismatchFailure());
      }
      canonicalBytes = Uint8List.fromList(mnemonic.seed);
      protectedBytes = passphrase == null || passphrase.isEmpty
          ? null
          : Uint8List.fromList(
              bip39.Mnemonic.fromWords(
                words: words,
                passphrase: passphrase,
              ).seed,
            );
      final matches = <(WalletSigner, Set<String>)>[];
      for (final signer in wallet.signers) {
        final protectedKeys = _matchingKeys(
          signer,
          canonicalBytes,
          protectedBytes,
        );
        if (protectedKeys != null) matches.add((signer, protectedKeys));
      }
      if (matches.length != 1) {
        return const Err(BullVaultCosignerMismatchFailure());
      }
      final (signer, protectedKeys) = matches.single;
      if (protectedBytes != null && protectedKeys.isEmpty) {
        return const Err(BullVaultCosignerMismatchFailure());
      }
      // Do not store input until every key of exactly one signer has matched.
      // This existing owner deduplicates and stores the passphrase-free seed.
      final fingerprint = await _ensureSeed.execute(
        Seed.mnemonic(
          mnemonicWords: mnemonic.words,
          bytes: canonicalBytes,
          masterFingerprint: bip32.Bip32Keys.fromSeed(
            canonicalBytes,
          ).fingerprintHex,
        ),
      );
      return Ok(
        await _ownership.markSignerLocal(
          walletId: wallet.id,
          signerId: signer.id,
          seedFingerprint: fingerprint,
          passphraseProtectedKeyIds: protectedKeys,
        ),
      );
    } on Exception {
      return const Err(BullVaultCosignerImportFailure());
    } finally {
      canonicalBytes?.fillRange(0, canonicalBytes.length, 0);
      protectedBytes?.fillRange(0, protectedBytes.length, 0);
    }
  }

  Set<String>? _matchingKeys(
    WalletSigner signer,
    Uint8List canonical,
    Uint8List? protected,
  ) {
    final protectedKeys = <String>{};
    for (final key in signer.descriptorKeys) {
      final path = key.derivationPath;
      if (path == null) return null;
      try {
        if (Bip32Derivation.seedMatchesXpub(
          seedBytes: canonical,
          derivationPath: path,
          xpub: key.xpub,
        )) {
          continue;
        }
        if (protected == null ||
            !Bip32Derivation.seedMatchesXpub(
              seedBytes: protected,
              derivationPath: path,
              xpub: key.xpub,
            )) {
          return null;
        }
        protectedKeys.add(key.id);
      } on Exception {
        return null;
      }
    }
    return protectedKeys;
  }
}
