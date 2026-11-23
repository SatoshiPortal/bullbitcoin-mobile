import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/bloc/app_startup_bloc.dart';

export '../presentation/app_bloc_observer.dart' show AppBlocObserver;
export '../ui/screens/app_init_error_screen.dart' show AppInitErrorScreen;
export '../ui/screens/route_error_screen.dart' show RouteErrorScreen;

/// Continues startup after Access has authorized the inventory session.
void completeAppStartupUnlock(BuildContext context) {
  context.read<AppStartupBloc>().add(const AppStartupUnlocked());
}
