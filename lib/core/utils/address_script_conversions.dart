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
      // This is expected for non-address scripts (e.g. OP_RETURN) and
      // not really a bug so using fine instead of severe or warning to avoid
      // flooding the logger with it.
      log.info(
        'error converting scriptPubkey to address',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }
}
