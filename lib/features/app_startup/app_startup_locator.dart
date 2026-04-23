import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:get_it/get_it.dart';

class AppStartupLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<AppStartupBloc>(() => AppStartupBloc());
  }
}
