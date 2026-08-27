import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/logs_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/log_viewer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<LogsCubit>()..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.logSettingsLogsTitle)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const LogsViewerWidget(),
          ),
        ),
      ),
    );
  }
}
