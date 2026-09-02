import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// Removes a passphrase wallet from this device: its private session, its local
/// public projection, and last its manifest record (spec 20.8).
///
/// The manifest and the wallet store cannot be written in one transaction, so
/// the order is the decision (decision 6): the cache goes first, the record
/// last. Interrupted, that leaves a locked card the user can forget again —
/// never a wallet still sitting on Home with no record of where it came from.
final class ForgetPassphraseWalletUsecase {
  final WalletFacade _wallets;
  final KeychainManifestFacade _manifest;

  const ForgetPassphraseWalletUsecase(this._wallets, this._manifest);

  Future<Result<void, PassphraseWalletFailure>> execute(
    PassphraseWalletRecord wallet,
  ) async {
    if (_wallets.isPrivateWalletSessionLoaded(wallet.walletId)) {
      _wallets.unloadPrivateWalletSession();
    }
    try {
      await _wallets.deletePublicProjection(wallet.walletId);
    } on Exception {
      return const Err(PassphraseWalletStorageFailure());
    }
    return switch (await _manifest.deleteWallet(
      parentFingerprint: wallet.parentFingerprint,
      walletId: wallet.walletId,
    )) {
      Ok() => const Ok(null),
      Err() => const Err(PassphraseWalletManifestFailure()),
    };
  }
}
