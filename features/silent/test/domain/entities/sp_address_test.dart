import 'package:silent/src/domain/entities/sp_address.dart';
import 'package:silent/src/domain/entities/sp_address_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SilentAddress constructor', () {
    test('an sp1 address is a mainnet silent payment', () {
      expect(
        SilentAddress('sp1qexample').kind,
        SilentAddressKind.silentPaymentMainnet,
      );
    });

    test('a tsp1 address is a testnet silent payment', () {
      expect(
        SilentAddress('tsp1qexample').kind,
        SilentAddressKind.silentPaymentTestnet,
      );
    });

    test('an sprt1 address is a regtest silent payment', () {
      expect(
        SilentAddress('sprt1qexample').kind,
        SilentAddressKind.silentPaymentRegtest,
      );
    });

    test('a bech32 prefix carries its network', () {
      expect(
        SilentAddress('bc1qexample').kind,
        SilentAddressKind.bitcoinMainnet,
      );
      expect(
        SilentAddress('tb1qexample').kind,
        SilentAddressKind.bitcoinTestnet,
      );
      expect(
        SilentAddress('bcrt1qexample').kind,
        SilentAddressKind.bitcoinRegtest,
      );
    });

    test('a legacy prefix is mainnet or the shared non-mainnet kind', () {
      for (final input in ['1abc', '3abc']) {
        expect(SilentAddress(input).kind, SilentAddressKind.bitcoinMainnet);
      }
      for (final input in ['2abc', 'mabc', 'nabc']) {
        expect(
          SilentAddress(input).kind,
          SilentAddressKind.bitcoinLegacyNonMainnet,
        );
      }
    });

    test('case and surrounding spaces are ignored', () {
      final address = SilentAddress('  SPRT1QEXAMPLE ');
      expect(address.kind, SilentAddressKind.silentPaymentRegtest);
      expect(address.value, 'SPRT1QEXAMPLE');
    });

    test('throws on an unrecognized address', () {
      expect(() => SilentAddress('zzz'), throwsArgumentError);
    });
  });
}
