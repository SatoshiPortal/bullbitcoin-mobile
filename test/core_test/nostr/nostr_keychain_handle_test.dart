import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip340/bip340.dart' as bip340;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const _facade = NostrIdentityFacade(
  deriveHandle: DeriveNostrIdentityHandleUsecase(
    registry: Bip85RegistryFacade(),
  ),
);

const _zeroMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _identity = 1;
const _account = 1;
const _expectedWalletManifestPublicKeyHex =
    'feae6420b59badf72d7e85436ced2b0c3b9bcf4e46f05d901bf448f698f0ab52';
const _expectedBullnymAuthPublicKeyHex =
    '23a772c17ca7b9eba8c9442c4378c063d791967e35fbaed98a51d65243c03cd4';

void main() {
  test('BIP85 path derivation matches the bitcoin_base public key', () {
    final xprv = _zeroMnemonicXprv();
    final handle = NostrKeychainHandle.deriveFromBip85Path(
      xprvBase58: xprv,
      hardenedPath: _walletManifestPath,
    );

    expect(handle.publicKeyHex, _legacyPublicKeyHex(xprv));
  });

  test('Bull reserved Nostr roles produce stable golden public keys', () {
    final xprv = _zeroMnemonicXprv();
    const facade = _facade;

    expect(
      facade.deriveWalletManifestPublicKeyFromXprv(xprv),
      _expectedWalletManifestPublicKeyHex,
    );
    expect(
      facade.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
      _expectedBullnymAuthPublicKeyHex,
    );
  });

  test('wallet manifest facade uses the registry exact path', () {
    final xprv = _zeroMnemonicXprv();
    const registry = Bip85RegistryFacade();
    const facade = _facade;
    final reservation = registry.reservationById('nostr_wallet_manifest_key');
    expect(reservation, isNotNull);
    final expected = NostrKeychainHandle.deriveFromBip85Path(
      xprvBase58: xprv,
      hardenedPath: reservation!.scope.exactPath,
    );

    expect(
      facade.deriveWalletManifestPublicKeyFromXprv(xprv),
      expected.publicKeyHex,
    );
  });

  test('exposed Nostr role public keys are distinct', () {
    final xprv = _zeroMnemonicXprv();
    const facade = _facade;
    final publicKeys = {
      facade.deriveWalletManifestPublicKeyFromXprv(xprv),
      facade.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
    };

    expect(publicKeys.length, 2);
  });

  test('handle debug output does not expose secret key material', () {
    final xprv = _zeroMnemonicXprv();
    final handle = NostrKeychainHandle.deriveFromBip85Path(
      xprvBase58: xprv,
      hardenedPath: _walletManifestPath,
    );

    expect(handle.toString(), isNot(contains(_secretKeyHex(xprv))));
  });

  test('signs an explicit hash with a signature bitcoin_base can verify', () {
    final xprv = _zeroMnemonicXprv();
    const facade = _facade;
    final digest = sha256.convert([1, 2, 3, 4]).bytes;
    final signatureHex = facade.signWalletManifestHashFromXprv(
      xprvBase58: xprv,
      messageHashHex: hex.encode(digest),
    );
    final pub = ECPublic.fromHex(
      '02${facade.deriveWalletManifestPublicKeyFromXprv(xprv)}',
    );

    expect(
      pub.verifyBip340Signature(
        digest: digest,
        signature: hex.decode(signatureHex),
        tweak: false,
      ),
      isTrue,
    );

    // Independent cross-check with the bip340 package (not bitcoin_base), so a
    // bitcoin_base sign/verify self-consistency bug alone cannot make this pass
    // (AD-6). After the pr20 backend swap, bitcoin_base above remains the
    // independent verifier for dart-nostr/bip340 signing - both directions
    // covered across the stack.
    expect(
      bip340.verify(
        facade.deriveWalletManifestPublicKeyFromXprv(xprv),
        hex.encode(digest),
        signatureHex,
      ),
      isTrue,
    );
  });

  test('rejects signing input that is not a 32-byte hash', () {
    final xprv = _zeroMnemonicXprv();
    const facade = _facade;

    expect(
      () => facade.signWalletManifestHashFromXprv(
        xprvBase58: xprv,
        messageHashHex: 'abcd',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

String _zeroMnemonicXprv() {
  final mnemonic = bip39.Mnemonic.fromSentence(
    _zeroMnemonic,
    bip39.Language.english,
  );
  return bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed)).toBase58();
}

String _legacyPublicKeyHex(String xprvBase58) {
  final secretKeyHex = _secretKeyHex(xprvBase58);
  return ECPrivate.fromHex(secretKeyHex).getPublic().toXOnlyHex();
}

String _secretKeyHex(String xprvBase58) {
  final path = bip85.Bip85HardenedPath(_walletManifestPath);
  final entropyHex = bip85.Bip85Entropy.deriveFromHardenedPath(
    xprvBase58: xprvBase58,
    path: path,
  );
  return entropyHex.substring(0, 64);
}

String get _walletManifestPath =>
    "$nostrBip85Application'/$_identity'/$_account'";
