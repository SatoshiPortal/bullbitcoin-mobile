import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/foundation.dart';

class AddressScriptConversions {
  static Future<String?> bitcoinAddressFromScriptPubkey(
    Uint8List scriptPubkey, {
    required bool isTestnet,
  }) async {
    try {
      final address = await bdk.Address.fromScript(
        script: bdk.ScriptBuf(bytes: scriptPubkey),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );

      return address.asString();
    } catch (e) {
      log.severe('error converting scriptPubkey to address: $e', trace: StackTrace.current);
      return null;
    }
  }
}
