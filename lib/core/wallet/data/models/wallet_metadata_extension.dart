import 'dart:convert';

import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

extension WalletMetadataX on WalletMetadataModel {
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
