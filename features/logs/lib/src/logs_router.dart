import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'presentation/logs_cubit.dart';
import 'ui/log_settings_screen.dart';

final class LogsRouter {
  static final route = GoRoute(
    name: 'logs',
    path: 'logs',
    builder: (context, state) => BlocProvider(
      create: (_) => GetIt.I<LogsCubit>()..load(),
      child: const LogSettingsScreen(),
    ),
  );
}
