import 'dart:typed_data';

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk/lwk.dart' as lwk;

class AddressScriptConversions {
  static Future<Uint8List> scriptPubkeyFromBitcoinAddress(
    String address, {
    required bool isTestnet,
  }) async {
    final addr = await bdk.Address.fromString(
      s: address,
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    return addr.scriptPubkey().bytes;
  }

  static Future<String> bitcoinAddressFromScriptPubkey(
    Uint8List scriptPubkey, {
    required bool isTestnet,
  }) async {
    final address = await bdk.Address.fromScript(
      script: bdk.ScriptBuf(bytes: scriptPubkey),
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
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
