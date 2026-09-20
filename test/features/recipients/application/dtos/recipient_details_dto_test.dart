import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Interac security credentials', () {
    test('preserves credentials supplied by the user', () {
      const dto = RecipientDetailsDto(
        recipientType: RecipientType.interacEmailCad,
        email: 'recipient@example.com',
        name: 'Recipient',
        securityQuestion: 'What is the invoice number?',
        securityAnswer: 'Invoice-123',
      );

      final details = dto.toDomain() as InteracEmailCadDetails;

      expect(details.securityQuestion, 'What is the invoice number?');
      expect(details.securityAnswer, 'Invoice-123');
    });

    test('represents missing credentials as absent', () {
      const dto = RecipientDetailsDto(
        recipientType: RecipientType.interacEmailCad,
        email: 'recipient@example.com',
        name: 'Recipient',
      );

      final details = dto.toDomain() as InteracEmailCadDetails;

      expect(details.securityQuestion, isNull);
      expect(details.securityAnswer, isNull);
    });

    test('normalizes an incomplete credential pair to absent', () {
      for (final dto in [
        const RecipientDetailsDto(
          recipientType: RecipientType.interacEmailCad,
          email: 'recipient@example.com',
          name: 'Recipient',
          securityQuestion: 'Favourite city?',
        ),
        const RecipientDetailsDto(
          recipientType: RecipientType.interacEmailCad,
          email: 'recipient@example.com',
          name: 'Recipient',
          securityAnswer: 'Montreal',
        ),
      ]) {
        final details = dto.toDomain() as InteracEmailCadDetails;

        expect(details.securityQuestion, isNull);
        expect(details.securityAnswer, isNull);
      }
    });
  });

  group('nullable SINPE owner name', () {
    test('mobile recipient remains valid without an owner name', () {
      const dto = RecipientDetailsDto(
        recipientType: RecipientType.sinpeMovilCrc,
        phoneNumber: '8888-8888',
      );

      final details = dto.toDomain() as SinpeMovilCrcDetails;

      expect(details.phoneNumber, '8888-8888');
      expect(details.ownerName, isNull);
    });

    test('IBAN recipients remain valid without an owner name', () {
      for (final type in [
        RecipientType.sinpeIbanCrc,
        RecipientType.sinpeIbanUsd,
      ]) {
        final dto = RecipientDetailsDto(
          recipientType: type,
          iban: 'CR05015202001026284066',
        );
        final details = dto.toDomain();
        final ownerName = switch (details) {
          SinpeIbanCrcDetails(:final ownerName) => ownerName,
          SinpeIbanUsdDetails(:final ownerName) => ownerName,
          _ => throw StateError('Unexpected details type'),
        };

        expect(ownerName, isNull);
      }
    });

    test('display name falls back to label then identifier', () {
      const labeled = RecipientViewModel(
        id: 'recipient-1',
        type: RecipientType.sinpeMovilCrc,
        label: 'Family',
        phoneNumber: '8888-8888',
      );
      const unlabeled = RecipientViewModel(
        id: 'recipient-2',
        type: RecipientType.sinpeMovilCrc,
        phoneNumber: '8888-8888',
      );

      expect(labeled.displayName, 'Family');
      expect(unlabeled.displayName, '8888-8888');
    });
  });
}
