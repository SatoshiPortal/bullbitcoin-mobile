import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockSeedStoreTypeDatasource extends Mock
    implements SeedStoreTypeDatasource {}

/// Backs the "migrate your storage" warning on the home screen.
///
/// The read goes to shared preferences, which can fail transiently, so the
/// three outcomes — legacy, not legacy, and could-not-tell — have to stay
/// distinguishable all the way up to the bloc.
void main() {
  late _MockSeedStoreTypeDatasource storeType;
  late SeedRepository repository;

  setUp(() {
    storeType = _MockSeedStoreTypeDatasource();
    repository = SeedRepository(
      source: _MockSeedDatasource(),
      storeType: storeType,
    );
  });

  test('fss9 is legacy storage', () async {
    when(() => storeType.read()).thenAnswer(
      (_) async => SeedStoreTypeModel.fromEntity(
        const SeedStoreType(storageLibrary: SeedStorageLibrary.fss9),
      ),
    );

    expect((await repository.isOnLegacyStorage() as Ok).value, isTrue);
  });

  test('fss10 is not legacy storage', () async {
    when(() => storeType.read()).thenAnswer(
      (_) async => SeedStoreTypeModel.fromEntity(
        const SeedStoreType(storageLibrary: SeedStorageLibrary.fss10),
      ),
    );

    expect((await repository.isOnLegacyStorage() as Ok).value, isFalse);
  });

  test('an unset store type is not legacy — a fresh install', () async {
    when(() => storeType.read()).thenAnswer((_) async => null);

    expect((await repository.isOnLegacyStorage() as Ok).value, isFalse);
  });

  test('a failed read is an Err, NOT "not on legacy storage"', () async {
    // The bloc keeps its previous value on Err precisely because these are
    // different facts: collapsing to `false` would drop the migration warning
    // for a user who is genuinely on legacy storage.
    when(
      () => storeType.read(),
    ).thenThrow(StateError('SharedPreferences: channel unavailable'));

    final result = await repository.isOnLegacyStorage();

    expect(result, isA<Err<bool, SeedFailure>>());
    final failure = (result as Err).failure as SeedFailure;
    expect(failure, isA<SeedFetchFailure>());
    expect(failure.logMessage, isNot(contains('channel unavailable')));
  });
}
