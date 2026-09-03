import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

enum BullVaultSignerRole {
  everyday,
  delayedMobileRecovery,
  cold,
  secondCold,
  inheritance,
}

final class BullVaultSignerKey {
  final BullVaultSignerRole role;
  final WalletDescriptorKey accountKey;
  final SignerEntity signer;
  final SignerDeviceEntity? signerDevice;

  BullVaultSignerKey({
    required this.role,
    required this.accountKey,
    required this.signer,
    required this.signerDevice,
  }) {
    if (accountKey.xpub.isEmpty) {
      throw ArgumentError('BullVault signers require an extended public key');
    }
  }

  static List<WalletSigner>? assignDescriptorKeys(
    List<WalletDescriptorKey> descriptorKeys,
    List<BullVaultSignerKey> signers, {
    String? localSeedFingerprint,
    List<WalletSigner>? existingSigners,
  }) {
    String canonicalXpub(String xpub) =>
        Bip32Derivation.getBip32Xpub(xpub).toBase58();
    final keysByXpub = <String, List<WalletDescriptorKey>>{};
    for (final key in descriptorKeys) {
      keysByXpub.putIfAbsent(canonicalXpub(key.xpub), () => []).add(key);
    }
    final annotations = <String, WalletSigner>{};
    for (final signer in signers) {
      final xpub = canonicalXpub(signer.accountKey.xpub);
      final keys = keysByXpub[xpub];
      if (keys == null) return null;
      final source = existingSigners?.singleWhere(
        (candidate) => candidate.descriptorKeys.any(
          (key) => canonicalXpub(key.xpub) == xpub,
        ),
      );
      // The passphrase key and delayed recovery key share one mobile signer.
      final id = signer.role == BullVaultSignerRole.delayedMobileRecovery
          ? BullVaultSignerRole.everyday.name
          : signer.role.name;
      final existing = annotations[id];
      annotations[id] = WalletSigner(
        id: id,
        signer: existing?.signer ?? source?.signer ?? signer.signer,
        signerDevice:
            existing?.signerDevice ??
            source?.signerDevice ??
            signer.signerDevice,
        registrationName:
            existing?.registrationName ?? source?.registrationName,
        localSeedFingerprint:
            existing?.localSeedFingerprint ??
            source?.localSeedFingerprint ??
            (signer.signer == SignerEntity.local ? localSeedFingerprint : null),
        descriptorKeys: [
          ...?existing?.descriptorKeys,
          for (final key in keys)
            key.copyWith(
              signerId: id,
              requiresPassphrase: signer.accountKey.requiresPassphrase,
            ),
        ],
      );
    }
    return annotations.values.toList();
  }

  String expression({required int receiveBranch, required int changeBranch}) {
    final derivationPath = accountKey.derivationPath;
    final origin = accountKey.masterFingerprint.isEmpty
        ? ''
        : '[${accountKey.masterFingerprint}${derivationPath == null ? '' : '/${_descriptorOriginPath(derivationPath)}'}]';
    return '$origin${accountKey.xpub}/<$receiveBranch;$changeBranch>/*';
  }

  BullVaultSignerKey copyWith({
    WalletDescriptorKey? accountKey,
    SignerEntity? signer,
    SignerDeviceEntity? signerDevice,
    bool clearSignerDevice = false,
  }) => BullVaultSignerKey(
    role: role,
    accountKey: accountKey ?? this.accountKey,
    signer: signer ?? this.signer,
    signerDevice: clearSignerDevice ? null : signerDevice ?? this.signerDevice,
  );

  static String _descriptorOriginPath(String path) {
    final normalized = path.startsWith('m/') ? path.substring(2) : path;
    return normalized.replaceAll('h', "'").replaceAll('H', "'");
  }
}
