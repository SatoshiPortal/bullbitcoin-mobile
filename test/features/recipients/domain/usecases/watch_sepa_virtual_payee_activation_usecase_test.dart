import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_activation_progress.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../recipient_fixtures.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late FakeRecipientsGateway repository;
  late _MockSettingsRepository settings;
  late WatchSepaVirtualPayeeActivationUsecase usecase;

  setUp(() {
    repository = FakeRecipientsGateway();
    settings = _MockSettingsRepository();
    when(() => settings.fetch()).thenAnswer((_) async => settingsFixture());
    usecase = WatchSepaVirtualPayeeActivationUsecase(
      repository,
      settings,
      Duration.zero,
      Duration.zero,
      1,
    );
  });

  test('activates when refresh finds no virtual payee sibling', () async {
    repository.findResult = const Ok(null);
    repository.activatedResult = sepaRecipientFixture(
      virtualPayeeStatus: 'ACTIVE',
    );

    final results = await usecase.execute(recipientId: 'r1').toList();

    expect(repository.findCalls, hasLength(1));
    expect(repository.activateCalls, hasLength(1));
    final progress =
        (results.single
                as Ok<SepaVirtualPayeeActivationProgress, RecipientsFailure>)
            .value;
    expect(
      (progress.recipient.details as SepaEurDetails).isVirtualPayeeActive,
      isTrue,
    );
  });

  test('polls an existing CREATED payee without activating it again', () async {
    repository.findResults.addAll([
      Ok<Recipient?, RecipientsFailure>(
        sepaRecipientFixture(virtualPayeeStatus: 'CREATED'),
      ),
      Ok<Recipient?, RecipientsFailure>(
        sepaRecipientFixture(virtualPayeeStatus: 'ACTIVE'),
      ),
    ]);

    final results = await usecase.execute(recipientId: 'r1').toList();

    expect(repository.activateCalls, isEmpty);
    expect(results, hasLength(1));
    final progress =
        (results.single
                as Ok<SepaVirtualPayeeActivationProgress, RecipientsFailure>)
            .value;
    expect(
      (progress.recipient.details as SepaEurDetails).isVirtualPayeeActive,
      isTrue,
    );
  });

  test(
    'polls an existing PROCESSING payee without activating it again',
    () async {
      repository.findResults.addAll([
        Ok<Recipient?, RecipientsFailure>(
          sepaRecipientFixture(virtualPayeeStatus: 'PROCESSING'),
        ),
        Ok<Recipient?, RecipientsFailure>(
          sepaRecipientFixture(virtualPayeeStatus: 'ACTIVE'),
        ),
      ]);

      final results = await usecase.execute(recipientId: 'r1').toList();

      expect(repository.activateCalls, isEmpty);
      expect(results, hasLength(1));
      final progress =
          (results.single
                  as Ok<SepaVirtualPayeeActivationProgress, RecipientsFailure>)
              .value;
      expect(
        (progress.recipient.details as SepaEurDetails).isVirtualPayeeActive,
        isTrue,
      );
    },
  );

  test('returns a typed refresh failure without throwing', () async {
    repository.findResult = const Err(
      RecipientRefreshFailure('safe refresh failure'),
    );

    final results = await usecase.execute(recipientId: 'r1').toList();

    expect(
      results.single,
      isA<Err<SepaVirtualPayeeActivationProgress, RecipientsFailure>>(),
    );
  });

  test(
    'returns a typed failure for an unknown status instead of polling',
    () async {
      repository.findResult = Ok(
        sepaRecipientFixture(virtualPayeeStatus: 'UNRECOGNIZED'),
      );

      final results = await usecase.execute(recipientId: 'r1').toList();

      expect(repository.activateCalls, isEmpty);
      expect(repository.findCalls, hasLength(1));
      expect(
        results.single,
        isA<Err<SepaVirtualPayeeActivationProgress, RecipientsFailure>>(),
      );
    },
  );
}
