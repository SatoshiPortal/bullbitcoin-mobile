import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_sync_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BackgroundSyncScreen extends StatelessWidget {
  const BackgroundSyncScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BackgroundSyncCubit>()..load(),
    child: Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsBackgroundSyncTitle)),
      body: SafeArea(
        child: BlocConsumer<BackgroundSyncCubit, BackgroundSyncState>(
          listenWhen: (previous, current) =>
              current.failure != null && previous.failure != current.failure,
          listener: (context, state) =>
              SnackBarUtils.showSnackBar(context, switch (state.failure) {
                final SettingsStorageFailure failure => failure.toTranslated(
                  context,
                ),
                _ => context.loc.backgroundSyncSaveFailed,
              }),
          builder: (context, state) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.loc.backgroundSyncDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              const Gap(16),
              for (final interval in BackgroundSyncInterval.values)
                ListTile(
                  key: Key('background-sync-${interval.name}'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: context.appColors.transparent,
                  selected: state.interval == interval,
                  title: Text(_label(context, interval)),
                  trailing: state.interval == interval
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () =>
                      context.read<BackgroundSyncCubit>().choose(interval),
                ),
              if (state.interval == BackgroundSyncInterval.off) ...[
                const Gap(8),
                Text(
                  context.loc.backgroundSyncOffHint,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  static String _label(BuildContext context, BackgroundSyncInterval interval) =>
      switch (interval) {
        BackgroundSyncInterval.minutes15 =>
          context.loc.backgroundSyncEvery15Minutes,
        BackgroundSyncInterval.minutes30 =>
          context.loc.backgroundSyncEvery30Minutes,
        BackgroundSyncInterval.hour1 => context.loc.backgroundSyncEveryHour,
        BackgroundSyncInterval.hours6 => context.loc.backgroundSyncEvery6Hours,
        BackgroundSyncInterval.hours24 => context.loc.backgroundSyncEveryDay,
        BackgroundSyncInterval.off => context.loc.backgroundSyncOff,
      };
}
