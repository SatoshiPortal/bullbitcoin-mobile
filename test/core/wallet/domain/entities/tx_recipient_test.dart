import 'package:bb_mobile/core/wallet/domain/entities/tx_recipient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const address = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
  const otherAddress =
      'tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7';

  group('FixedTxRecipient', () {
    test('exposes the pinned amount', () {
      final recipient = FixedTxRecipient(
        address: address,
        amountSat: BigInt.from(10000),
      );

      expect(recipient.address, address);
      expect(recipient.amountSat, BigInt.from(10000));
    });

    test('rejects an empty or blank address', () {
      expect(
        () => FixedTxRecipient(address: '', amountSat: BigInt.one),
        throwsArgumentError,
      );
      expect(
        () => FixedTxRecipient(address: '   ', amountSat: BigInt.one),
        throwsArgumentError,
      );
    });

    test('rejects a zero or negative amount', () {
      expect(
        () => FixedTxRecipient(address: address, amountSat: BigInt.zero),
        throwsArgumentError,
      );
      expect(
        () => FixedTxRecipient(address: address, amountSat: -BigInt.one),
        throwsArgumentError,
      );
    });

    test('is equal by value', () {
      final a = FixedTxRecipient(address: address, amountSat: BigInt.from(5));
      final b = FixedTxRecipient(address: address, amountSat: BigInt.from(5));
      final differentAmount = FixedTxRecipient(
        address: address,
        amountSat: BigInt.from(6),
      );
      final differentAddress = FixedTxRecipient(
        address: otherAddress,
        amountSat: BigInt.from(5),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentAmount));
      expect(a, isNot(differentAddress));
    });
  });

  group('DrainTxRecipient', () {
    test('has no pinned amount', () {
      expect(DrainTxRecipient(address: address).amountSat, isNull);
    });

    test('rejects an empty or blank address', () {
      expect(() => DrainTxRecipient(address: ''), throwsArgumentError);
      expect(() => DrainTxRecipient(address: '  '), throwsArgumentError);
    });

    test('is equal by value', () {
      expect(
        DrainTxRecipient(address: address),
        DrainTxRecipient(address: address),
      );
      expect(
        DrainTxRecipient(address: address),
        isNot(DrainTxRecipient(address: otherAddress)),
      );
    });

    test('never equals a fixed recipient for the same address', () {
      expect(
        DrainTxRecipient(address: address),
        isNot(FixedTxRecipient(address: address, amountSat: BigInt.one)),
      );
    });
  });
}
