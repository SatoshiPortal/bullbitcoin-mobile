import 'package:bull_map/bull_map.dart';
import 'package:get_it/get_it.dart';

import 'package:bb_mobile/features/map/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:bb_mobile/features/map/domain/usecases/sync_merchants_usecase.dart';
import 'package:bb_mobile/features/map/presentation/map_cubit.dart';

final class MapLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<MapCubit>(() {
      final session = BullMap.open();
      return MapCubit(
        LoadCachedMerchantsUsecase(session.cachedMerchants),
        SyncMerchantsUsecase(session.syncMerchants),
      );
    });
  }
}
