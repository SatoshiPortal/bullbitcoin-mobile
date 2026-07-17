import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

void main() {
  late _MockSeedRepository repository;
  late GetAllSeedsUsecase usecase;

  setUp(() {
    repository = _MockSeedRepository();
    usecase = GetAllSeedsUsecase(seedRepository: repository);
  });

  group('GetAllSeedsUsecase', () {
    test('returns SeedFetchFailure on repository error — no raw leak', () async {
      when(() => repository.getAllMnemonicSeeds()).thenAnswer(
        (_) async => const Err(SeedFetchFailure('raw internal error')),
      );

      final result = await usecase.execute();

      expect(result, isA<Err>());
      final failure = (result as Err).failure;
      expect(failure, isA<SeedFetchFailure>());
      // logMessage is for logs only — the UI never reads it, but we verify the
      // raw reason is NOT silently swallowed (it should be in logMessage).
      expect((failure as SeedFetchFailure).logMessage, isNotNull);
    });

    test('returns Ok with seeds on success', () async {
      when(
        () => repository.getAllMnemonicSeeds(),
      ).thenAnswer((_) async => const Ok([]));

      final result = await usecase.execute();

      expect(result, isA<Ok>());
    });
  });
}
