import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/screens/tor_settings_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TorSettingsRoute {
  torSettings('tor-settings');

  final String path;
  const TorSettingsRoute(this.path);
}

class TorSettingsRouter {
  static final route = GoRoute(
    name: TorSettingsRoute.torSettings.name,
    path: TorSettingsRoute.torSettings.path,
    builder: (context, state) => MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => locator<ElectrumSettingsBloc>()),
        BlocProvider(create: (context) => locator<TorSettingsCubit>()),
      ],
      child: const TorSettingsScreen(),
    ),
  );
}
