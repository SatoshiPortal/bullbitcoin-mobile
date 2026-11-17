import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';

void main() {
  test('Liquid regtest retains its identity and carries no real value', () {
    final network = Network.fromLwkNetwork(lwk.LiquidNetwork.regtest);
    expect(network, Network.liquidRegtest);
    expect(network.isLiquid, isTrue);
    expect(network.isBitcoin, isFalse);
    expect(network.isMainnet, isFalse);
    expect(network.isTestnet, isTrue);
    expect(network, isNot(Network.liquidTestnet));
  });
}
