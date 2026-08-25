import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';

final class WalletSigner {
  final String id;
  final SignerEntity signer;
  final SignerDeviceEntity? signerDevice;
  final List<WalletDescriptorKey> descriptorKeys;

  WalletSigner({
    required this.id,
    required this.signer,
    required this.signerDevice,
    required List<WalletDescriptorKey> descriptorKeys,
  }) : descriptorKeys = List.unmodifiable(descriptorKeys) {
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id');
    if (descriptorKeys.isEmpty) {
      throw ArgumentError.value(descriptorKeys, 'descriptorKeys');
    }
    if (descriptorKeys.any((key) => key.signerId != id)) {
      throw ArgumentError('Every descriptor key must reference its signer');
    }
  }

  factory WalletSigner.single({
    String id = 'signer-0',
    String descriptorKeyId = 'key-0',
    required String masterFingerprint,
    required String xpubFingerprint,
    required String xpub,
    String? derivationPath,
    String descriptorPath = '',
    required SignerEntity signer,
    required SignerDeviceEntity? signerDevice,
  }) => WalletSigner(
    id: id,
    signer: signer,
    signerDevice: signerDevice,
    descriptorKeys: [
      WalletDescriptorKey(
        id: descriptorKeyId,
        signerId: id,
        masterFingerprint: masterFingerprint,
        xpubFingerprint: xpubFingerprint,
        xpub: xpub,
        derivationPath: derivationPath,
        descriptorPath: descriptorPath,
      ),
    ],
  );

  String get displayFingerprint {
    for (final key in descriptorKeys) {
      if (key.masterFingerprint.isNotEmpty) return key.masterFingerprint;
      if (key.xpubFingerprint.isNotEmpty) return key.xpubFingerprint;
    }
    return '';
  }

  WalletSigner copyWith({
    SignerEntity? signer,
    SignerDeviceEntity? signerDevice,
    bool clearSignerDevice = false,
  }) => WalletSigner(
    id: id,
    signer: signer ?? this.signer,
    signerDevice: clearSignerDevice ? null : signerDevice ?? this.signerDevice,
    descriptorKeys: descriptorKeys,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletSigner &&
          id == other.id &&
          signer == other.signer &&
          signerDevice == other.signerDevice &&
          _listsEqual(descriptorKeys, other.descriptorKeys);

  @override
  int get hashCode =>
      Object.hash(id, signer, signerDevice, Object.hashAll(descriptorKeys));
}

bool _listsEqual<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
