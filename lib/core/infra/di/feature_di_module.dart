abstract class FeatureDiModule {
  Future<void> registerFrameworksAndDrivers();
  Future<void> registerDrivenAdapters();
  Future<void> registerApplicationServices();
  Future<void> registerUseCases();
  Future<void> registerDrivingAdapters();
}
