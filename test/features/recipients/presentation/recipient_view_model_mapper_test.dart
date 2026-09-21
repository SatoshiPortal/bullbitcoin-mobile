import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/presentation/recipient_view_model_mapper.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps an internal recipient DTO to the published recipient model', () {
    final dto = RecipientDto(
      recipientId: 'recipient-1',
      userId: 'user-1',
      userNbr: 1,
      isArchived: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      details: const RecipientDetailsDto(
        recipientType: RecipientType.sepaEur,
        isOwner: true,
        label: 'Primary account',
        iban: 'FR7630006000011234567890189',
        firstname: 'Ada',
        lastname: 'Lovelace',
      ),
    );

    expect(
      dto.toViewModel(),
      const RecipientViewModel(
        id: 'recipient-1',
        type: RecipientType.sepaEur,
        isOwner: true,
        label: 'Primary account',
        iban: 'FR7630006000011234567890189',
        firstname: 'Ada',
        lastname: 'Lovelace',
      ),
    );
  });
}
