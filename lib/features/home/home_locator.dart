import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/app_locator.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';

class HomeLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<HomeBloc>(
      () => HomeBloc(
        getWalletsUseCase: locator<GetWalletsUseCase>(),
      ),
    );
  }
}
