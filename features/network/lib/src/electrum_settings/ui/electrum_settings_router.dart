import 'screens/electrum_settings_screen.dart';
import '../presentation/electrum_settings_bloc.dart';
import '../../tor_settings/presentation/tor_settings_cubit.dart';
import '../../tor_settings/public/tor_settings_scope.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ElectrumSettingsRoute {
  electrumSettings('/electrum-settings');

  final String path;
  const ElectrumSettingsRoute(this.path);
}

class ElectrumSettingsRouter {
  static GoRoute route({
    required ElectrumSettingsBloc Function() createBloc,
    required TorSettingsCubit Function() createTorCubit,
  }) => GoRoute(
    name: ElectrumSettingsRoute.electrumSettings.name,
    path: ElectrumSettingsRoute.electrumSettings.path,
    builder: (_, _) => BlocProvider(
      create: (_) =>
          createBloc()..add(const ElectrumSettingsLoaded(isLiquid: false)),
      child: TorSettingsScope(
        createCubit: createTorCubit,
        child: const ElectrumSettingsScreen(),
      ),
    ),
  );
}
