import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Builds the ephemeral, per-request npub-wide signer for fiat-settlement
/// actions from the account's default-wallet xprv. The xprv is confined to this
/// call frame and never stored on any object.
Future<BullnymAuthSigner> buildFiatSettlementSigner({
  required FiatSettlementDefaultWalletXprvPort xprvPort,
  required NostrIdentityFacade nostrIdentity,
}) async {
  final xprvBase58 = await xprvPort.deriveDefaultWalletXprv();
  return BullnymAuthSigner(
    npubHex: nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprvBase58),
    signHashHex: (messageHashHex) =>
        nostrIdentity.signBullnymServerAuthHashFromXprv(
          xprvBase58: xprvBase58,
          messageHashHex: messageHashHex,
        ),
  );
}
