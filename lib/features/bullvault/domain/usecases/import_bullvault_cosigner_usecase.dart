import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Fingerprint;
import 'package:secrets/secrets.dart';
import 'package:meta/meta.dart';

/// Attaches a verified secret to a signer without changing the descriptor or default wallet.
class ImportBullVaultCosignerUsecase {
  final BullVaultRepository _vaults;
  final GetWalletUsecase _getWallet;
  final Secrets _secrets;
  final WalletSignerOwnershipPort _ownership;

  const ImportBullVaultCosignerUsecase(
    this._vaults,
    this._getWallet,
    this._secrets,
    this._ownership,
  );

  @useResult
  Future<Result<Wallet, BullVaultFailure>> execute({
    required String walletId,
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
  }) async {
    if (words.join(' ').length > 2048 || (passphrase?.length ?? 0) > 1024) {
      return const Err(BullVaultCosignerMismatchFailure());
    }
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
      final matches = <(WalletSigner, Fingerprint, Set<String>)>[];
      for (final signer in wallet.signers) {
        final match = await _matchingKeys(signer, words, language, passphrase);
        if (match != null) matches.add((signer, match.$1, match.$2));
      }
      if (matches.length != 1) {
        return const Err(BullVaultCosignerMismatchFailure());
      }
      final (signer, fingerprint, protectedKeys) = matches.single;
      if (passphrase?.isNotEmpty == true && protectedKeys.isEmpty) {
        return const Err(BullVaultCosignerMismatchFailure());
      }
      // Persist only the canonical words, after every key of one signer matches.
      switch (await _secrets.import(
        words: words,
        language: language,
        acceptOnly: {fingerprint},
      )) {
        case Ok():
          break;
        case Err(failure: SecretAlreadyExistsFailure()):
          if (await _secrets.contains(words: words, language: language) case Ok(
            value: true,
          )) {
            break;
          }
          return const Err(BullVaultCosignerImportFailure());
        case Err():
          return const Err(BullVaultCosignerImportFailure());
      }
      return Ok(
        await _ownership.markSignerLocal(
          walletId: wallet.id,
          signerId: signer.id,
          seedFingerprint: fingerprint.hex,
          passphraseProtectedKeyIds: protectedKeys,
        ),
      );
    } on Exception {
      return const Err(BullVaultCosignerImportFailure());
    }
  }

  Future<(Fingerprint, Set<String>)?> _matchingKeys(
    WalletSigner signer,
    List<String> words,
    Language language,
    String? passphrase,
  ) async {
    Fingerprint? canonicalFingerprint;
    final protectedKeys = <String>{};
    for (final key in signer.descriptorKeys) {
      final path = key.derivationPath;
      if (path == null) return null;
      final canonical = await _secrets.preview.account(
        words: words,
        language: language,
        derivationPath: path,
        network: BitcoinNetwork.mainnet,
      );
      final PublicAccountKey account;
      switch (canonical) {
        case Ok(:final value):
          account = value;
        case Err():
          return null;
      }
      canonicalFingerprint = account.fingerprint;
      final xpub = Bip32Derivation.getBip32Xpub(key.xpub).toBase58();
      if (account.xpub == xpub) continue;
      if (passphrase == null || passphrase.isEmpty) return null;
      switch (await _secrets.preview.account(
        words: words,
        language: language,
        derivationPath: path,
        network: BitcoinNetwork.mainnet,
        passphrase: passphrase,
      )) {
        case Ok(:final value) when value.xpub == xpub:
          protectedKeys.add(key.id);
        default:
          return null;
      }
    }
    return canonicalFingerprint == null
        ? null
        : (canonicalFingerprint, protectedKeys);
  }
}
