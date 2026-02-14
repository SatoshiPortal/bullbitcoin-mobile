import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter/foundation.dart';

class AddressScriptConversions {
  static Future<String?> bitcoinAddressFromScriptPubkey(
    Uint8List scriptPubkey, {
    required bool isTestnet,
  }) async {
    try {
      final address = bdk.Address.fromScript(
        bdk.Script(scriptPubkey),
        isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );

      return address.toString();
    } catch (e) {
      log.severe(
        message: 'error converting scriptPubkey to address',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }
}
