import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipient_update_repository.dart';
import 'package:bb_mobile/features/recipients/domain/update_interac_security_details_usecase.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientUpdateRepository extends Mock
    implements RecipientUpdateRepository {}

class _MockSettingsFacade extends Mock implements SettingsFacade {}

void main() {
  late _MockRecipientUpdateRepository repository;
  late _MockSettingsFacade settingsFacade;
  late UpdateInteracSecurityDetailsUsecase usecase;
  late InteracSecurityDetails details;

  setUp(() {
    repository = _MockRecipientUpdateRepository();
    settingsFacade = _MockSettingsFacade();
    usecase = UpdateInteracSecurityDetailsUsecase(repository, settingsFacade);
    details =
        (InteracSecurityDetails.create(
                  recipientId: 'recipient-1',
                  email: 'person@example.com',
                  securityQuestion: 'Favourite city?',
                  securityAnswer: 'Montreal',
                )
                as Ok<InteracSecurityDetails, RecipientsFailure>)
            .value;
  });

  test('forwards the update result from the repository', () async {
    when(
      () => settingsFacade.getTestnetMode(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => repository.updateInteracSecurityDetails(details, isTestnet: false),
    ).thenAnswer((_) async => const Ok<void, RecipientsFailure>(null));

    final result = await usecase.execute(details);

    expect(result, isA<Ok<void, RecipientsFailure>>());
    verify(
      () => repository.updateInteracSecurityDetails(details, isTestnet: false),
    ).called(1);
  });
}
