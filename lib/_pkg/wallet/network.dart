import 'dart:async';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletNetwork {
  bdk.Blockchain? _blockchain;

  (bdk.Blockchain?, Err?) get blockchain =>
      _blockchain != null ? (_blockchain, null) : (null, Err('Network not setup'));

  Future<Err?> createBlockChain({
    required int stopGap,
    required int timeout,
    required int retry,
    required String url,
    required bool validateDomain,
  }) async {
    try {
      Uri.parse(url);
      if (locator.isRegistered<Logger>()) locator.get<Logger>().log('Connecting to $url');

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

      _blockchain = blockchain;

      return null;
    } on Exception catch (r) {
      return Err(
        r.message,
        // showAlert: true,
        title: 'Failed to connect to electrum',
      );
    }
  }
}
