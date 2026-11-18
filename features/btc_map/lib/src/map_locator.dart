import 'package:btc_map/src/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:btc_map/src/domain/usecases/sync_merchants_usecase.dart';
import 'package:btc_map/src/map_types.dart';
import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:get_it/get_it.dart';

import 'data/ip_map_location_repository.dart';

import 'domain/usecases/get_initial_map_center_usecase.dart';
import 'domain/usecases/select_merchants_usecase.dart';

final class MapLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<MapCubit>(() {
      final session = BullMap.open();
      return MapCubit(
        LoadCachedMerchantsUsecase(session.cachedMerchants),
        SyncMerchantsUsecase(session.syncMerchants),
        const SelectMerchantsUsecase(),
        GetInitialMapCenterUsecase(IpMapLocationRepository()),
      );
    });
  }
}
