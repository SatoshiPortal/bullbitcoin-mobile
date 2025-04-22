import 'dart:typed_data';

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk/lwk.dart' as lwk;

class AddressScriptConversions {
  static Future<String> bitcoinAddressFromScriptPubkey(
    Uint8List scriptPubkey,
  ) async {
    final address = await bdk.Address.fromScript(
      script: bdk.ScriptBuf(bytes: scriptPubkey),
      network: bdk.Network.bitcoin,
    );

    return address.asString();
  }

  static Future<String> liquidAddressFromScript(
    String script, {
    required bool isTestnet,
  }) async {
    final address = await lwk.Address.addressFromScript(
      script: script,
      network: isTestnet ? lwk.Network.testnet : lwk.Network.mainnet,
    );
    return address.confidential;
  }
}
