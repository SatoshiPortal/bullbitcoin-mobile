import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Resolves the Get Paid signing identity for invoices. Unlinked v1 needs ONLY
/// the npub signer — the SAME server-auth npub the Donation Page / POS derive
/// from the DEFAULT (Bitcoin) wallet xprv. The xprv is derived at point of use
/// and captured only inside the signing closure (charter H1: never stored,
/// never logged).
class InvoicesIdentityDatasource implements InvoicesIdentityPort {
  final GetSettingsUsecase _getSettings;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final NostrIdentityFacade _nostrIdentity;

  const InvoicesIdentityDatasource({
    required this._getSettings,
    required this._walletRepository,
    required this._seedRepository,
    required this._nostrIdentity,
  });

  @override
  Future<BullnymAuthSigner> getSigningHandle() async {
    final xprvBase58 = await _deriveDefaultWalletXprv();
    final String npubHex;
    try {
      npubHex = _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprvBase58,
      );
    } catch (_) {
      throw const InvoicesException.signingFailed();
    }
    return BullnymAuthSigner(
      npubHex: npubHex,
      signHashHex: (messageHashHex) =>
          _nostrIdentity.signBullnymServerAuthHashFromXprv(
            xprvBase58: xprvBase58,
            messageHashHex: messageHashHex,
          ),
    );
  }

  Future<String> _deriveDefaultWalletXprv() async {
    final settings = await _getSettings.execute();
    final wallets = await _walletRepository.getWallets(
      environment: settings.environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) {
      // No default wallet to bind the Get Paid identity to.
      throw const InvoicesException.noDefaultBitcoinWallet();
    }
    final defaultWallet = wallets.first;
    try {
      final seed = await _seedRepository.get(defaultWallet.masterFingerprint);
      return Bip32Derivation.getXprvFromSeed(
        seed.bytes,
        defaultWallet.network,
      );
    } on InvoicesException {
      rethrow;
    } catch (_) {
      throw const InvoicesException.signingFailed();
    }
  }
}
