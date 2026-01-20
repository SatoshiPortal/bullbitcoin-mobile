import 'package:bb_mobile/core/mesh/mesh_service.dart';
import 'package:get_it/get_it.dart';

class MeshLocator {
  static void registerServices(GetIt locator) {
    locator.registerLazySingleton<MeshService>(() => MeshService());
  }
}
