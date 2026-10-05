import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/presentation/recipient_view_model_mapper.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
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
  test('maps a SEPA recipient to the published model', () {
    final recipient = _recipient(
      SepaEurDetails.create(
        label: 'Primary account',
        isOwner: true,
        iban: 'FR7630006000011234567890189',
        isCorporate: false,
        firstname: 'Ada',
        lastname: 'Lovelace',
      ),
    );

    expect(
      recipient.toViewModel(),
      const RecipientViewModel(
        id: 'recipient-1',
        type: RecipientType.sepaEur,
        isOwner: true,
        label: 'Primary account',
        iban: 'FR7630006000011234567890189',
        isCorporate: false,
        firstname: 'Ada',
        lastname: 'Lovelace',
      ),
    );
  });

  test('keeps a SINPE recipient without an owner name', () {
    final recipient = _recipient(
      SinpeMovilCrcDetails.create(label: 'Mobile', phoneNumber: '88887777'),
    );

    final viewModel = recipient.toViewModel();

    expect(viewModel.ownerName, isNull);
    expect(viewModel.phoneNumber, '88887777');
    expect(viewModel.displayName, 'Mobile');
  });

  test('exposes the Argentine CBU through bankAccount', () {
    final recipient = _recipient(
      BankAccountArgentinaDetails.create(
        claveUniform: '0170099220000067797171',
        name: 'Jorge Borges',
      ),
    );

    final viewModel = recipient.toViewModel();

    expect(viewModel.bankAccount, '0170099220000067797171');
    expect(viewModel.displayName, 'Jorge Borges');
  });

  test('carries Interac security details through to the view model', () {
    final recipient = _recipient(
      InteracEmailCadDetails.create(
        email: 'ada@example.com',
        name: 'Ada Lovelace',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      ),
    );

    final viewModel = recipient.toViewModel();

    expect(viewModel.securityQuestion, 'Favourite city?');
    expect(viewModel.securityAnswer, 'Montreal');
    expect(viewModel.email, 'ada@example.com');
  });

  test('maps a bill payment recipient to its payee fields', () {
    final recipient = _recipient(
      BillPaymentCadDetails.create(
        payeeName: 'Hydro',
        payeeCode: '1234',
        payeeAccountNumber: '55667788',
      ),
    );

    final viewModel = recipient.toViewModel();

    expect(viewModel.payeeName, 'Hydro');
    expect(viewModel.payeeCode, '1234');
    expect(viewModel.payeeAccountNumber, '55667788');
    expect(viewModel.displayName, 'Hydro');
  });
}
