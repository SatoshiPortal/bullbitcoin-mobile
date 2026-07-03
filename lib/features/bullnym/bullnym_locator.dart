import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:get_it/get_it.dart';

class BullnymLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BullnymClientPort>(() => BullnymHttpClient());
    locator.registerFactory<BullnymFacade>(
      () => BullnymFacade(client: locator<BullnymClientPort>()),
    );
  }
}
