import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Master BIP32 root key from the official BIP85 test vectors.
const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';
const _expectedWalletManifestNpubHex =
    '1072ff1a657708c194dcd1fa57d894eab3e8fca1b65950cee5c05f35a4425b9f';
const _expectedBullnymAuthNpubHex =
    '8b455c643d16fe546012f699b8f05eea4386268baa933b39dd1bbe0dc1965c4f';
const _expectedBullnymVerificationNpubHex =
    '852600604d65fea77a9d23e9623b7a5bab24b5314deb7f79419006363338047f';
const _expectedWalletMetadataNpubHex =
    '21ee43d352f3506c8cef5ee18f028efec0a2f71c510638afd0f7869f630a7dfd';

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
    final bullnymVerificationHandle = usecase.execute(
      xprvBase58: _masterXprv,
      role: NostrIdentityRole.bullnymNip05Verification,
    );
    final walletMetadataHandle = usecase.execute(
      xprvBase58: _masterXprv,
      role: NostrIdentityRole.walletMetadata,
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
      bullnymVerificationHandle.publicKeyHex,
      NostrKeychainHandle.deriveFromBip85Path(
        xprvBase58: _masterXprv,
        hardenedPath: "9000'/3'/1'",
      ).publicKeyHex,
    );
    expect(
      walletMetadataHandle.publicKeyHex,
      NostrKeychainHandle.deriveFromBip85Path(
        xprvBase58: _masterXprv,
        hardenedPath: "9000'/4'/1'",
      ).publicKeyHex,
    );
    expect(
      walletManifestHandle.publicKeyHex,
      isNot(bullnymAuthHandle.publicKeyHex),
    );
    expect(
      bullnymAuthHandle.publicKeyHex,
      isNot(bullnymVerificationHandle.publicKeyHex),
    );
    expect(
      walletMetadataHandle.publicKeyHex,
      isNot(walletManifestHandle.publicKeyHex),
    );
  });

  test('matches canonical registration identity fixtures', () {
    final keys = {
      NostrIdentityRole.walletManifest: _expectedWalletManifestNpubHex,
      NostrIdentityRole.bullnymServerAuth: _expectedBullnymAuthNpubHex,
      NostrIdentityRole.bullnymNip05Verification:
          _expectedBullnymVerificationNpubHex,
      NostrIdentityRole.walletMetadata: _expectedWalletMetadataNpubHex,
    };

    for (final entry in keys.entries) {
      final publicKeyHex = usecase
          .execute(xprvBase58: _masterXprv, role: entry.key)
          .publicKeyHex;
      expect(publicKeyHex, entry.value);
      expect(publicKeyHex, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
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
