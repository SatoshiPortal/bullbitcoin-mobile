import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the api value of a SEPA recipient reads as regular SEPA', () {
    expect(RecipientType.fromValue('SEPA_EUR'), RecipientType.sepaEur);
  });

  test('Confidential SEPA is sent to the api as SEPA_EUR', () {
    expect(RecipientType.confidentialSepaEur.value, 'SEPA_EUR');
  });

  test('standard types leave out Confidential SEPA', () {
    expect(
      RecipientType.standardTypes,
      isNot(contains(RecipientType.confidentialSepaEur)),
    );
    expect(
      RecipientType.standardTypes,
      hasLength(RecipientType.values.length - 1),
    );
  });

  test('the euro types leave out Confidential SEPA', () {
    expect(RecipientType.typesForCurrency('EUR'), {RecipientType.sepaEur});
  });
}
