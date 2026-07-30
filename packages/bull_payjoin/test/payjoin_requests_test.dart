import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('sender request rejects a zero amount', () {
    expect(
      () => StartPayjoinSender(
        walletId: 'wallet',
        network: BitcoinNetwork.mainnet,
        bip21Uri: 'bitcoin:address?pj=https://example.com',
        unsignedOriginalPsbt: 'psbt',
        amount: Sats.zero,
        feeRate: FeeRate(1),
      ),
      throwsArgumentError,
    );
  });

  test('receiver request rejects blank identifiers', () {
    expect(
      () => StartPayjoinReceiver(
        walletId: ' ',
        network: BitcoinNetwork.mainnet,
        address: 'address',
      ),
      throwsArgumentError,
    );
  });

  test('session filter rejects a blank wallet constraint', () {
    expect(() => PayjoinSessionFilter(walletId: ''), throwsArgumentError);
  });

  test(
    'receiver requests reject networks collapsed to testnet by the engine',
    () {
      for (final network in [BitcoinNetwork.signet, BitcoinNetwork.regtest]) {
        expect(
          () => StartPayjoinReceiver(
            walletId: 'wallet',
            network: network,
            address: 'address',
          ),
          throwsArgumentError,
          reason: '$network must not be silently executed on testnet',
        );
      }
    },
  );
}
