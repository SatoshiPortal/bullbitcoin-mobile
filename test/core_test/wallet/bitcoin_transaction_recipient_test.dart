import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Sats;

void main() {
  test('fixed recipient requires a destination and positive amount', () {
    expect(
      () => BitcoinTransactionRecipient.fixed(
        address: '',
        amountSat: Sats.fromInt(1),
      ),
      throwsArgumentError,
    );
    expect(
      () => BitcoinTransactionRecipient.fixed(
        address: 'bc1qrecipient',
        amountSat: Sats.zero,
      ),
      throwsArgumentError,
    );
  });

  test('remainder recipient has no fixed amount', () {
    expect(
      () => BitcoinTransactionRecipient.remainder(address: ''),
      throwsArgumentError,
    );

    final recipient = BitcoinTransactionRecipient.remainder(
      address: 'bc1qrecipient',
    );

    expect(recipient.amountSat, isNull);
    expect(recipient.receivesRemainder, isTrue);
  });

  test('recipient list requires at least one output', () {
    expect(
      () => validateBitcoinTransactionRecipients(const []),
      throwsArgumentError,
    );
  });

  test('recipient list permits only one remainder output', () {
    expect(
      () => validateBitcoinTransactionRecipients([
        BitcoinTransactionRecipient.remainder(address: 'bc1qfirst'),
        BitcoinTransactionRecipient.remainder(address: 'bc1qsecond'),
      ]),
      throwsArgumentError,
    );
  });
}
