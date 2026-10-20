import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter_test/flutter_test.dart';

const _confidential = RecipientSelection(
  id: 'r-1',
  type: RecipientType.confidentialSepaEur,
  iban: 'FR7630006000011234567890189',
);

void main() {
  test('a confidential recipient without an active payee needs activation', () {
    expect(_confidential.requiresVirtualPayeeActivation, isTrue);
    expect(
      _confidential.asVirtualPayeeActive().requiresVirtualPayeeActivation,
      isFalse,
    );
  });

  test('a regular recipient never needs activation', () {
    const regular = RecipientSelection(id: 'r-1', type: RecipientType.sepaEur);

    expect(regular.requiresVirtualPayeeActivation, isFalse);
  });

  test('the regular route keeps the account', () {
    final regular = _confidential.asRegularSepa();

    expect(regular.type, RecipientType.sepaEur);
    expect(regular.id, 'r-1');
    expect(regular.iban, _confidential.iban);
  });
}
