import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../recipient_fixtures.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late FakeRecipientsGateway gateway;
  late _MockSettingsRepository settings;
  late AddRecipientUsecase usecase;

  setUp(() {
    gateway = FakeRecipientsGateway();
    settings = _MockSettingsRepository();
    usecase = AddRecipientUsecase(
      gateway,
      recipientsGateway: gateway,
      settingsRepository: settings,
    );
    when(() => settings.fetch()).thenAnswer((_) async => settingsFixture());
  });

  test('confidential SEPA activates the virtual payee after saving', () async {
    gateway.savedResult = sepaRecipientFixture(recipientId: 'created-1');
    gateway.activatedResult = sepaRecipientFixture(
      recipientId: 'created-1',
      virtualPayeeStatus: 'ACTIVE',
    );

    final result = await usecase.execute(
      AddRecipientParams(
        recipientDetails: sepaDetailsDtoFixture(
          recipientType: RecipientType.confidentialSepaEur,
        ),
      ),
    );

    expect(gateway.activateCalls, hasLength(1));
    expect(gateway.activateCalls.single.recipientId, 'created-1');
    expect(result.recipient.recipientType, RecipientType.confidentialSepaEur);
    expect(
      result.recipient.details.virtualPayeeStatus,
      SepaVirtualPayeeStatus.active,
    );
    expect(result.activationFailure, isNull);
  });

  test('regular SEPA never activates a virtual payee', () async {
    gateway.savedResult = sepaRecipientFixture(recipientId: 'created-1');

    final result = await usecase.execute(
      AddRecipientParams(
        recipientDetails: sepaDetailsDtoFixture(
          recipientType: RecipientType.sepaEur,
        ),
      ),
    );

    expect(gateway.activateCalls, isEmpty);
    expect(result.recipient.recipientId, 'created-1');
  });

  test('a failed activation keeps the submitted confidential intent', () async {
    gateway.savedResult = sepaRecipientFixture(recipientId: 'created-1');
    gateway.activateError = Exception('activation backend unavailable');

    final result = await usecase.execute(
      AddRecipientParams(
        recipientDetails: sepaDetailsDtoFixture(
          recipientType: RecipientType.confidentialSepaEur,
        ),
      ),
    );

    expect(gateway.activateCalls, hasLength(1));
    expect(result.recipient.recipientId, 'created-1');
    expect(result.recipient.recipientType, RecipientType.confidentialSepaEur);
    expect(
      result.recipient.details.virtualPayeeStatus,
      SepaVirtualPayeeStatus.absent,
    );
    expect(result.activationFailure, isNotNull);
  });
}
