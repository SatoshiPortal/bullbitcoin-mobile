import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  late _MockSeedRepository repository;
  late DeleteSeedUsecase usecase;

  const fingerprint = 'abc123';

  setUp(() {
    repository = _MockSeedRepository();
    usecase = DeleteSeedUsecase(seedRepository: repository);
  });

  group('DeleteSeedUsecase', () {
    test('returns Ok on successful delete', () async {
      when(() => repository.delete(fingerprint)).thenAnswer(
        (_) async => const Ok(null),
      );

      final result = await usecase.execute(fingerprint);

      expect(result, isA<Ok>());
    });

    test('returns SeedDeleteFailure on repository error — no raw leak', () async {
      when(() => repository.delete(fingerprint)).thenAnswer(
        (_) async => const Err(SeedDeleteFailure('raw storage error')),
      );

      final result = await usecase.execute(fingerprint);

      expect(result, isA<Err>());
      final failure = (result as Err).failure;
      expect(failure, isA<SeedDeleteFailure>());
      // logMessage carries the raw reason for logs — never exposed to the UI.
      expect((failure as SeedDeleteFailure).logMessage, isNotNull);
    });
  });
}
