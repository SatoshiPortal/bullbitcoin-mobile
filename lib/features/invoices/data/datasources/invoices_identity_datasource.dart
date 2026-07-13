import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
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
  Future<Result<BullnymAuthSigner, InvoicesFailure>> getSigningHandle() async {
    try {
      final settings = await _getSettings.execute();
      final wallets = await _walletRepository.getWallets(
        environment: settings.environment,
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      if (wallets.isEmpty) {
        return const Err(InvoicesFailure.noDefaultBitcoinWallet());
      }
      final defaultWallet = wallets.first;
      final seed = await _seedRepository.get(defaultWallet.masterFingerprint);
      final xprvBase58 = Bip32Derivation.getXprvFromSeed(
        seed.bytes,
        defaultWallet.network,
      );
      final npubHex = _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
        xprvBase58,
      );
      return Ok(
        BullnymAuthSigner(
          npubHex: npubHex,
          signHashHex: (messageHashHex) =>
              _nostrIdentity.signBullnymServerAuthHashFromXprv(
                xprvBase58: xprvBase58,
                messageHashHex: messageHashHex,
              ),
        ),
      );
    } on Exception {
      // Do not attach raw seed/derivation diagnostics to this failure. The
      // signing path handles key material and must remain non-observable.
      return const Err(InvoicesFailure.signingFailed());
    }
  }
}
