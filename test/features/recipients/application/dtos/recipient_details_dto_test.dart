import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
