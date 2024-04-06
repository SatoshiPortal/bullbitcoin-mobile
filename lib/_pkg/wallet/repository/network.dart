import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class NetworkRepository {
  bdk.Blockchain? _bdkBlockchain;
  String? _liquidUrl;
  bool _isTestnet = false;

  (bdk.Blockchain?, Err?) get bdkBlockchain =>
      _bdkBlockchain != null ? (_bdkBlockchain, null) : (null, Err('Network not setup'));

  (String?, Err?) get liquidUrl =>
      _liquidUrl != null ? (_liquidUrl, null) : (null, Err('Network not setup'));

  Err? setLiquidUrl(String url) {
    _liquidUrl = url;
    return null;
  }

  Err? setBlockchain(bdk.Blockchain blockchain) {
    _bdkBlockchain = blockchain;
    return null;
  }

  Err? setTestnet(bool isTestnet) {
    _isTestnet = isTestnet;
    return null;
  }

  bool get isTestnet => _isTestnet;
}
