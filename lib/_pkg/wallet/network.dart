import 'dart:async';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletNetwork implements IWalletNetwork {
  WalletNetwork({required NetworkRepository networkRepository})
      : _networkRepository = networkRepository;

  final NetworkRepository _networkRepository;

  @override
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

      final err = _networkRepository.setBlockchain(blockchain);
      if (err != null) return err;

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
