import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show ScriptType;

class WalletMetadataService {
  static String encodeOrigin({
    required String fingerprint,
    required Network network,
    required ScriptType scriptType,
  }) {
    final networkPath = switch (network) {
      Network.bitcoinMainnet => '0h',
      Network.liquidMainnet => '1776h',
      Network.bitcoinTestnet ||
      Network.bitcoinRegtest ||
      Network.liquidTestnet ||
      Network.liquidRegtest => '1h',
    };

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
    final match = RegExp(r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]')
        .firstMatch(origin);

    if (match == null) throw 'Invalid origin format';

    final fingerprint = match.group(1);
    final matchingScript = match.group(2);
    final matchingNetwork = match.group(3);
    final account = match.group(4);
    if (fingerprint == null ||
        matchingScript == null ||
        matchingNetwork == null ||
        account == null) {
      throw 'Invalid origin format';
    }

    final script = switch (matchingScript) {
      '84h' => ScriptType.bip84,
      '49h' => ScriptType.bip49,
      '44h' => ScriptType.bip44,
      _ => throw 'Unknown origin script',
    };

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
        throw 'Unknown origin network';
    }

    return (
      fingerprint: fingerprint,
      network: network,
      script: script,
      account: account,
    );
  }

  static const regtestSuffix = ':regtest';

  /// The derivation origin stays suitable for BIP329 on every network.
  static String originFromId(String id) => id.endsWith(regtestSuffix)
      ? id.substring(0, id.length - regtestSuffix.length)
      : id;

  static String encodeId({
    required String fingerprint,
    required Network network,
    required ScriptType scriptType,
  }) {
    final origin = encodeOrigin(
      fingerprint: fingerprint,
      network: network,
      scriptType: scriptType,
    );
    return switch (network) {
      Network.bitcoinRegtest ||
      Network.liquidRegtest => '$origin$regtestSuffix',
      _ => origin,
    };
  }

  /// Parses derivation metadata without treating its coin type as a network.
  static ({String fingerprint, ScriptType script, String account}) parseOrigin({
    required String origin,
  }) {
    final match = RegExp(r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]')
        .firstMatch(origin);
    final fingerprint = match?.group(1);
    final purpose = match?.group(2);
    final account = match?.group(4);
    if (fingerprint == null || purpose == null || account == null) {
      throw 'Invalid origin format';
    }
    final script = switch (purpose) {
      '84h' => ScriptType.bip84,
      '49h' => ScriptType.bip49,
      '44h' => ScriptType.bip44,
      _ => throw 'Unknown origin script',
    };
    return (fingerprint: fingerprint, script: script, account: account);
  }
}
