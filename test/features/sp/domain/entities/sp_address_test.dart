import 'package:bb_mobile/features/sp/domain/entities/sp_address.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpAddress constructor', () {
    test('an sp1 address is a mainnet silent payment', () {
      expect(SpAddress('sp1qexample').kind, SpAddressKind.silentPaymentMainnet);
    });

    test('a tsp1 address is a testnet silent payment', () {
      expect(
        SpAddress('tsp1qexample').kind,
        SpAddressKind.silentPaymentTestnet,
      );
    });

    test('an sprt1 address is a regtest silent payment', () {
      expect(
        SpAddress('sprt1qexample').kind,
        SpAddressKind.silentPaymentRegtest,
      );
    });

    test('a bech32 prefix carries its network', () {
      expect(SpAddress('bc1qexample').kind, SpAddressKind.bitcoinMainnet);
      expect(SpAddress('tb1qexample').kind, SpAddressKind.bitcoinTestnet);
      expect(SpAddress('bcrt1qexample').kind, SpAddressKind.bitcoinRegtest);
    });

    test('a legacy prefix is mainnet or the shared non-mainnet kind', () {
      for (final input in ['1abc', '3abc']) {
        expect(SpAddress(input).kind, SpAddressKind.bitcoinMainnet);
      }
      for (final input in ['2abc', 'mabc', 'nabc']) {
        expect(SpAddress(input).kind, SpAddressKind.bitcoinLegacyNonMainnet);
      }
    });

    test('case and surrounding spaces are ignored', () {
      final address = SpAddress('  SPRT1QEXAMPLE ');
      expect(address.kind, SpAddressKind.silentPaymentRegtest);
      expect(address.value, 'SPRT1QEXAMPLE');
    });

    test('throws on an unrecognized address', () {
      expect(() => SpAddress('zzz'), throwsArgumentError);
    });
  });
}
