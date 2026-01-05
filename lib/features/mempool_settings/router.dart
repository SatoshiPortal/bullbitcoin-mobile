import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/ui/mempool_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

class MempoolSettingsRoute {
  static const String name = 'mempoolSettings';
  static const String path = '/mempool-settings';

  static GoRoute get route => GoRoute(
    name: name,
    path: path,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: BlocProvider(
        create: (_) => sl<MempoolSettingsCubit>(),
        child: const MempoolSettingsScreen(),
      ),
    ),
  );
}
