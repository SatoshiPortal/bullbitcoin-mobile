import 'package:bull_exchange/src/recipients/domain/recipients_state.dart';
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
    expect(
      state.copyWith(recipients: <RecipientViewModel>[]).selectableRecipients,
      isEmpty,
    );
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

  group('the shown list follows the selected type and jurisdiction', () {
    final interac = recipientFixture('interac', RecipientType.interacEmailCad);
    final sepa = recipientFixture('sepa', RecipientType.sepaEur);
    final confidential = recipientFixture(
      'confidential',
      RecipientType.confidentialSepaEur,
    );
    // The pay flow's picker: every rail, Confidential SEPA usable.
    RecipientsState pay({
      Jurisdiction? jurisdiction,
      RecipientType sepaType = RecipientType.sepaEur,
    }) => RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(
        types: [for (final rail in PayoutRails.all) rail.type],
      ),
      confidentialSepaAvailability: ConfidentialSepaAvailability.ready,
      jurisdictionFilter: jurisdiction,
      sepaType: sepaType,
      recipients: [interac, sepa, confidential],
    );

    test('all jurisdictions: every rail, regular SEPA, no route tab', () {
      final state = pay();
      expect(state.canChooseSepaType, isFalse);
      expect(state.shownRecipients(strict: true), [interac, sepa]);
      expect(state.listedTypes, contains(RecipientType.interacEmailCad));
      expect(
        state.listedTypes,
        isNot(contains(RecipientType.confidentialSepaEur)),
      );
    });

    test('Europe, SEPA tab: only regular SEPA rows', () {
      final state = pay(jurisdiction: Jurisdiction.europe);
      expect(state.canChooseSepaType, isTrue);
      expect(state.shownRecipients(strict: true), [sepa]);
      expect(state.listedTypes, {RecipientType.sepaEur});
    });

    test('Europe, Confidential SEPA tab: only confidential rows', () {
      final state = pay(
        jurisdiction: Jurisdiction.europe,
        sepaType: RecipientType.confidentialSepaEur,
      );
      expect(state.shownRecipients(strict: true), [confidential]);
      expect(state.listedTypes, {RecipientType.confidentialSepaEur});
    });

    test('Canada: only Canadian rails', () {
      final state = pay(jurisdiction: Jurisdiction.canada);
      expect(state.canChooseSepaType, isFalse);
      expect(state.shownRecipients(strict: true), [interac]);
    });

    test('before the first page there is no list', () {
      expect(
        pay().copyWith(recipients: null).shownRecipients(strict: true),
        isNull,
      );
    });
  });
}
