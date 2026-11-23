import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/payment_request.dart';

void main() {
  PaymentRequest request(Network network) =>
      PaymentRequest.bip21(network: network, uri: '', address: '');

  test('BIP21 reports mainnet and testnet on both chains', () {
    for (final network in <Network>[
      BitcoinNetwork.mainnet,
      LiquidNetwork.mainnet,
    ]) {
      expect(request(network).isTestnet, isFalse);
    }
    for (final network in <Network>[
      BitcoinNetwork.testnet,
      LiquidNetwork.testnet,
    ]) {
      expect(request(network).isTestnet, isTrue);
    }
  });

  test('BIP21 never aliases regtest or signet to a historical network', () {
    for (final network in <Network>[
      BitcoinNetwork.regtest,
      LiquidNetwork.regtest,
      BitcoinNetwork.signet,
    ]) {
      final payment = request(network) as Bip21PaymentRequest;
      expect(payment.network, network);
      expect(
        () => payment.isTestnet,
        throwsA(isA<UnsupportedNetworkException>()),
      );
    }
  });
}
