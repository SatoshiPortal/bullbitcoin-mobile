import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/get_sell_confidential_sepa_availability_usecase_v2.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockRecipients extends Mock implements RecipientsFacade {}

void main() {
  test('publishes every successful eligibility state', () async {
    final recipients = _MockRecipients();
    final usecase = GetSellConfidentialSepaAvailabilityUsecaseV2(recipients);
    for (final availability in ConfidentialSepaAvailability.values) {
      when(
        recipients.getConfidentialSepaAvailability,
      ).thenAnswer((_) async => Ok(availability));
      final result = await usecase.execute();
      expect(
        (result as Ok<ConfidentialSepaAvailability, SellFailure>).value,
        availability,
      );
    }
  });

  test('maps foreign failures to Sell failures', () async {
    final recipients = _MockRecipients();
    final usecase = GetSellConfidentialSepaAvailabilityUsecaseV2(recipients);
    for (final failure in [
      const RecipientsNetworkFailure(),
      const RecipientsUnexpectedFailure(),
    ]) {
      when(
        recipients.getConfidentialSepaAvailability,
      ).thenAnswer((_) async => Err(failure));
      final result = await usecase.execute();
      expect(
        (result as Err<ConfidentialSepaAvailability, SellFailure>).failure,
        failure is RecipientsNetworkFailure
            ? isA<SellNetworkFailure>()
            : isA<SellUnexpectedFailure>(),
      );
    }
  });
}
