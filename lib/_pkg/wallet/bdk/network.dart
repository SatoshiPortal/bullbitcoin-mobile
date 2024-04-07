import 'dart:async';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BDKNetwork {
  Future<(bdk.Blockchain?, Err?)> createBlockChain({
    required String url,
    required int stopGap,
    required int timeout,
    required int retry,
    required bool validateDomain,
  }) async {
    try {
      final blockchain = await bdk.Blockchain.create(
        config: bdk.BlockchainConfig.electrum(
          config: bdk.ElectrumConfig(
            url: url,
            retry: retry,
            timeout: timeout,
            stopGap: stopGap,
            validateDomain: validateDomain,
          ),
        ),
      );

      return (blockchain, null);
    } on Exception catch (r) {
      return (
        null,
        Err(
          r.message,
          // showAlert: true,
          title: 'Failed to connect to electrum',
        )
      );
    }
  }
}
