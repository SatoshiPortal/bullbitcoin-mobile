import 'package:exchange/exchange.dart' show ConfidentialSepaAvailability;
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared rows keep backend order and deduplicate by recipient ID', () {
    const own = RecipientViewModel(
      id: 'own',
      type: RecipientType.sepaEur,
      isOwner: true,
    );
    const other = RecipientViewModel(
      id: 'other',
      type: RecipientType.sepaEur,
      isOwner: false,
    );
    const unknown = RecipientViewModel(
      id: 'unknown',
      type: RecipientType.interacEmailCad,
    );
    final state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(),
      recipients: const [own, other, unknown, own],
    );
    expect(state.selectableRecipients, [own, other, unknown]);
  });

  for (final type in RecipientType.standardTypes) {
    test('shared $type rows preserve unknown ownership from the backend', () {
      final recipient = RecipientViewModel(id: 'backend-row', type: type);
      final state = RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(
          types: [type],
          isOwner: true,
        ),
        recipients: [recipient],
      );
      expect(state.selectableRecipients, [recipient]);
    });
  }

  test('shared getter does not apply a second owner or type policy', () {
    const recipient = RecipientViewModel(
      id: 'backend-row',
      type: RecipientType.interacEmailCad,
      isOwner: false,
    );
    final state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(
        types: [RecipientType.sepaEur],
        isOwner: true,
      ),
      recipients: const [recipient],
    );
    expect(state.selectableRecipients, [recipient]);
  });

  test('missing rows remain missing, and empty rows remain empty', () {
    final state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(),
    );
    expect(state.selectableRecipients, isNull);
    expect(state.copyWith(recipients: []).selectableRecipients, isEmpty);
  });

  test('Confidential SEPA eligibility still controls the selectable types', () {
    final state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(
        types: [RecipientType.confidentialSepaEur],
        isOwner: true,
      ),
    );
    expect(state.selectableRecipientTypes, isEmpty);
    expect(
      state
          .copyWith(
            confidentialSepaAvailability:
                ConfidentialSepaAvailability.unavailable,
          )
          .selectableRecipientTypes,
      isEmpty,
    );
    expect(
      state
          .copyWith(
            confidentialSepaAvailability: ConfidentialSepaAvailability.ready,
          )
          .selectableRecipientTypes,
      {RecipientType.confidentialSepaEur},
    );
  });
}
