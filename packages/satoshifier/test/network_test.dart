import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/enums/network.dart';

void main() {
  group('Network', () {
    test('classifies signet and regtest as test networks', () {
      expect(Network.bitcoinSignet.isTestnet, isTrue);
      expect(Network.bitcoinRegtest.isTestnet, isTrue);
    });

    test('classifies only mainnet as production', () {
      expect(Network.bitcoinMainnet.isMainnet, isTrue);
      expect(Network.liquidMainnet.isMainnet, isTrue);

      expect(Network.bitcoinTestnet.isMainnet, isFalse);
      expect(Network.bitcoinSignet.isMainnet, isFalse);
      expect(Network.bitcoinRegtest.isMainnet, isFalse);
      expect(Network.liquidTestnet.isMainnet, isFalse);
    });

    test('classifies addresses from their own encoding', () {
      expect(
        Network.fromBitcoinAddress(
          'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
        ),
        Network.bitcoinMainnet,
      );
      expect(
        Network.fromBitcoinAddress('17VZNX1SN5NtKa8UQFxwQbFeFc3iqRYhem'),
        Network.bitcoinMainnet,
      );
      expect(
        Network.fromBitcoinAddress('3EktnHQD7RiAE6uzMj2ZifT9YgRrkSgzQX'),
        Network.bitcoinMainnet,
      );
      expect(
        Network.fromBitcoinAddress(
          'bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080',
        ),
        Network.bitcoinRegtest,
      );
      expect(Network.fromBitcoinAddress('not-an-address'), isNull);
    });

    test('classifies bech32 case-insensitively', () {
      expect(
        Network.fromBitcoinAddress(
          'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4',
        ),
        Network.bitcoinMainnet,
      );
    });

    test('reports the shared test-network encodings as a test network', () {
      // testnet3, testnet4 and signet share the 'tb' HRP, and every test-kind
      // base58 address shares one version byte with regtest too, so the exact
      // chain is not recoverable from the address. What must hold is that none
      // of them is ever mistaken for mainnet.
      for (final address in [
        'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
        'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn',
        'n2eMqTT929pb1RDNuqEnxdaLau1rxy3efi',
        '2MzQwSSnBHWHqSAqtTVQ6v47XtaisrJa1Vc',
      ]) {
        final network = Network.fromBitcoinAddress(address);
        expect(network, isNotNull, reason: address);
        expect(network!.isMainnet, isFalse, reason: address);
        expect(network.isTestnet, isTrue, reason: address);
      }
    });

    test('isTestnet is the exact complement of isMainnet', () {
      for (final network in Network.values) {
        expect(
          network.isTestnet,
          !network.isMainnet,
          reason: '$network must be either mainnet or a test network',
        );
      }
    });
  });
}
