import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';
part 'wallet_metadata_model.g.dart';

@freezed
class WalletMetadataModel with _$WalletMetadataModel {
  factory WalletMetadataModel({
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required bool isBitcoin,
    required bool isLiquid,
    required bool isMainnet,
    required bool isTestnet,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
    @Default(false) bool isDefault,
    @Default('') String label,
    DateTime? syncedAt,
  }) = _WalletMetadataModel;
  const WalletMetadataModel._();

  factory WalletMetadataModel.fromJson(Map<String, Object?> json) =>
      _$WalletMetadataModelFromJson(json);

  String get id => origin;

  String get origin {
    String networkPath;
    if (isBitcoin && isMainnet) {
      networkPath = "0h";
    } else if (isBitcoin && isTestnet) {
      networkPath = "1h";
    } else if (isLiquid && isMainnet) {
      networkPath = "1667h";
    } else if (isLiquid && isTestnet) {
      networkPath = "1668h";
    } else {
      throw '';
    }

    String prefixFormat = '';
    String scriptPath = '';
    switch (ScriptType.fromName(scriptType)) {
      case ScriptType.bip84:
        prefixFormat = isBitcoin ? 'wpkh([*])' : 'elwpkh([*])';
        scriptPath = '84h';
      case ScriptType.bip49:
        prefixFormat = isBitcoin ? 'sh(wpkh([*]))' : 'elsh(wpkh([*]))';
        scriptPath = '49h';
      case ScriptType.bip44:
        prefixFormat = isBitcoin ? 'pkh([*])' : 'elpkh([*])';
        scriptPath = '44h';
    }

    const String accountPath = '0h';
    final path = '[$masterFingerprint/$scriptPath/$networkPath/$accountPath]';
    return prefixFormat.replaceAll('[*]', path);
  }

  ({
    String fingerprint,
    Network network,
    ScriptType script,
    String account,
  }) decodeOrigin() {
    final list = json.decode(origin) as List<String>;

    ScriptType script;
    switch (list[1]) {
      case '84h':
        script = ScriptType.bip84;
      case '49h':
        script = ScriptType.bip49;
      case '44h':
        script = ScriptType.bip44;
      default:
        throw 'Unknown script: ${list[1]}';
    }

    Network network;
    switch (list[2]) {
      case '0h':
        network = Network.bitcoinMainnet;
      case '1h':
        network = Network.bitcoinTestnet;
      case '1667h':
        network = Network.liquidMainnet;
      case '1668h':
        network = Network.liquidTestnet;
      default:
        throw 'Unknown script: ${list[2]}';
    }

    return (
      fingerprint: list.first,
      network: network,
      script: script,
      account: list.last
    );
  }
}
