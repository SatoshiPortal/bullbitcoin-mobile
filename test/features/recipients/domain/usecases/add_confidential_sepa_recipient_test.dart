import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details_input.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements RecipientsRepository {}

class _MockSepaVirtualPayeeRepository extends Mock
    implements SepaVirtualPayeeRepository {}

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

RecipientDetailsInput _sepaForm(RecipientType type) => RecipientDetailsInput(
  recipientType: type,
  isOwner: true,
  iban: 'FR7630006000011234567890189',
  isCorporate: false,
  firstname: 'Satoshi',
  lastname: 'Nakamoto',
);

void main() {
  late _MockRepository repository;
  late _MockSepaVirtualPayeeRepository virtualPayees;
  late _MockGetRecipientsEnvironmentUsecase environment;
  late AddRecipientUsecase usecase;

  setUpAll(() {
    registerFallbackValue(_sepaForm(RecipientType.sepaEur).toDomain());
  });

  setUp(() {
    repository = _MockRepository();
    virtualPayees = _MockSepaVirtualPayeeRepository();
    environment = _MockGetRecipientsEnvironmentUsecase();
    usecase = AddRecipientUsecase(
      recipientsRepository: repository,
      sepaVirtualPayeeRepository: virtualPayees,
      getRecipientsEnvironmentUsecase: environment,
    );
    when(
      () => environment.execute(),
    ).thenAnswer((_) async => const Ok(Environment.testnet));
    // The API saves every SEPA recipient as a regular one.
    when(
      () => repository.saveRecipient(any(), isTestnet: any(named: 'isTestnet')),
    ).thenAnswer(
      (_) async => Ok(
        Recipient.create(
          recipientId: 'r-1',
          userId: 'user-1',
          userNbr: 1,
          isArchived: false,
          createdAt: DateTime(2026, 10),
          updatedAt: DateTime(2026, 10),
          details: _sepaForm(RecipientType.sepaEur).toDomain(),
        ),
      ),
    );
  });

  Future<Recipient> add(RecipientType type) async {
    final result = await usecase.execute(
      AddRecipientParams(recipientDetails: _sepaForm(type)),
    );
    return (result as Ok<AddRecipientResult, RecipientsFailure>)
        .value
        .recipient;
  }

  test(
    'a Confidential SEPA recipient is activated after it is saved',
    () async {
      when(
        () => virtualPayees.activate(recipientId: 'r-1', isTestnet: true),
      ).thenAnswer((_) async => const Ok(SepaVirtualPayeeStatus.pending));

      final recipient = await add(RecipientType.confidentialSepaEur);

      expect(recipient.type, RecipientType.confidentialSepaEur);
      final saved =
          verify(
                () => repository.saveRecipient(
                  captureAny(),
                  isTestnet: any(named: 'isTestnet'),
                ),
              ).captured.single
              as SepaEurDetails;
      expect(saved.isConfidential, isTrue);
      verify(
        () => virtualPayees.activate(recipientId: 'r-1', isTestnet: true),
      ).called(1);
    },
  );

  test('a failed activation still returns the saved recipient', () async {
    when(
      () => virtualPayees.activate(
        recipientId: any(named: 'recipientId'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Err(RecipientsUnexpectedFailure()));

    final recipient = await add(RecipientType.confidentialSepaEur);

    expect(recipient.recipientId, 'r-1');
    expect(recipient.type, RecipientType.confidentialSepaEur);
  });

  test('a regular SEPA recipient is not activated', () async {
    final recipient = await add(RecipientType.sepaEur);

    expect(recipient.type, RecipientType.sepaEur);
    verifyZeroInteractions(virtualPayees);
  });
}
