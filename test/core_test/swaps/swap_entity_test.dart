import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // BOLT11 test vector: 2500u = 0.0025 BTC = 250 000 sats.
  const bolt11Invoice =
      'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypq'
      'dq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2aw'
      'hz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp';

  Swap lnSendSwap(String invoice) => Swap.lnSend(
    id: 'swap-1',
    keyIndex: 0,
    type: SwapType.bitcoinToLightning,
    status: SwapStatus.pending,
    environment: Environment.mainnet,
    creationTime: DateTime(2026),
    sendWalletId: 'wallet-1',
    invoice: invoice,
    paymentAddress: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
    paymentAmount: 0,
  );

  group('Swap.amountSat', () {
    test('decodes the bolt11 invoice amount exactly', () {
      expect(lnSendSwap(bolt11Invoice).amountSat, 250000);
    });

    test('returns 0 for an empty invoice (restored swap)', () {
      expect(lnSendSwap('').amountSat, 0);
    });

    test('returns 0 for an unparseable invoice', () {
      expect(lnSendSwap('lnbc10u1invoice').amountSat, 0);
    });

    test('chain swap uses the payment amount directly', () {
      final swap = Swap.chain(
        id: 'swap-2',
        keyIndex: 0,
        type: SwapType.bitcoinToLiquid,
        status: SwapStatus.pending,
        environment: Environment.mainnet,
        creationTime: DateTime(2026),
        sendWalletId: 'wallet-1',
        paymentAddress: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
        paymentAmount: 123456,
      );
      expect(swap.amountSat, 123456);
    });
  });
}
