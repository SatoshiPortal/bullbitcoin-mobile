import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/restamp_sp_payment_times_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

void main() {
  late MockSpAccountRepository repository;
  late RestampSpPaymentTimesUsecase usecase;

  setUp(() {
    repository = MockSpAccountRepository();
    usecase = RestampSpPaymentTimesUsecase(repository: repository);
  });

  test('restamps through the repository', () {
    when(() => repository.restampMissingTimestamps())
        .thenReturn(const Ok<void, SilentFailure>(null));

    final result = usecase.execute();

    expect(result, isA<Ok<void, SilentFailure>>());
    verify(() => repository.restampMissingTimestamps()).called(1);
  });

  test('forwards a repository failure', () {
    when(() => repository.restampMissingTimestamps()).thenReturn(
      const Err<void, SilentFailure>(SilentUnexpected('lock poisoned')),
    );

    final result = usecase.execute();

    expect(
      (result as Err<void, SilentFailure>).failure,
      isA<SilentUnexpected>(),
    );
  });
}
