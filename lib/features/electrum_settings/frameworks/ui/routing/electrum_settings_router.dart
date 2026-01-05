import 'package:bb_mobile/features/electrum_settings/frameworks/ui/screens/electrum_settings_screen.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

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
                sl<ElectrumSettingsBloc>()
                  ..add(const ElectrumSettingsLoaded(isLiquid: false)),
          ),
          BlocProvider<TorSettingsCubit>(
            create: (context) => sl<TorSettingsCubit>()..init(),
          ),
        ],
        child: const ElectrumSettingsScreen(),
      );
    },
  );
}
