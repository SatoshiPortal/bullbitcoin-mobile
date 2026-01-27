import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';

class ImportWatchOnlyWalletDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<ImportWatchOnlyDescriptorUsecase>(
      () => ImportWatchOnlyDescriptorUsecase(
        walletRepository: sl(),
      ),
    );

    sl.registerFactory<ImportWatchOnlyXpubUsecase>(
      () => ImportWatchOnlyXpubUsecase(
        walletRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {}
}
