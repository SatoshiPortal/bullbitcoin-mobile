import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';

enum KeychainManifestNostrSystemKind {
  metadataBackup,
  bullnymAuth,
  nip05Verification,
  none,
}

final class KeychainManifestNostrKeyDisplay {
  final bool isSystem;
  final KeychainManifestNostrSystemKind systemKind;

  const KeychainManifestNostrKeyDisplay._(this.isSystem, this.systemKind);

  factory KeychainManifestNostrKeyDisplay.of(KeychainManifestEntry entry) {
    final key = entry.materializations.singleOrNull;
    final isSystem =
        key is KeychainManifestNostrKey &&
        key.keyKind == KeychainManifestNostrKeyKind.reserved;
    final kind = switch (Bip85Reservations.reservationByExactPath(
      entry.bip85DerivationPath,
    )) {
      Bip85Reservations.nostrWalletBackupKey =>
        KeychainManifestNostrSystemKind.metadataBackup,
      Bip85Reservations.nostrBullnymServerAuthKey =>
        KeychainManifestNostrSystemKind.bullnymAuth,
      Bip85Reservations.nostrNip05PublicNymVerificationKey =>
        KeychainManifestNostrSystemKind.nip05Verification,
      _ => KeychainManifestNostrSystemKind.none,
    };
    return KeychainManifestNostrKeyDisplay._(isSystem, kind);
  }
}
