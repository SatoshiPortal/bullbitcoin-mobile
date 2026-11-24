import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

Recipient _recipient(RecipientDetails details) => Recipient.create(
  recipientId: 'recipient-1',
  userId: 'user-1',
  userNbr: 1,
  isArchived: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  details: details,
);

void main() {
  test('a recipient shows what its rail shows', () {
    final viewModel = RecipientViewModel(
      _recipient(
        SepaEurDetails.create(
          label: 'Primary account',
          isOwner: true,
          iban: 'FR7630006000011234567890189',
          isCorporate: false,
          firstname: 'Ada',
          lastname: 'Lovelace',
        ),
      ),
    );

    expect(viewModel.id, 'recipient-1');
    expect(viewModel.rail, PayoutRails.sepa);
    expect(viewModel.type, RecipientType.sepaEur);
    expect(viewModel.isOwner, isTrue);
    expect(viewModel.label, 'Primary account');
    expect(viewModel.displayName, 'Ada Lovelace');
    expect(viewModel.accountRows, [
      const AccountRow(AccountField.iban, 'FR7630006000011234567890189'),
    ]);
  });

  test('a SINPE recipient without an owner name shows its label', () {
    final viewModel = RecipientViewModel(
      _recipient(
        SinpeMovilCrcDetails.create(label: 'Mobile', phoneNumber: '88887777'),
      ),
    );

    expect(viewModel.displayName, 'Mobile');
    expect(viewModel.accountRows.single.value, '+506-8888-7777');
  });
}
