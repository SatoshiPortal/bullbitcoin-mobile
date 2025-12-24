import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';

class Bip85EntropyDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {}

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<Bip85EntropyCubit>(
      () => Bip85EntropyCubit(
        fetchAllBip85DerivationsUsecase: sl(),
        deriveNextBip85MnemonicFromDefaultWalletUsecase: sl(),
        deriveNextBip85HexFromDefaultWalletUsecase: sl(),
        getDefaultSeedUsecase: sl(),
        aliasBip85DerivationUsecase: sl(),
        revokeBip85DerivationUsecase: sl(),
        activateBip85DerivationUsecase: sl(),
      ),
    );
  }
}
