import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recipient_fixture.dart';

void main() {
  test('shared rows keep backend order and deduplicate by recipient ID', () {
    final own = recipientFixture('own', RecipientType.sepaEur, isOwner: true);
    final other = recipientFixture(
      'other',
      RecipientType.sepaEur,
      isOwner: false,
    );
    final unknown = recipientFixture('unknown', RecipientType.interacEmailCad);
    final state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(),
      recipients: [own, other, unknown, own],
    );
    expect(state.selectableRecipients, [own, other, unknown]);
  });

  for (final type in RecipientType.standardTypes) {
    test('shared $type rows preserve unknown ownership from the backend', () {
      final recipient = recipientFixture('backend-row', type);
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
    final recipient = recipientFixture(
      'backend-row',
      RecipientType.interacEmailCad,
      isOwner: false,
    );
    final state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(
        types: [RecipientType.sepaEur],
        isOwner: true,
      ),
      recipients: [recipient],
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
