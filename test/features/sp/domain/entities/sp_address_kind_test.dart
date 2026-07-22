import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifySpAddress', () {
    test('sp1 is a mainnet silent payment', () {
      expect(
        classifySpAddress('sp1qexample'),
        SpAddressKind.silentPaymentMainnet,
      );
    });

    test('tsp1 is a testnet-family silent payment', () {
      expect(
        classifySpAddress('tsp1qexample'),
        SpAddressKind.silentPaymentTestnet,
      );
    });

    test('sprt1 is a regtest silent payment (not mainnet)', () {
      expect(
        classifySpAddress('sprt1qexample'),
        SpAddressKind.silentPaymentRegtest,
      );
    });

    test('bcrt1 is a standard bitcoin address, not a silent payment', () {
      expect(classifySpAddress('bcrt1qexample'), SpAddressKind.bitcoin);
    });

    test('bech32 and legacy bitcoin prefixes classify as bitcoin', () {
      expect(classifySpAddress('bc1qexample'), SpAddressKind.bitcoin);
      expect(classifySpAddress('tb1qexample'), SpAddressKind.bitcoin);
      expect(classifySpAddress('1abc'), SpAddressKind.bitcoin);
      expect(classifySpAddress('mabc'), SpAddressKind.bitcoin);
      expect(classifySpAddress('nabc'), SpAddressKind.bitcoin);
    });

    test('classification is case-insensitive and trims whitespace', () {
      expect(
        classifySpAddress('  SPRT1QEXAMPLE '),
        SpAddressKind.silentPaymentRegtest,
      );
    });

    test('anything else is unrecognized', () {
      expect(classifySpAddress('zzz'), SpAddressKind.unrecognized);
      expect(classifySpAddress(''), SpAddressKind.unrecognized);
    });
  });

  group('isSilentPayment', () {
    test('is true for every silent payment kind', () {
      expect(SpAddressKind.silentPaymentMainnet.isSilentPayment, isTrue);
      expect(SpAddressKind.silentPaymentTestnet.isSilentPayment, isTrue);
      expect(SpAddressKind.silentPaymentRegtest.isSilentPayment, isTrue);
    });

    test('is false for standard and unrecognized', () {
      expect(SpAddressKind.bitcoin.isSilentPayment, isFalse);
      expect(SpAddressKind.unrecognized.isSilentPayment, isFalse);
    });
  });
}
