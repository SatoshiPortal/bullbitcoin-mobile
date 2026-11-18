import 'dart:async';

import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:btc_map/src/domain/repositories/map_location_repository.dart';
import 'package:btc_map/src/domain/usecases/get_initial_map_center_usecase.dart';
import 'package:btc_map/src/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:btc_map/src/domain/usecases/select_merchants_usecase.dart';
import 'package:btc_map/src/domain/usecases/sync_merchants_usecase.dart';
import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _LocationRepository implements MapLocationRepository {
  final result = Completer<Result<GeoPoint, BullMapFailure>>();
  int calls = 0;

  @override
  Future<Result<GeoPoint, BullMapFailure>> locate() {
    calls++;
    return result.future;
  }
}

void main() {
  MapCubit cubit(_LocationRepository repository) => MapCubit(
    LoadCachedMerchantsUsecase(() async => const Ok([])),
    SyncMerchantsUsecase(() async => const Ok([])),
    const SelectMerchantsUsecase(),
    GetInitialMapCenterUsecase(repository),
  );

  test(
    'merchants load without waiting for centering; refresh never locates again',
    () async {
      final repository = _LocationRepository();
      final subject = cubit(repository);
      addTearDown(subject.close);
      await subject.start();
      expect(subject.state.isSyncing, isFalse);
      expect(subject.state.initialCenter, isNull);
      final point = GeoPoint(latitude: 45.5, longitude: -73.6);
      repository.result.complete(Ok(point));
      await pumpEventQueue();
      expect(subject.state.initialCenter, point);
      await subject.refresh();
      await subject.start();
      expect(repository.calls, 1);
    },
  );

  test('an unavailable IP location quietly keeps the world view', () async {
    final repository = _LocationRepository();
    final subject = cubit(repository);
    addTearDown(subject.close);
    repository.result.complete(const Err(BullMapNetworkFailure()));
    await subject.start();
    await pumpEventQueue();
    expect(subject.state.initialCenter, isNull);
    expect(subject.state.failure, isNull);
    expect(subject.state.isBlockingFailure, isFalse);
  });

  test('closing the map before the response is safe', () async {
    final repository = _LocationRepository();
    final subject = cubit(repository);
    await subject.start();
    await subject.close();
    repository.result.complete(Ok(GeoPoint(latitude: 1, longitude: 2)));
    await pumpEventQueue();
    expect(subject.state.initialCenter, isNull);
  });
}
