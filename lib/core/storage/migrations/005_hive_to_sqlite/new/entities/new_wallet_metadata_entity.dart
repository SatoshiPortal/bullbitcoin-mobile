import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_wallet_metadata_entity.freezed.dart';

enum NewNetwork {
  bitcoinMainnet(
    coinType: 0,
    isBitcoin: true,
    isLiquid: false,
    isMainnet: true,
    isTestnet: false,
  ),
  bitcoinTestnet(
    coinType: 1,
    isBitcoin: true,
    isLiquid: false,
    isMainnet: false,
    isTestnet: true,
  ),
  liquidMainnet(
    coinType: 1776,
    isBitcoin: false,
    isLiquid: true,
    isMainnet: true,
    isTestnet: false,
  ),
  liquidTestnet(
    coinType: 1,
    isBitcoin: false,
    isLiquid: true,
    isMainnet: false,
    isTestnet: true,
  );

  final int coinType;
  final bool isBitcoin;
  final bool isLiquid;
  final bool isMainnet;
  final bool isTestnet;

  const NewNetwork({
    required this.coinType,
    required this.isBitcoin,
    required this.isLiquid,
    required this.isMainnet,
    required this.isTestnet,
  });

  factory NewNetwork.fromName(String name) {
    return NewNetwork.values.firstWhere((network) => network.name == name);
  }

  factory NewNetwork.fromEnvironment({
    required bool isTestnet,
    required bool isLiquid,
  }) {
    if (isLiquid) {
      return isTestnet ? NewNetwork.liquidTestnet : NewNetwork.liquidMainnet;
    } else {
      return isTestnet ? NewNetwork.bitcoinTestnet : NewNetwork.bitcoinMainnet;
    }
  }
}

enum NewScriptType {
  bip84(purpose: 84),
  bip49(purpose: 49),
  bip44(purpose: 44);

  final int purpose;

  const NewScriptType({required this.purpose});

  static NewScriptType fromName(String name) {
    return NewScriptType.values.firstWhere((script) => script.name == name);
  }
}

@freezed
abstract class NewWallet with _$NewWallet {
  const factory NewWallet({
    required String origin,
    @Default('') String label,
    required NewNetwork network,
    @Default(false) bool isDefault,
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required NewScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required dynamic source,
    required BigInt balanceSat,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    DateTime? latestEncryptedBackup,
    DateTime? latestPhysicalBackup,
  }) = _NewWallet;

  const NewWallet._();

  String get id => origin;

  String getWalletTypeString() {
    return switch (network) {
      NewNetwork.bitcoinMainnet ||
      NewNetwork.bitcoinTestnet => 'Bitcoin network',
      NewNetwork.liquidMainnet ||
      NewNetwork.liquidTestnet => 'Liquid and Lightning network',
    };
  }

  String getLabel() {
    if (!isDefault) return label;
    return switch (network) {
      NewNetwork.bitcoinMainnet ||
      NewNetwork.bitcoinTestnet => 'Secure Bitcoin wallet',
      NewNetwork.liquidMainnet ||
      NewNetwork.liquidTestnet => 'Instant payments wallet',
    };
  }

  bool get isTestnet {
    return network == NewNetwork.bitcoinTestnet ||
        network == NewNetwork.liquidTestnet;
  }

  bool get isLiquid {
    return network == NewNetwork.liquidMainnet ||
        network == NewNetwork.liquidTestnet;
  }

  bool get isWatchOnly => false;
}

String newEncodeOrigin({
  required String fingerprint,
  required NewNetwork network,
  required NewScriptType scriptType,
}) {
  String networkPath;
  if (network.isBitcoin && network.isMainnet) {
    networkPath = "0h";
  } else if (network.isBitcoin && network.isTestnet) {
    networkPath = "1h";
  } else if (network.isLiquid && network.isMainnet) {
    networkPath = "1667h";
  } else if (network.isLiquid && network.isTestnet) {
    networkPath = "1668h";
  } else {
    throw 'Unexpected network path';
  }

  String prefixFormat = '';
  String scriptPath = '';
  switch (scriptType) {
    case NewScriptType.bip84:
      prefixFormat = network.isBitcoin ? 'wpkh([*])' : 'elwpkh([*])';
      scriptPath = '84h';
    case NewScriptType.bip49:
      prefixFormat = network.isBitcoin ? 'sh(wpkh([*]))' : 'elsh(wpkh([*]))';
      scriptPath = '49h';
    case NewScriptType.bip44:
      prefixFormat = network.isBitcoin ? 'pkh([*])' : 'elpkh([*])';
      scriptPath = '44h';
  }

  const String accountPath = '0h';
  final path = '[$fingerprint/$scriptPath/$networkPath/$accountPath]';
  return prefixFormat.replaceAll('[*]', path);
}
