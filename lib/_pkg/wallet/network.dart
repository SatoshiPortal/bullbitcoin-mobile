import 'dart:async';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/network.dart';
import 'package:bb_mobile/_repository/wallet/internal_network.dart';

class WalletNetwork implements IWalletNetwork {
  WalletNetwork({
    required InternalNetworkRepository networkRepository,
    required BDKNetwork bdkNetwork,
    // required Logger logger,
  })  : _networkRepository = networkRepository,
        _bdkNetwork = bdkNetwork;

  final InternalNetworkRepository _networkRepository;
  final BDKNetwork _bdkNetwork;
  // final Logger _logger;

  @override
  Future<Err?> createBlockChain({
    required String url,
    required bool isTestnet,
    int? stopGap,
    int? timeout,
    int? retry,
    bool? validateDomain,
  }) async {
    try {
      Uri.parse(url);
      if (stopGap != null) {
        final (blockchain, errCreate) = await _bdkNetwork.createBlockChain(
          url: url,
          stopGap: stopGap,
          timeout: timeout!,
          retry: retry!,
          validateDomain: validateDomain!,
        );
        if (errCreate != null) return errCreate;
        final errSetUrl = _networkRepository.setBitcoinUrl(url);
        if (errSetUrl != null) return errSetUrl;
        final errSet = _networkRepository.setBdkBlockchain(blockchain!);
        if (errSet != null) return errSet;
      } else {
        final errSet = _networkRepository.setLiquidUrl(url);
        if (errSet != null) return errSet;
      }

      // final errTestnet = _networkRepository.setTestnet(isTestnet);
      // if (errTestnet != null) return errTestnet;

      return null;
    } catch (r) {
      return Err(
        r.toString(),
        // showAlert: true,
        title: 'Failed to connect to electrum',
      );
    }
  }
}
