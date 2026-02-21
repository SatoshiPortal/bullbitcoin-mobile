import 'package:bb_mobile/features/manual_swap_status_reset/presentation/cubit/manual_swap_status_reset_cubit.dart';
import 'package:bb_mobile/features/manual_swap_status_reset/ui/manual_swap_status_reset_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ManualSwapStatusResetRoute {
  static const String name = 'manualSwapStatusReset';
  static const String path = '/manual-swap-status-reset';

  static GoRoute get route => GoRoute(
    name: name,
    path: path,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: BlocProvider(
        create: (_) => locator<ManualSwapStatusResetCubit>(),
        child: const ManualSwapStatusResetScreen(),
      ),
    ),
  );
}
