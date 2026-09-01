import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_metadata_rules.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// Edits a passphrase wallet's label and hint (spec 6.6).
///
/// The manifest is canonical for both (decision 2), so it is written first and
/// alone decides whether the edit happened. The mounted wallet's label is a
/// projection of it: failing to refresh that leaves the manifest truth intact
/// and only means the wallet shows its old name until it is mounted again.
final class UpdatePassphraseWalletMetadataUsecase {
  final KeychainManifestFacade _manifest;
  final WalletFacade _wallets;

  const UpdatePassphraseWalletMetadataUsecase(this._manifest, this._wallets);

  Future<Result<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>
  execute(
    PassphraseWalletRecord wallet, {
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
  }) async {
    final newLabel = PassphraseWalletMetadataRules.normalize(label?.value);
    final newHint = PassphraseWalletMetadataRules.normalize(hint?.value);
    if (PassphraseWalletMetadataRules.rejectsLabel(newLabel) ||
        PassphraseWalletMetadataRules.rejectsHint(newHint)) {
      return const Err(PassphraseWalletManifestFailure());
    }

    final saved = await _manifest.updatePassphraseLabelHint(
      parentFingerprint: wallet.parentFingerprint,
      walletId: wallet.walletId,
      label: label == null ? null : KeychainManifestEdit(newLabel),
      hint: hint == null ? null : KeychainManifestEdit(newHint),
    );
    if (saved case Err()) {
      return const Err(PassphraseWalletManifestFailure());
    }

    // Only the label is projected onto the wallet; the hint lives in the
    // manifest alone. A cleared label has no projected form — the card falls
    // back to the default name — so there is nothing to write for it either.
    if (newLabel == null) {
      return const Ok(PassphraseWalletMetadataStatus.updated);
    }
    try {
      await _wallets.updateWalletLabel(
        walletId: wallet.walletId,
        label: newLabel,
      );
    } on Exception {
      return const Ok(PassphraseWalletMetadataStatus.savedRemountNeeded);
    }
    return const Ok(PassphraseWalletMetadataStatus.updated);
  }
}
