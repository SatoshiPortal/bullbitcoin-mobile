import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details_repository.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/update_interac_security_details_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInteracSecurityDetailsRepository extends Mock
    implements InteracSecurityDetailsRepository {}

void main() {
  late _MockInteracSecurityDetailsRepository repository;
  late UpdateInteracSecurityDetailsUsecase usecase;
  late InteracSecurityDetails details;

  setUp(() {
    repository = _MockInteracSecurityDetailsRepository();
    usecase = UpdateInteracSecurityDetailsUsecase(repository);
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
      () => repository.update(details),
    ).thenAnswer((_) async => const Ok<void, RecipientsFailure>(null));

    final result = await usecase.execute(details);

    expect(result, isA<Ok<void, RecipientsFailure>>());
    verify(() => repository.update(details)).called(1);
  });
}
