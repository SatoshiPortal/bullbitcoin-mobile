import 'wallet.dart';

/// Encodes the legacy wallet identity shared by storage and BIP329 origins.
class WalletOriginCodec {
  static String encodeOrigin({
    required String fingerprint,
    required Network network,
    required ScriptType scriptType,
  }) {
    String networkPath;
    if (network.isBitcoin && network.isMainnet) {
      networkPath = "0h";
    } else if (network.isLiquid && network.isMainnet) {
      networkPath = "1776h";
    } else if (network.isTestnet) {
      networkPath = "1h";
    } else {
      throw 'Unexpected network path';
    }

    String prefixFormat = '';
    String scriptPath = '';
    switch (scriptType) {
      case ScriptType.bip84:
        prefixFormat = network.isBitcoin ? 'wpkh([*])' : 'elwpkh([*])';
        scriptPath = '84h';
      case ScriptType.bip49:
        prefixFormat = network.isBitcoin ? 'sh(wpkh([*]))' : 'elsh(wpkh([*]))';
        scriptPath = '49h';
      case ScriptType.bip44:
        prefixFormat = network.isBitcoin ? 'pkh([*])' : 'elpkh([*])';
        scriptPath = '44h';
    }

    const String accountPath = '0h';
    final path = '[$fingerprint/$scriptPath/$networkPath/$accountPath]';
    return prefixFormat.replaceAll('[*]', path);
  }

  static ({
    String fingerprint,
    Network network,
    ScriptType script,
    String account,
  })
  decodeOrigin({required String origin}) {
    final match = RegExp(
      r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]',
    ).firstMatch(origin);

    if (match == null) throw 'Invalid origin format: $origin';

    final fingerprint = match.group(1);
    final matchingScript = match.group(2);
    final matchingNetwork = match.group(3);
    final account = match.group(4);
    if (fingerprint == null ||
        matchingScript == null ||
        matchingNetwork == null ||
        account == null) {
      throw 'Invalid origin format: $origin';
    }

    ScriptType script;
    switch (matchingScript) {
      case '84h':
        script = ScriptType.bip84;
      case '49h':
        script = ScriptType.bip49;
      case '44h':
        script = ScriptType.bip44;
      default:
        throw 'Unknown script: $matchingScript';
    }

    Network network;
    switch (matchingNetwork) {
      case '0h':
        network = Network.bitcoinMainnet;
      case '1h':
        if (origin.contains('elwpkh(') ||
            origin.contains('elsh(wpkh(') ||
            origin.contains('elpkh(')) {
          network = Network.liquidTestnet;
        } else {
          network = Network.bitcoinTestnet;
        }
      case '1776h':
        network = Network.liquidMainnet;

      default:
        throw 'Unknown script: $matchingNetwork';
    }

    return (
      fingerprint: fingerprint,
      network: network,
      script: script,
      account: account,
    );
  }
}
