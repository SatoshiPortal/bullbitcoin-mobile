import 'package:signers/signers.dart' as signers;
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:legacy_storage/app_database.dart' show Signer, SignerDevice;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:primitives/primitives.dart'
    show Fingerprint, ScriptType, SignerEntity;

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

extension WalletMetadataSignerMapping on Signer {
  SignerEntity toEntity() => switch (this) {
    Signer.local => SignerEntity.local,
    Signer.remote => SignerEntity.remote,
    Signer.none => SignerEntity.none,
  };
}

extension WalletMetadataSignerEntityMapping on SignerEntity {
  Signer toSqlite() => switch (this) {
    SignerEntity.local => Signer.local,
    SignerEntity.remote => Signer.remote,
    SignerEntity.none => Signer.none,
  };
}

extension WalletMetadataDeviceMapping on SignerDevice {
  signers.SignerDevice toEntity() => switch (this) {
    SignerDevice.bitbox02 => signers.SignerDevice.bitbox02,
    SignerDevice.coldcardQ => signers.SignerDevice.coldcardQ,
    SignerDevice.coldcardMk4 => signers.SignerDevice.coldcardMk4,
    SignerDevice.jade => signers.SignerDevice.jade,
    SignerDevice.keystone => signers.SignerDevice.keystone,
    SignerDevice.krux => signers.SignerDevice.krux,
    SignerDevice.ledgerNanoSPlus => signers.SignerDevice.ledgerNanoSPlus,
    SignerDevice.ledgerNanoX => signers.SignerDevice.ledgerNanoX,
    SignerDevice.ledgerFlex => signers.SignerDevice.ledgerFlex,
    SignerDevice.ledgerStax => signers.SignerDevice.ledgerStax,
    SignerDevice.passport => signers.SignerDevice.passport,
    SignerDevice.seedsigner => signers.SignerDevice.seedsigner,
    SignerDevice.specter => signers.SignerDevice.specter,
  };
}

extension WalletMetadataSignerDeviceMapping on signers.SignerDevice {
  SignerDevice toSqlite() => switch (this) {
    signers.SignerDevice.bitbox02 => SignerDevice.bitbox02,
    signers.SignerDevice.coldcardQ => SignerDevice.coldcardQ,
    signers.SignerDevice.coldcardMk4 => SignerDevice.coldcardMk4,
    signers.SignerDevice.jade => SignerDevice.jade,
    signers.SignerDevice.keystone => SignerDevice.keystone,
    signers.SignerDevice.krux => SignerDevice.krux,
    signers.SignerDevice.ledgerNanoSPlus => SignerDevice.ledgerNanoSPlus,
    signers.SignerDevice.ledgerNanoX => SignerDevice.ledgerNanoX,
    signers.SignerDevice.ledgerFlex => SignerDevice.ledgerFlex,
    signers.SignerDevice.ledgerStax => SignerDevice.ledgerStax,
    signers.SignerDevice.passport => SignerDevice.passport,
    signers.SignerDevice.seedsigner => SignerDevice.seedsigner,
    signers.SignerDevice.specter => SignerDevice.specter,
  };
}
