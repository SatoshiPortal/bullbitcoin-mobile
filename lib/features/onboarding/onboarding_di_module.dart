import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';

class OnboardingDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        walletRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUsecase: sl(),
        completePhysicalBackupVerificationUsecase: sl(),
      ),
    );
  }
}
