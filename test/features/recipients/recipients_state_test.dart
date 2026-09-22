import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipient_fixtures.dart';

void main() {
  test('selectable recipients deduplicate by ID and processor choice', () {
    final regular = sepaViewModelFixture(type: RecipientType.sepaEur);
    final confidential = sepaViewModelFixture(
      type: RecipientType.confidentialSepaEur,
    );
    final state = RecipientsState(
      allowedRecipientFilters: const RecipientFilterCriteria(),
      recipients: [regular, confidential, regular],
    );

    expect(state.selectableRecipients, [regular, confidential]);
  });

  test('confidential SEPA creation is hidden until eligibility is known', () {
    const state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(),
    );

    expect(
      state.recipientTypesForJurisdiction('EU'),
      contains(RecipientType.sepaEur),
    );
    expect(
      state.recipientTypesForJurisdiction('EU'),
      isNot(contains(RecipientType.confidentialSepaEur)),
    );
  });

  test('confidential SEPA creation is shown to eligible users', () {
    const state = RecipientsState(
      allowedRecipientFilters: RecipientFilterCriteria(),
      canUseConfidentialSepa: true,
    );

    expect(
      state.recipientTypesForJurisdiction('EU'),
      contains(RecipientType.confidentialSepaEur),
    );
  });
}
