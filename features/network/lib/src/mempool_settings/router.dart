import 'presentation/mempool_settings_cubit.dart';
import 'ui/mempool_settings_screen.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MempoolSettingsRoute {
  static const String name = 'mempoolSettings';
  static const String path = '/mempool-settings';

  static GoRoute route(MempoolSettingsCubit Function() createCubit) => GoRoute(
    name: name,
    path: path,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: BlocProvider(
        create: (_) => createCubit(),
        child: const MempoolSettingsScreen(),
      ),
    ),
  );
}
