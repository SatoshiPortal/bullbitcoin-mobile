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
        script: bdk.Script(rawOutputScript: scriptPubkey),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );

      return address.toString();
    } catch (e) {
      // This is expected for non-address scripts (e.g. OP_RETURN) and
      // not really a bug so using fine instead of severe or warning to avoid
      // flooding the logger with it.
      log.fine(
        'error converting scriptPubkey to address',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }
}
