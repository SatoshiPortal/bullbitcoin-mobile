import 'package:silent/src/domain/entities/sp_address_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSilentPayment', () {
    test('is true for every silent payment kind', () {
      expect(SilentAddressKind.silentPaymentMainnet.isSilentPayment, isTrue);
      expect(SilentAddressKind.silentPaymentTestnet.isSilentPayment, isTrue);
      expect(SilentAddressKind.silentPaymentRegtest.isSilentPayment, isTrue);
    });

    test('is false for standard and unrecognized', () {
      expect(SilentAddressKind.bitcoinMainnet.isSilentPayment, isFalse);
      expect(SilentAddressKind.bitcoinTestnet.isSilentPayment, isFalse);
      expect(SilentAddressKind.bitcoinRegtest.isSilentPayment, isFalse);
      expect(
        SilentAddressKind.bitcoinLegacyNonMainnet.isSilentPayment,
        isFalse,
      );
      expect(SilentAddressKind.unrecognized.isSilentPayment, isFalse);
    });
  });

  group('isBitcoin', () {
    test('is true for every standard kind', () {
      expect(SilentAddressKind.bitcoinMainnet.isBitcoin, isTrue);
      expect(SilentAddressKind.bitcoinTestnet.isBitcoin, isTrue);
      expect(SilentAddressKind.bitcoinRegtest.isBitcoin, isTrue);
      expect(SilentAddressKind.bitcoinLegacyNonMainnet.isBitcoin, isTrue);
    });

    test('is false for silent payment and unrecognized', () {
      expect(SilentAddressKind.silentPaymentMainnet.isBitcoin, isFalse);
      expect(SilentAddressKind.silentPaymentTestnet.isBitcoin, isFalse);
      expect(SilentAddressKind.silentPaymentRegtest.isBitcoin, isFalse);
      expect(SilentAddressKind.unrecognized.isBitcoin, isFalse);
    });
  });
}
