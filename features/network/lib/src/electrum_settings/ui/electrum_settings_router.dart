import 'screens/electrum_settings_screen.dart';
import '../presentation/electrum_settings_bloc.dart';
import '../../tor_settings/public/tor_settings_scope.dart';

import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ElectrumSettingsRoute {
  electrumSettings('/electrum-settings');

  final String path;
  const ElectrumSettingsRoute(this.path);
}

class ElectrumSettingsRouter {
  static final route = GoRoute(
    name: ElectrumSettingsRoute.electrumSettings.name,
    path: ElectrumSettingsRoute.electrumSettings.path,
    builder: (context, state) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<ElectrumSettingsBloc>(
            create: (context) =>
                GetIt.I<ElectrumSettingsBloc>()
                  ..add(const ElectrumSettingsLoaded(isLiquid: false)),
          ),
        ],
        child: const TorSettingsScope(child: ElectrumSettingsScreen()),
      );
    },
  );
}
