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

  group('the selection a flow receives', () {
    test('carries the Argentine CBU and its row', () {
      final selection = RecipientSelection.of(
        _recipient(
          BankAccountArgentinaDetails.create(
            claveUniform: '0170099220000067797171',
            name: 'Jorge Borges',
          ),
        ),
      );

      expect(selection.bankAccount, '0170099220000067797171');
      expect(selection.displayName, 'Jorge Borges');
      expect(selection.accountRows, [
        const AccountRow(AccountField.cbuCvu, '0170099220000067797171'),
      ]);
    });

    test('carries the Interac security details', () {
      final selection = RecipientSelection.of(
        _recipient(
          InteracEmailCadDetails.create(
            email: 'ada@example.com',
            name: 'Ada Lovelace',
            securityQuestion: 'Favourite city?',
            securityAnswer: 'Montreal',
          ),
        ),
      );

      expect(selection.securityQuestion, 'Favourite city?');
      expect(selection.securityAnswer, 'Montreal');
      expect(selection.email, 'ada@example.com');
    });

    test('carries the bill payment payee fields', () {
      final selection = RecipientSelection.of(
        _recipient(
          BillPaymentCadDetails.create(
            payeeName: 'Hydro',
            payeeCode: '1234',
            payeeAccountNumber: '55667788',
          ),
        ),
      );

      expect(selection.payeeName, 'Hydro');
      expect(selection.payeeCode, '1234');
      expect(selection.payeeAccountNumber, '55667788');
      expect(selection.displayName, 'Hydro');
    });

    test('carries the SPEI SMS phone', () {
      final selection = RecipientSelection.of(
        _recipient(
          SpeiSmsMxnDetails.create(
            institutionCode: '40',
            phone: '5512345678',
            name: 'Lu',
          ),
        ),
      );

      expect(selection.phoneNumber, '5512345678');
    });

    test('a confidential recipient carries its virtual payee status', () {
      final details = SepaEurDetails.create(
        isOwner: true,
        iban: 'FR7630006000011234567890189',
        isCorporate: false,
        firstname: 'Ada',
        lastname: 'Lovelace',
        virtualPayeeStatus: SepaVirtualPayeeStatus.active,
      ).asConfidential();

      final selection = RecipientSelection.of(_recipient(details));

      expect(selection.type, RecipientType.confidentialSepaEur);
      expect(selection.isVirtualPayeeActive, isTrue);
      expect(selection.requiresVirtualPayeeActivation, isFalse);
    });
  });
}
