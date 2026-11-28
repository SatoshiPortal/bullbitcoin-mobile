import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show Environment, Swap, SwapStatus, SwapType;
import 'package:sync/sync.dart' show WalletKey;

import '../support/overview_home_harness.dart';

Swap _swap(String id) => Swap.lnSend(
  id: id,
  keyIndex: 0,
  type: SwapType.liquidToLightning,
  status: SwapStatus.pending,
  environment: Environment.regtest,
  creationTime: DateTime.utc(2026, 1, 1),
  sendWalletId: 'liquid',
  invoice: 'lnbc1example',
  paymentAddress: 'lq1example',
  paymentAmount: 10000,
);

void main() {
  test('an older swap read cannot overwrite a later wallet finish', () async {
    final h = OverviewHomeHarness()..swaps.manual = true;
    await h.mount();
    addTearDown(h.close);
    h.swaps.complete(const Ok([]));
    await flushEvents();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [homeWallet('btc')]),
    );
    await flushEvents();
    final key = WalletKey(id: 'btc', network: BitcoinNetwork.regtest);
    h.finished.add(key);
    await flushEvents();
    h.finished.add(key);
    await flushEvents();
    // The current contract performs one read per finish, without coalescing.
    expect(h.swaps.reads, 3);
    final newer = _swap('newer');
    h.swaps.completeAt(1, Ok([newer]));
    await flushEvents();
    expect(h.controller.current.ongoingSwaps, [newer]);
    h.swaps.completeAt(0, Ok([_swap('older')]));
    await flushEvents();
    expect(h.controller.current.ongoingSwaps, [newer]);
  });
}
