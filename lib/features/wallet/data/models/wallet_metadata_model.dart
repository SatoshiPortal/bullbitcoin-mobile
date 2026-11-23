import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart' show Fingerprint, ScriptType;

part 'wallet_metadata_model.freezed.dart';

@freezed
abstract class WalletMetadataModel with _$WalletMetadataModel {
  const factory WalletMetadataModel({
    required String id,
    required String networkCode,
    required String masterFingerprint,
    required String xpubFingerprint,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required Signer signer,
    required bool isDefault,
    @Default(0) int lastReceiveAddressIndex,
    String? label,
    DateTime? syncedAt,
    SignerDevice? signerDevice,
    DateTime? birthday,
  }) = _WalletMetadataModel;

  const WalletMetadataModel._();
}

extension WalletMetadataModelExtension on WalletMetadataModel {
  ({String account, String fingerprint, ScriptType script}) get parsedOrigin =>
      WalletMetadataService.parseOrigin(origin: origin);

  String get origin => WalletMetadataService.originFromId(id);

  Network get network => WalletNetworkCodec.decode(networkCode);

  String get account => parsedOrigin.account;
  String get fingerprint => parsedOrigin.fingerprint;

  /// The stored master fingerprint as a [Fingerprint], or null when it is
  /// not one — a watch-only wallet imported from a descriptor keeps the key
  /// origin verbatim, which may be uppercase or absent. Parsed rather than
  /// constructed so a signing path reports "no secret" instead of raising.
  Fingerprint? get seedFingerprint => Fingerprint.tryParse(masterFingerprint);
  ScriptType get scriptType => parsedOrigin.script;
  bool get isBitcoin => network.isBitcoin;
  bool get isLiquid => network.isLiquid;
  bool get isMainnet => network.isMainnet;
}
