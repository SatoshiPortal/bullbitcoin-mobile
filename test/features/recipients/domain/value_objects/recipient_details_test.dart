import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InteracEmailCadDetails', () {
    test('accepts no security question and answer for recipient creation', () {
      final details = InteracEmailCadDetails.create(
        email: 'person@example.com',
        name: 'Person',
      );

      expect(details.securityQuestion, isNull);
      expect(details.securityAnswer, isNull);
    });

    test('preserves one-sided security details returned by the API', () {
      final details = InteracEmailCadDetails.create(
        email: 'person@example.com',
        name: 'Person',
        securityQuestion: 'Favourite city?',
      );

      expect(details.securityQuestion, 'Favourite city?');
      expect(details.securityAnswer, isNull);
    });

    test('preserves legacy security details outside current edit limits', () {
      final details = InteracEmailCadDetails.create(
        email: 'person@example.com',
        name: 'Person',
        securityQuestion: 'q' * 41,
        securityAnswer: 'not valid!',
      );

      expect(details.securityQuestion, 'q' * 41);
      expect(details.securityAnswer, 'not valid!');
    });
  });
}
