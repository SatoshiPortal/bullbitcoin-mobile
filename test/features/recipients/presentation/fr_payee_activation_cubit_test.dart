import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_activation_progress.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/presentation/fr_payee_activation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../recipient_fixtures.dart';

class _MockWatchUsecase extends Mock
    implements WatchSepaVirtualPayeeActivationUsecase {}

void main() {
  test('maps active workflow output to active presentation state', () async {
    final usecase = _MockWatchUsecase();
    final recipient = sepaRecipientFixture(
      virtualPayeeStatus: 'ACTIVE',
      isConfidential: true,
    );
    when(() => usecase.execute(recipientId: 'r1')).thenAnswer(
      (_) => Stream.value(
        Ok<SepaVirtualPayeeActivationProgress, RecipientsFailure>(
          SepaVirtualPayeeActivationProgress(
            recipient: recipient,
            initialWaitTimedOut: false,
          ),
        ),
      ),
    );
    final cubit = FrPayeeActivationCubit(
      usecase,
      recipient: sepaViewModelFixture(),
    );

    await cubit.start();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isActive, isTrue);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('maps a typed activation failure to presentation state', () async {
    final usecase = _MockWatchUsecase();
    when(() => usecase.execute(recipientId: 'r1')).thenAnswer(
      (_) => Stream.value(
        const Err<SepaVirtualPayeeActivationProgress, RecipientsFailure>(
          RecipientActivationFailure('private API response'),
        ),
      ),
    );
    final cubit = FrPayeeActivationCubit(
      usecase,
      recipient: sepaViewModelFixture(),
    );

    await cubit.start();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.failure, isA<RecipientActivationFailure>());
    await cubit.close();
  });
}
