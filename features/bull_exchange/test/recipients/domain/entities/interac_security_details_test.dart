import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates trimmed security details', () {
    final result = InteracSecurityDetails.create(
      recipientId: 'recipient-1',
      email: 'person@example.com',
      securityQuestion: '  Favourite city?  ',
      securityAnswer: '  Montreal  ',
    );

    expect(result, isA<Ok<InteracSecurityDetails, ExchangeFailure>>());
    final details =
        (result as Ok<InteracSecurityDetails, ExchangeFailure>).value;
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

    expect(result, isA<Ok<InteracSecurityDetails, ExchangeFailure>>());
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

    expect(incomplete, isA<Err<InteracSecurityDetails, ExchangeFailure>>());
    expect(
      invalidCharacters,
      isA<Err<InteracSecurityDetails, ExchangeFailure>>(),
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
      isA<Err<InteracSecurityDetails, ExchangeFailure>>(),
    );
    expect(missingEmail, isA<Err<InteracSecurityDetails, ExchangeFailure>>());
  });
}
