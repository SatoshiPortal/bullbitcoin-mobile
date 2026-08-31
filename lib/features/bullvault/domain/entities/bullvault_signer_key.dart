import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';

enum BullVaultSignerRole { everyday, cold, secondCold, inheritance }

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

  String expression({required int receiveBranch, required int changeBranch}) {
    final derivationPath = accountKey.derivationPath;
    final origin = accountKey.masterFingerprint.isEmpty
        ? ''
        : '[${accountKey.masterFingerprint}${derivationPath == null ? '' : '/${_descriptorOriginPath(derivationPath)}'}]';
    return '$origin${accountKey.xpub}/<$receiveBranch;$changeBranch>/*';
  }

  static String _descriptorOriginPath(String path) {
    final normalized = path.startsWith('m/') ? path.substring(2) : path;
    return normalized.replaceAll('h', "'").replaceAll('H', "'");
  }
}
