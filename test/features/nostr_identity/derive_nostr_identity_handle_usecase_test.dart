import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Master BIP32 root key from the official BIP85 test vectors.
const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';

void main() {
  const usecase = DeriveNostrIdentityHandleUsecase(
    registry: Bip85RegistryFacade(),
  );

  test('derives role keys from the registry key reservations', () {
    final walletManifestHandle = usecase.execute(
      xprvBase58: _masterXprv,
      role: NostrIdentityRole.walletManifest,
    );
    final bullnymAuthHandle = usecase.execute(
      xprvBase58: _masterXprv,
      role: NostrIdentityRole.bullnymServerAuth,
    );

    expect(
      walletManifestHandle.publicKeyHex,
      '1072ff1a657708c194dcd1fa57d894eab3e8fca1b65950cee5c05f35a4425b9f',
    );
    expect(
      walletManifestHandle.publicKeyHex,
      NostrKeychainHandle.deriveFromBip85Path(
        xprvBase58: _masterXprv,
        hardenedPath: "9000'/1'/1'",
      ).publicKeyHex,
    );
    expect(
      bullnymAuthHandle.publicKeyHex,
      NostrKeychainHandle.deriveFromBip85Path(
        xprvBase58: _masterXprv,
        hardenedPath: "9000'/2'/1'",
      ).publicKeyHex,
    );
    expect(
      walletManifestHandle.publicKeyHex,
      isNot(bullnymAuthHandle.publicKeyHex),
    );
  });

  test('derives distinct role keys per role', () {
    final roleKeys = NostrIdentityRole.values
        .map(
          (role) =>
              usecase.execute(xprvBase58: _masterXprv, role: role).publicKeyHex,
        )
        .toSet();

    expect(roleKeys, hasLength(NostrIdentityRole.values.length));
  });
}
