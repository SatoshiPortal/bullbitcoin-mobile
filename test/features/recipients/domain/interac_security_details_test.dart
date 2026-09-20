import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates trimmed security details', () {
    final result = InteracSecurityDetails.create(
      recipientId: 'recipient-1',
      email: 'person@example.com',
      securityQuestion: '  Favourite city?  ',
      securityAnswer: '  Montreal  ',
    );

    expect(result, isA<Ok<InteracSecurityDetails, RecipientsFailure>>());
    final details =
        (result as Ok<InteracSecurityDetails, RecipientsFailure>).value;
    expect(details.securityQuestion, 'Favourite city?');
    expect(details.securityAnswer, 'Montreal');
    expect(details.toString(), isNot(contains('Montreal')));
  });

  test('creates a request that clears saved security details', () {
    final result = InteracSecurityDetails.create(
      recipientId: 'recipient-1',
      email: 'person@example.com',
      securityQuestion: null,
      securityAnswer: null,
    );

    expect(result, isA<Ok<InteracSecurityDetails, RecipientsFailure>>());
  });

  test('rejects incomplete or invalid security details', () {
    final incomplete = InteracSecurityDetails.create(
      recipientId: 'recipient-1',
      email: 'person@example.com',
      securityQuestion: 'Favourite city?',
      securityAnswer: null,
    );
    final invalidCharacters = InteracSecurityDetails.create(
      recipientId: 'recipient-1',
      email: 'person@example.com',
      securityQuestion: 'Favourite city?',
      securityAnswer: 'Montréal!',
    );

    expect(incomplete, isA<Err<InteracSecurityDetails, RecipientsFailure>>());
    expect(
      invalidCharacters,
      isA<Err<InteracSecurityDetails, RecipientsFailure>>(),
    );
  });

  test('rejects an empty recipient id or email', () {
    final missingRecipientId = InteracSecurityDetails.create(
      recipientId: ' ',
      email: 'person@example.com',
      securityQuestion: 'Favourite city?',
      securityAnswer: 'Montreal',
    );
    final missingEmail = InteracSecurityDetails.create(
      recipientId: 'recipient-1',
      email: ' ',
      securityQuestion: 'Favourite city?',
      securityAnswer: 'Montreal',
    );

    expect(
      missingRecipientId,
      isA<Err<InteracSecurityDetails, RecipientsFailure>>(),
    );
    expect(missingEmail, isA<Err<InteracSecurityDetails, RecipientsFailure>>());
  });
}
