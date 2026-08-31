import 'package:bull_swap/bull_swap.dart';
import 'package:test/test.dart';

void main() {
  test('apiName is the enum name', () {
    expect(OrderSwapNetwork.bitcoin.apiName, 'bitcoin');
    expect(OrderSwapNetwork.liquid.apiName, 'liquid');
    expect(OrderSwapNetwork.lightning.apiName, 'lightning');
  });

  test('converts to and from the neutral SwapNetwork', () {
    for (final n in OrderSwapNetwork.values) {
      expect(OrderSwapNetwork.fromSwapNetwork(n.toSwapNetwork), n);
    }
    expect(OrderSwapNetwork.bitcoin.toSwapNetwork, SwapNetwork.bitcoin);
    expect(OrderSwapNetwork.liquid.toSwapNetwork, SwapNetwork.liquid);
    expect(OrderSwapNetwork.lightning.toSwapNetwork, SwapNetwork.lightning);
  });
}
