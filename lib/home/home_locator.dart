import 'package:bb_mobile/_core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/locator.dart';

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
