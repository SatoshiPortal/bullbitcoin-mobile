import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/restamp_sp_payment_times_usecase.dart';
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
    when(
      () => repository.restampMissingTimestamps(),
    ).thenReturn(const Ok<void, SpFailure>(null));

    final result = usecase.execute();

    expect(result, isA<Ok<void, SpFailure>>());
    verify(() => repository.restampMissingTimestamps()).called(1);
  });

  test('forwards a repository failure', () {
    when(
      () => repository.restampMissingTimestamps(),
    ).thenReturn(const Err<void, SpFailure>(SpUnexpected('lock poisoned')));

    final result = usecase.execute();

    expect((result as Err<void, SpFailure>).failure, isA<SpUnexpected>());
  });
}
