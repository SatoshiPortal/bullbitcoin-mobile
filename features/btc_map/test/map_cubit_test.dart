import 'package:btc_map/src/map_types.dart';
import 'package:btc_map/src/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:btc_map/src/domain/usecases/sync_merchants_usecase.dart';
import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _FakeRepository {
  Result<List<Merchant>, BullMapFailure> cachedResult = const Ok([]);
  Result<List<Merchant>, BullMapFailure> syncResult = const Ok([]);

  Future<Result<List<Merchant>, BullMapFailure>> cached() async => cachedResult;

  Future<Result<List<Merchant>, BullMapFailure>> sync() async => syncResult;
}

Merchant _merchant(
  int id,
  String name, {
  double latitude = 0,
  MerchantCategory? category,
}) => Merchant(
  id: id,
  location: GeoPoint(latitude: latitude, longitude: 0),
  name: name,
  category: category,
);

final _aroundNullIsland = GeoBounds(
  south: -0.2,
  west: -0.2,
  north: 0.2,
  east: 0.2,
);

void main() {
  late _FakeRepository repository;

  setUp(() => repository = _FakeRepository());

  MapCubit cubit() => MapCubit(
    LoadCachedMerchantsUsecase(repository.cached),
    SyncMerchantsUsecase(repository.sync),
  );

  test('shows cached merchants, then the synced ones', () async {
    repository.cachedResult = Ok([_merchant(1, 'Old')]);
    repository.syncResult = Ok([_merchant(1, 'Old'), _merchant(2, 'New')]);
    final subject = cubit();
    final states = <List<int>>[];
    final subscription = subject.stream.listen(
      (s) => states.add([for (final m in s.merchants) m.id]),
    );

    await subject.start();
    // Cubit emissions reach listeners asynchronously.
    await pumpEventQueue();
    await subscription.cancel();

    expect(states.first, [1]);
    expect(states.last, [1, 2]);
    expect(subject.state.isSyncing, isFalse);
    expect(subject.state.merchants.last.name, 'New');
  });

  test(
    'a first sync that fails with nothing cached blocks with the failure',
    () async {
      repository.syncResult = const Err(BullMapNetworkFailure());
      final subject = cubit();

      await subject.start();

      expect(subject.state.isBlockingFailure, isTrue);
      expect(subject.state.failure, isA<BullMapNetworkFailure>());
    },
  );

  test(
    'a failed sync with cached merchants keeps them and is not blocking',
    () async {
      repository.cachedResult = Ok([_merchant(1, 'Cached')]);
      repository.syncResult = const Err(BullMapNetworkFailure());
      final subject = cubit();

      await subject.start();

      expect(subject.state.merchants, hasLength(1));
      expect(subject.state.failure, isNotNull);
      expect(subject.state.isBlockingFailure, isFalse);
    },
  );

  test('a successful retry clears the failure', () async {
    repository.syncResult = const Err(BullMapNetworkFailure());
    final subject = cubit();
    await subject.start();

    repository.syncResult = Ok([_merchant(1, 'Back')]);
    await subject.refresh();

    expect(subject.state.failure, isNull);
    expect(subject.state.merchants, hasLength(1));
  });

  test('lists the places in view once the map reports its viewport', () async {
    repository.syncResult = Ok([
      _merchant(1, 'Near'),
      _merchant(2, 'Far away', latitude: 40),
    ]);
    final subject = cubit();
    await subject.start();
    expect(subject.state.listing.places, isEmpty);

    subject.viewportChanged(_aroundNullIsland);

    expect(subject.state.listing.places.map((m) => m.id), [1]);
    expect(subject.state.listing.total, 1);
  });

  test('search looks beyond the viewport', () async {
    repository.syncResult = Ok([
      _merchant(1, 'Coffee'),
      _merchant(2, 'Coffee far away', latitude: 40),
      _merchant(3, 'Bakery'),
    ]);
    final subject = cubit();
    await subject.start();
    subject.viewportChanged(_aroundNullIsland);

    subject.search('cof');

    expect(subject.state.isSearching, isTrue);
    expect(subject.state.listing.places.map((m) => m.id), [1, 2]);
  });

  test('a category filters both the list and the map pins', () async {
    repository.syncResult = Ok([
      _merchant(1, 'Cafe', category: MerchantCategory.coffee),
      _merchant(2, 'Hotel', category: MerchantCategory.hotels),
    ]);
    final subject = cubit();
    await subject.start();
    subject.viewportChanged(_aroundNullIsland);
    final allPins = subject.state.mapMerchants;

    subject.selectCategory(MerchantCategory.coffee);

    expect(subject.state.listing.places.map((m) => m.id), [1]);
    expect(subject.state.listing.categories, {
      MerchantCategory.coffee,
      MerchantCategory.hotels,
    });
    expect(subject.state.mapMerchants.map((m) => m.id), [1]);

    subject.selectCategory(null);
    expect(subject.state.mapMerchants, hasLength(2));
    expect(allPins, hasLength(2));
  });

  test('moving the map does not hand the map a new pin list', () async {
    repository.syncResult = Ok([_merchant(1, 'Cafe')]);
    final subject = cubit();
    await subject.start();
    final pins = subject.state.mapMerchants;

    subject.viewportChanged(_aroundNullIsland);

    // The map re-uploads every pin when the list changes identity.
    expect(identical(subject.state.mapMerchants, pins), isTrue);
  });

  test('an unchanged sync keeps the pins of the picked category', () async {
    final merchants = [
      _merchant(1, 'Cafe', category: MerchantCategory.coffee),
      _merchant(2, 'Hotel', category: MerchantCategory.hotels),
    ];
    repository.syncResult = Ok(merchants);
    final subject = cubit();
    await subject.start();
    subject.selectCategory(MerchantCategory.coffee);
    final pins = subject.state.mapMerchants;

    // The repository hands back the same list when nothing changed.
    await subject.refresh();

    expect(identical(subject.state.mapMerchants, pins), isTrue);
  });
}
