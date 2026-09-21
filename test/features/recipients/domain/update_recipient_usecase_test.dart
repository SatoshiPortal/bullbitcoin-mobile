import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipient_update_repository.dart';
import 'package:bb_mobile/features/recipients/domain/update_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientUpdateRepository extends Mock
    implements RecipientUpdateRepository {}

class _MockSettingsFacade extends Mock implements SettingsFacade {}

class _FakeRecipientDetails extends Fake implements RecipientDetails {}

void main() {
  late _MockRecipientUpdateRepository recipientRepository;
  late _MockSettingsFacade settingsFacade;
  late UpdateRecipientUsecase usecase;

  setUpAll(() {
    registerFallbackValue(_FakeRecipientDetails());
  });

  setUp(() {
    recipientRepository = _MockRecipientUpdateRepository();
    settingsFacade = _MockSettingsFacade();
    usecase = UpdateRecipientUsecase(recipientRepository, settingsFacade);
    when(
      () => settingsFacade.getTestnetMode(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => recipientRepository.update(
        any(),
        any(),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('updates an Interac recipient with valid security details', () async {
    await usecase.execute(
      UpdateRecipientParams(
        recipientId: 'recipient-1',
        recipientDetails: RecipientDetailsDto(
          recipientType: RecipientType.interacEmailCad,
          email: 'person@example.com',
          name: 'Person',
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal',
        ).toDomain(),
      ),
    );

    final captured =
        verify(
              () => recipientRepository.update(
                'recipient-1',
                captureAny(),
                isTestnet: false,
              ),
            ).captured.single
            as InteracEmailCadDetails;

    expect(captured.securityQuestion, 'Favourite city?');
    expect(captured.securityAnswer, 'Montreal');
  });

  test('allows clearing Interac security details', () async {
    await usecase.execute(
      UpdateRecipientParams(
        recipientId: 'recipient-1',
        recipientDetails: RecipientDetailsDto(
          recipientType: RecipientType.interacEmailCad,
          email: 'person@example.com',
          name: 'Person',
        ).toDomain(),
      ),
    );

    final captured =
        verify(
              () => recipientRepository.update(
                'recipient-1',
                captureAny(),
                isTestnet: false,
              ),
            ).captured.single
            as InteracEmailCadDetails;

    expect(captured.securityQuestion, isNull);
    expect(captured.securityAnswer, isNull);
  });

  test('routes updates to testnet', () async {
    when(
      () => settingsFacade.getTestnetMode(),
    ).thenAnswer((_) async => const Ok(true));

    await usecase.execute(
      UpdateRecipientParams(
        recipientId: 'recipient-1',
        recipientDetails: RecipientDetailsDto(
          recipientType: RecipientType.interacEmailCad,
          email: 'person@example.com',
          name: 'Person',
        ).toDomain(),
      ),
    );

    verify(
      () => recipientRepository.update('recipient-1', any(), isTestnet: true),
    ).called(1);
  });

  test('supports corporate Colombia details without a personal name', () {
    const dto = RecipientDetailsDto(
      recipientType: RecipientType.pseColombia,
      isCorporate: true,
      corporateName: 'Company SAS',
      accountType: 'S',
      bankAccount: '1234567890',
      bankCode: '007',
      bankName: 'Bancolombia',
      documentId: '900123456',
      documentType: 'NIT',
    );

    final details = dto.toDomain() as PseColombiaDetails;

    expect(details.name, isNull);
    expect(details.corporateName, 'Company SAS');
  });
}
