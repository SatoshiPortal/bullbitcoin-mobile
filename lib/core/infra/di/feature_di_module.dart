// lib/core/di/feature_module.dart
import 'package:get_it/get_it.dart';

abstract class FeatureDiModule {
  Future<void> registerFrameworksAndDrivers(GetIt sl);
  Future<void> registerDrivenAdapters(GetIt sl);
  Future<void> registerApplicationServices(GetIt sl);
  Future<void> registerUseCases(GetIt sl);
  Future<void> registerDrivingAdapters(GetIt sl);
}
