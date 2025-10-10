import 'package:bb_mobile/features/electrum_settings/frameworks/ui/screens/electrum_settings_screen.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/locator.dart';
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
      return BlocProvider<ElectrumSettingsBloc>(
        create:
            (context) =>
                locator<ElectrumSettingsBloc>()
                  ..add(const ElectrumSettingsLoaded(isLiquid: false)),
        child: const ElectrumSettingsScreen(),
      );
    },
  );
}
