import 'package:exchange/exchange.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Interac security credentials', () {
    test('preserves credentials supplied by the user', () {
      const input = RecipientDetailsInput(
        recipientType: RecipientType.interacEmailCad,
        email: 'recipient@example.com',
        name: 'Recipient',
        securityQuestion: 'What is the invoice number?',
        securityAnswer: 'Invoice-123',
      );

      final details = input.toDomain() as InteracEmailCadDetails;

      expect(details.securityQuestion, 'What is the invoice number?');
      expect(details.securityAnswer, 'Invoice-123');
    });

    test('represents missing credentials as absent', () {
      const input = RecipientDetailsInput(
        recipientType: RecipientType.interacEmailCad,
        email: 'recipient@example.com',
        name: 'Recipient',
      );

      final details = input.toDomain() as InteracEmailCadDetails;

      expect(details.securityQuestion, isNull);
      expect(details.securityAnswer, isNull);
    });

    test('normalizes an incomplete credential pair to absent', () {
      for (final input in [
        const RecipientDetailsInput(
          recipientType: RecipientType.interacEmailCad,
          email: 'recipient@example.com',
          name: 'Recipient',
          securityQuestion: 'Favourite city?',
        ),
        const RecipientDetailsInput(
          recipientType: RecipientType.interacEmailCad,
          email: 'recipient@example.com',
          name: 'Recipient',
          securityAnswer: 'Montreal',
        ),
      ]) {
        final details = input.toDomain() as InteracEmailCadDetails;

        expect(details.securityQuestion, isNull);
        expect(details.securityAnswer, isNull);
      }
    });
  });

  group('nullable SINPE owner name', () {
    test('mobile recipient remains valid without an owner name', () {
      const input = RecipientDetailsInput(
        recipientType: RecipientType.sinpeMovilCrc,
        phoneNumber: '8888-8888',
      );

      final details = input.toDomain() as SinpeMovilCrcDetails;

      expect(details.phoneNumber, '8888-8888');
      expect(details.ownerName, isNull);
    });

    test('IBAN recipients remain valid without an owner name', () {
      for (final type in [
        RecipientType.sinpeIbanCrc,
        RecipientType.sinpeIbanUsd,
      ]) {
        final input = RecipientDetailsInput(
          recipientType: type,
          iban: 'CR05015202001026284066',
        );
        final details = input.toDomain();
        final ownerName = switch (details) {
          SinpeIbanCrcDetails(:final ownerName) => ownerName,
          SinpeIbanUsdDetails(:final ownerName) => ownerName,
          _ => throw StateError('Unexpected details type'),
        };

        expect(ownerName, isNull);
      }
    });

    test('display name falls back to label then identifier', () {
      final labeled = SinpeMovilCrcDetails.create(
        label: 'Family',
        phoneNumber: '8888-8888',
      );
      final unlabeled = SinpeMovilCrcDetails.create(phoneNumber: '8888-8888');

      expect(labeled.onRail.displayName, 'Family');
      expect(unlabeled.onRail.displayName, '8888-8888');
    });
  });
}
