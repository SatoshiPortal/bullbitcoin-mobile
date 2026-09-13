import 'dart:typed_data';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/ensure_canonical_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bip32_keys/bip32_keys.dart';

/// Adds an existing cosigner, never changes the policy or the default wallet.
/// Reuses encrypted canonical seed storage; a BIP39 passphrase is never stored.
final class ImportBullVaultCosignerUsecase {
  final BullVaultRepository _vaults;
  final GetWalletUsecase _wallets;
  final EnsureCanonicalSeedUsecase _seeds;
  final WalletSignerOwnershipPort _ownership;
  const ImportBullVaultCosignerUsecase(
    this._vaults,
    this._wallets,
    this._seeds,
    this._ownership,
  );

  Future<Result<Wallet, BullVaultFailure>> execute({
    required String walletId,
    required String words,
    required String passphrase,
  }) async {
    if (words.length > 2048 || passphrase.length > 1024) {
      return const Err(BullVaultInvalidSignerFailure());
    }
    try {
      final record = await _vaults.getByWalletId(walletId);
      if (record case Err()) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      if ((record as Ok).value == null) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      final wallet = await _wallets.execute(walletId);
      if (wallet == null) return const Err(BullVaultInvalidRecoveryFailure());
      final wordList = words.trim().toLowerCase().split(RegExp(r'\s+'));
      final mnemonic = Mnemonic.fromWords(
        words: wordList,
        passphrase: passphrase,
      );
      final bytes = Uint8List.fromList(mnemonic.seed);
      final canonicalBytes = Uint8List.fromList(
        Mnemonic.fromWords(words: wordList).seed,
      );
      try {
        final protectedKeys = <String>{};
        final matching = wallet.signers
            .where(
              (signer) => signer.descriptorKeys.every((key) {
                final path = key.derivationPath;
                if (path == null || path.isEmpty) return false;
                if (passphrase.isNotEmpty &&
                    Bip32Derivation.seedMatchesXpub(
                      seedBytes: bytes,
                      derivationPath: path,
                      xpub: key.xpub,
                    )) {
                  protectedKeys.add(key.id);
                  return true;
                }
                // Ben groups the passphrased everyday key and the canonical delayed
                // recovery key in one signer. Verify each against its actual seed.
                return Bip32Derivation.seedMatchesXpub(
                  seedBytes: canonicalBytes,
                  derivationPath: path,
                  xpub: key.xpub,
                );
              }),
            )
            .toList();
        if (matching.length != 1) {
          return const Err(BullVaultInvalidSignerFailure());
        }
        final signer = matching.single;
        final matchedProtectedKeys = signer.descriptorKeys
            .where((key) => protectedKeys.contains(key.id))
            .map((key) => key.id)
            .toSet();
        if (passphrase.isNotEmpty && matchedProtectedKeys.isEmpty) {
          return const Err(BullVaultInvalidSignerFailure());
        }
        // Persist the canonical seed only after every account key has matched.
        // Wrong input never writes storage.
        final canonical = Seed.mnemonic(
          mnemonicWords: wordList,
          bytes: canonicalBytes,
          masterFingerprint: Bip32Keys.fromSeed(canonicalBytes).fingerprintHex,
        );
        final fingerprint = await _seeds.execute(canonical);
        final updated = await _ownership.markSignerLocal(
          walletId: walletId,
          signerId: signer.id,
          seedFingerprint: fingerprint,
          passphraseProtectedKeyIds: matchedProtectedKeys,
        );
        return Ok(updated);
      } finally {
        canonicalBytes.fillRange(0, canonicalBytes.length, 0);
        bytes.fillRange(0, bytes.length, 0);
      }
    } on FormatException {
      return const Err(BullVaultInvalidSignerFailure());
    } on Exception {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
  }
}
