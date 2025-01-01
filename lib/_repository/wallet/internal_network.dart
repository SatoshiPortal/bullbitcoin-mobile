import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class InternalNetworkRepository {
  bdk.Blockchain? _bdkBlockchain;
  String? _bitcoinUrl;
  String? _liquidUrl;
  // bool _isTestnet = false;

  (bdk.Blockchain?, Err?) get bdkBlockchain => _bdkBlockchain != null
      ? (_bdkBlockchain, null)
      : (null, Err('Network not setup'));

  (String?, Err?) get bitcoinUrl => _bitcoinUrl != null
      ? (_bitcoinUrl, null)
      : (null, Err('Network not setup'));

  Err? setBitcoinUrl(String url) {
    _bitcoinUrl = url;
    return null;
  }

  (String?, Err?) get liquidUrl => _liquidUrl != null
      ? (_liquidUrl, null)
      : (null, Err('Network not setup'));

  Err? setLiquidUrl(String url) {
    _liquidUrl = url;
    return null;
  }

  Err? setBdkBlockchain(bdk.Blockchain blockchain) {
    _bdkBlockchain = blockchain;
    return null;
  }

  // Err? setTestnet(bool isTestnet) {
  //   _isTestnet = isTestnet;
  //   return null;
  // }

  // bool get isTestnet => _isTestnet;

  Err? checkNetworks() => (_bdkBlockchain == null || _liquidUrl == null)
      ? Err('Network not setup')
      : null;

  Err? checkNetworks2(bool isLiquid) =>
      isLiquid ? checkLiquidNetwork() : checkBitcoinNetwork();

  Err? checkBitcoinNetwork() =>
      (_bitcoinUrl == null) ? Err('Network not setup') : null;

  Err? checkLiquidNetwork() =>
      (_liquidUrl == null) ? Err('Network not setup') : null;
}
