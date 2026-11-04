import 'wallet.dart' show Network, ScriptType;

import 'signer_entity.dart';
import 'signer_device_entity.dart';
import 'wallet_metadata.dart';
import 'wallet_origin_codec.dart';

/// Public descriptor import independent of a parser or feature representation.
final class WatchOnlyWalletImport {
  final String masterFingerprint;
  final String pubkeyFingerprint;
  final Network network;
  final ScriptType scriptType;
  final SignerEntity signer;
  final SignerDeviceEntity? signerDevice;
  final String pubkey;
  final String externalDescriptor;
  final String internalDescriptor;
  final String label;

  const WatchOnlyWalletImport({
    required this.masterFingerprint,
    required this.pubkeyFingerprint,
    required this.network,
    required this.scriptType,
    required this.signer,
    required this.signerDevice,
    required this.pubkey,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.label,
  });

  WalletMetadata toMetadata() {
    return WalletMetadata(
      id: WalletOriginCodec.encodeOrigin(
        fingerprint: masterFingerprint,
        network: network,
        scriptType: scriptType,
      ),
      masterFingerprint: masterFingerprint,
      xpubFingerprint: pubkeyFingerprint,
      signer: signer,
      signerDevice: signerDevice,
      xpub: pubkey,
      externalPublicDescriptor: externalDescriptor,
      internalPublicDescriptor: internalDescriptor,
      isDefault: false,
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      label: label,
    );
  }
}
