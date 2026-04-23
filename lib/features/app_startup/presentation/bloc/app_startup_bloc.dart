import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'app_startup_event.dart';
part 'app_startup_state.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState> {
  AppStartupBloc() : super(const AppStartupInitial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
  }

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupLoadingInProgress());
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      log.info(
        'Recovery build started: ${packageInfo.appName} v${packageInfo.version}+${packageInfo.buildNumber}',
      );
    } catch (_) {}
    emit(const AppStartupFailure(null));
  }
}
