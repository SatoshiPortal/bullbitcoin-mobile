import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:get_it/get_it.dart';

class Bip85RegistryLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<Bip85RegistryFacade>(Bip85RegistryFacade.new);
  }
}
