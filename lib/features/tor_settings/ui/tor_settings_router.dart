import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/screens/tor_settings_screen.dart';
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
    builder: (context, state) => BlocProvider(
      create: (context) => sl<TorSettingsCubit>()..init(),
      child: const TorSettingsScreen(),
    ),
  );
}
