import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/samrock/data/datasources/samrock_api_datasource.dart';
import 'package:bb_mobile/features/samrock/data/repositories/samrock_repository_impl.dart';
import 'package:bb_mobile/features/samrock/domain/repositories/samrock_repository.dart';
import 'package:bb_mobile/features/samrock/domain/usecases/complete_samrock_setup_usecase.dart';
import 'package:bb_mobile/features/samrock/presentation/bloc/samrock_cubit.dart';
import 'package:get_it/get_it.dart';

class SamrockLocator {
  static void setup(GetIt locator) {
    // Datasources
    locator.registerLazySingleton<SamrockApiDatasource>(
      () => SamrockApiDatasource(),
    );

    // Repositories
    locator.registerLazySingleton<SamrockRepository>(
      () => SamrockRepositoryImpl(
        datasource: locator<SamrockApiDatasource>(),
      ),
    );

    // Usecases
    locator.registerFactory<CompleteSamrockSetupUsecase>(
      () => CompleteSamrockSetupUsecase(
        walletRepository: locator<WalletRepository>(),
        samrockRepository: locator<SamrockRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<SamrockCubit>(
      () => SamrockCubit(
        completeSamrockSetupUsecase: locator<CompleteSamrockSetupUsecase>(),
      ),
    );
  }
}
