import 'package:bb_mobile/features/sp/domain/entities/sp_address_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSilentPayment', () {
    test('is true for every silent payment kind', () {
      expect(SpAddressKind.silentPaymentMainnet.isSilentPayment, isTrue);
      expect(SpAddressKind.silentPaymentTestnet.isSilentPayment, isTrue);
      expect(SpAddressKind.silentPaymentRegtest.isSilentPayment, isTrue);
    });

    test('is false for standard and unrecognized', () {
      expect(SpAddressKind.bitcoinMainnet.isSilentPayment, isFalse);
      expect(SpAddressKind.bitcoinTestnet.isSilentPayment, isFalse);
      expect(SpAddressKind.bitcoinRegtest.isSilentPayment, isFalse);
      expect(SpAddressKind.bitcoinLegacyNonMainnet.isSilentPayment, isFalse);
      expect(SpAddressKind.unrecognized.isSilentPayment, isFalse);
    });
  });

  group('isBitcoin', () {
    test('is true for every standard kind', () {
      expect(SpAddressKind.bitcoinMainnet.isBitcoin, isTrue);
      expect(SpAddressKind.bitcoinTestnet.isBitcoin, isTrue);
      expect(SpAddressKind.bitcoinRegtest.isBitcoin, isTrue);
      expect(SpAddressKind.bitcoinLegacyNonMainnet.isBitcoin, isTrue);
    });

    test('is false for silent payment and unrecognized', () {
      expect(SpAddressKind.silentPaymentMainnet.isBitcoin, isFalse);
      expect(SpAddressKind.silentPaymentTestnet.isBitcoin, isFalse);
      expect(SpAddressKind.silentPaymentRegtest.isBitcoin, isFalse);
      expect(SpAddressKind.unrecognized.isBitcoin, isFalse);
    });
  });
}
