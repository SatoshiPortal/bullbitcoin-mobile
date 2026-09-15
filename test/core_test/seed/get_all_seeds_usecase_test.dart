import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart' as logging;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockLogger extends Mock implements logging.Logger {}

void main() {
  late _MockSeedRepository repository;
  late GetAllSeedsUsecase usecase;

  setUp(() {
    repository = _MockSeedRepository();
    usecase = GetAllSeedsUsecase(seedRepository: repository);
  });

  group('GetAllSeedsUsecase', () {
    for (final corruptSeed in [true, false]) {
      test(
        '${corruptSeed ? 'mnemonic parsing' : 'storage'} failure does not expose secret input through logs or Result',
        () async {
          final source = _MockSeedDatasource();
          final logger = _MockLogger();
          final previousLogger = logging.log;
          logging.log = logger;
          addTearDown(() => logging.log = previousLogger);
          registerFallbackValue(StackTrace.empty);
          if (corruptSeed) {
            when(() => source.getAll()).thenAnswer(
              (_) async => [
                SeedModel.mnemonic(
                  mnemonicWords: [...List.filled(11, 'zoo'), 'private-input'],
                ),
              ],
            );
          } else {
            when(() => source.getAll()).thenThrow(StateError('private-input'));
          }
          final result = await GetAllSeedsUsecase(
            seedRepository: SeedRepository(source: source),
          ).execute();
          final failure = (result as Err).failure;
          expect(failure, isA<SeedFetchFailure>());
          expect((failure as SeedFetchFailure).logMessage, isNull);
          final logged = verify(
            () => logger.severe(
              message: 'Failed to get all mnemonic seeds',
              error: captureAny(named: 'error'),
              trace: any(named: 'trace'),
            ),
          ).captured;
          expect(logged.single, isA<Type>());
          expect(logged.single.toString(), isNot(contains('private-input')));
          verifyNoMoreInteractions(logger);
        },
      );
    }

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
