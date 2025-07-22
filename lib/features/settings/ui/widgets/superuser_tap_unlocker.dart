import 'package:bb_mobile/core/widgets/buttons/multi_tap_trigger.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SuperuserTapUnlocker extends StatelessWidget {
  const SuperuserTapUnlocker({
    super.key,
    this.tapsReachedMessageBackgroundColor,
    this.tapsReachedMessageTextColor,
    required this.child,
  });

  final Color? tapsReachedMessageBackgroundColor;
  final Color? tapsReachedMessageTextColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    return MultiTapTrigger(
      onRequiredTaps: () async {
        await context.read<SettingsCubit>().toggleSuperuserMode(!isSuperuser);
      },
      tapsReachedMessage:
          isSuperuser ? 'Superuser mode disabled.' : 'Superuser mode unlocked!',
      tapsReachedMessageBackgroundColor: tapsReachedMessageBackgroundColor,
      tapsReachedMessageTextColor: tapsReachedMessageTextColor,
      child: child,
    );
  }
}
