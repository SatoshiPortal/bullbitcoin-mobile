import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

/// One optional field of an update.
///
/// Absent leaves the stored value alone; present carries the replacement, which
/// may be null to clear the field. A plain nullable parameter cannot say the
/// difference between "leave the hint" and "remove the hint".
final class KeychainManifestEdit<T> {
  final T value;

  const KeychainManifestEdit(this.value);
}

final class KeychainManifestWalletInventoryBinding {
  final String walletId;
  final Fingerprint seedFingerprint;
  final Network network;
  final ScriptType scriptType;
  final WalletProvenance provenance;
  final String derivationPath;
  final bool? seedPassphraseUsed;
  final String? descriptor;
  final String? label;
  final String? description;
  final int? createdAt;
  final int? updatedAt;

  const KeychainManifestWalletInventoryBinding({
    required this.walletId,
    required this.seedFingerprint,
    required this.network,
    required this.scriptType,
    required this.provenance,
    required this.derivationPath,
    required this.seedPassphraseUsed,
    this.descriptor,
    this.label,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  /// Whether the manifest may hold this binding at all.
  ///
  /// Watch-only and external-signer wallets have no seed to recover from, and a
  /// passphrase wallet without its combined public descriptor cannot be
  /// re-derived, so neither is recordable recovery truth (spec 20.1).
  bool get isRecordable =>
      (provenance == WalletProvenance.defaultSeed ||
          provenance == WalletProvenance.defaultSeedPassphrase ||
          provenance == WalletProvenance.importedMnemonic) &&
      (label?.trim().length ?? 0) <= KeychainManifestWallet.maxLabelLength &&
      (label == null ||
          !KeychainManifestNostrKey.hasControlCharacter(label!)) &&
      (description?.trim().length ?? 0) <=
          KeychainManifestEntry.maxDescriptionLength &&
      (description == null ||
          !KeychainManifestNostrKey.hasControlCharacter(description!)) &&
      (provenance != WalletProvenance.defaultSeedPassphrase ||
          (descriptor != null &&
              descriptor!.trim().isNotEmpty &&
              descriptor!.length <=
                  KeychainManifestWallet.maxDescriptorLength));

  /// The manifest entry this binding stands for, or null when its timestamps
  /// cannot make a valid entry.
  KeychainManifestEntry? tryToEntry(
    Fingerprint parentFingerprint, {
    required int fallbackTimestamp,
  }) {
    final created = createdAt ?? fallbackTimestamp;
    final updated = updatedAt ?? created;
    if (created < 0 || updated < created) return null;
    final entryId = KeychainManifestEntry.entryIdFor(
      parentFingerprint: parentFingerprint,
      derivationKind: KeychainManifestDerivationKind.bip32,
      derivationPath: derivationPath,
      seedFingerprint: seedFingerprint,
    );
    return KeychainManifestEntry(
      parentFingerprint: parentFingerprint,
      derivationKind: KeychainManifestDerivationKind.bip32,
      derivationPath: derivationPath,
      description: description,
      createdAt: created,
      updatedAt: updated,
      materializations: [
        KeychainManifestWallet(
          walletId: walletId,
          entryId: entryId,
          childSeedFingerprint: seedFingerprint,
          network: network,
          scriptType: scriptType,
          provenance: provenance,
          seedPassphraseUsed: seedPassphraseUsed,
          descriptor: descriptor,
          label: label,
          createdAt: created,
          updatedAt: updated,
        ),
      ],
    );
  }
}
