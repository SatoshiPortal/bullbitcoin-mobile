import 'package:bb_mobile/core/router/app_router.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AppStartupWidget extends StatefulWidget {
  const AppStartupWidget({super.key, required this.app});

  final Widget app;

  @override
  State<AppStartupWidget> createState() => _AppStartupWidgetState();
}

class _AppStartupWidgetState extends State<AppStartupWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppStartupBloc, AppStartupState>(
      builder: (context, state) {
        if (state is AppStartupInitial) {
          // TODO: return a splash or loading screen
        } else if (state is AppStartupLoadingInProgress) {
          // TODO: return a loading screen
        } else if (state is AppStartupSuccess) {
          return widget.app;
        } else if (state is AppStartupFailure) {
          // TODO: return a failure page
        }

        // TODO: remove this when all states are handled and return the
        //  appropriate widget
        return const SizedBox.shrink();
      },
    );
  }
}
