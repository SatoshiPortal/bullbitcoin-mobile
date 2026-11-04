import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

import 'signer_entity.dart';
import 'signer_device_entity.dart';
import 'wallet.dart';
import 'wallet_origin_codec.dart';

part 'wallet_metadata.freezed.dart';

@freezed
abstract class WalletMetadata with _$WalletMetadata {
  const factory WalletMetadata({
    required String id,
    required String masterFingerprint,
    required String xpubFingerprint,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required SignerEntity signer,
    required bool isDefault,
    @Default(0) int lastReceiveAddressIndex,
    String? label,
    DateTime? syncedAt,
    SignerDeviceEntity? signerDevice,
    DateTime? birthday,
  }) = _WalletMetadata;

  const WalletMetadata._();
}

extension WalletMetadataExtension on WalletMetadata {
  ({String account, String fingerprint, Network network, ScriptType script})
  get decodeOrigin => WalletOriginCodec.decodeOrigin(origin: id);

  String get account => decodeOrigin.account;
  String get fingerprint => decodeOrigin.fingerprint;

  /// The stored master fingerprint as a [Fingerprint], or null when it is
  /// not one — a watch-only wallet imported from a descriptor keeps the key
  /// origin verbatim, which may be uppercase or absent. Parsed rather than
  /// constructed so a signing path reports "no secret" instead of raising.
  Fingerprint? get seedFingerprint => Fingerprint.tryParse(masterFingerprint);
  Network get network => decodeOrigin.network;
  ScriptType get scriptType => decodeOrigin.script;
  bool get isBitcoin => decodeOrigin.network.isBitcoin;
  bool get isLiquid => decodeOrigin.network.isLiquid;
  bool get isMainnet => decodeOrigin.network.isMainnet;
  bool get isTestnet => decodeOrigin.network.isTestnet;
}
