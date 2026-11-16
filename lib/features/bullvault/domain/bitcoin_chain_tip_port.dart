import 'package:primitives/primitives.dart' show BitcoinNetwork;

abstract interface class BitcoinChainTipPort {
  Future<({int height, int medianTimePast})> getChainTip({
    required BitcoinNetwork network,
  });
}
