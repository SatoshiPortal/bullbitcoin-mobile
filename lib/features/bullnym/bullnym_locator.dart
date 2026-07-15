import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:get_it/get_it.dart';

class BullnymLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BullnymClientPort>(
      () => BullnymHttpClient(nowSecs: () => locator<Clock>().nowSecs()),
    );
    locator.registerFactory<BullnymFacade>(
      () => BullnymFacade(
        client: locator<BullnymClientPort>(),
        // Route the Bullpay request timestamp through the injectable clock so a
        // skewed device clock is controllable in tests (the signed timestamp
        // gates the server's signature time-window).
        nowSecs: () => locator<Clock>().nowSecs(),
      ),
    );
  }
}
