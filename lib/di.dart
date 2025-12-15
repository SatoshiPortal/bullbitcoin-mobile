import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/infra/di/service_locator.dart';

// Configure core and feature dependencies following a clear order to avoid
// cyclic dependencies and have outer layers depend on inner layers only.
Future<void> configureDependencies() async {
  // 1. Core infra first
  await registerCoreDependencies();

  // 2. Feature modules
  final modules = <FeatureDiModule>[
    //WalletsDiModule(),
    //ReceiveDiModule(),
  ];

  // 2. Register frameworks and drivers
  for (final module in modules) {
    module.registerFrameworksAndDrivers(sl);
  }
  // 3. Register driven adapters
  for (final module in modules) {
    module.registerDrivenAdapters(sl);
  }
  // 4. Register application services
  for (final module in modules) {
    module.registerApplicationServices(sl);
  }
  // 5. Register use cases
  for (final module in modules) {
    module.registerUseCases(sl);
  }
  // 6. Register driving adapters
  for (final module in modules) {
    module.registerDrivingAdapters(sl);
  }
}
