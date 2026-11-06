import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart'
    show NetworkX;
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/foundation.dart';

class AddressScriptConversions {
  static Future<String?> bitcoinAddressFromScriptPubkey(
    Uint8List scriptPubkey, {
    required Network network,
  }) async {
    try {
      final address = bdk.Address.fromScript(
        script: bdk.Script(rawOutputScript: scriptPubkey),
        network: network.bdkNetwork,
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
