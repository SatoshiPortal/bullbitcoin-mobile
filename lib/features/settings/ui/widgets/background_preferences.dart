import '../../presentation/settings_failure_l10n.dart';

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/bloc/background_preferences_cubit.dart';

class BackgroundPreferences extends StatelessWidget {
  const BackgroundPreferences({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<BackgroundPreferencesCubit>()..load(),
    child: BlocBuilder<BackgroundPreferencesCubit, BackgroundPreferencesState>(
      builder: (context, state) => Column(
        children: [
          Text(context.loc.backgroundSyncTitle),
          Text(context.loc.backgroundSyncDescription),
          BullDropdown<BackgroundSyncInterval>(
            value: state.interval,
            items: [
              for (final interval in BackgroundSyncInterval.values)
                DropdownMenuItem(
                  value: interval,
                  child: Text(_label(context, interval)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                context.read<BackgroundPreferencesCubit>().load(
                  interval: value,
                );
              }
            },
          ),
          Text(context.loc.backgroundNotificationsTitle),
          Text(
            state.allowed
                ? context.loc.backgroundNotificationsAllowed
                : context.loc.backgroundNotificationsDenied,
          ),
          BullButton.big(
            label: context.loc.backgroundNotificationsRequest,
            bgColor: context.bull.primary,
            textColor: context.bull.onPrimary,
            onPressed: () => context.read<BackgroundPreferencesCubit>().load(
              requestPermission: true,
            ),
          ),
          BullButton.big(
            label: context.loc.backgroundNotificationsSettings,
            bgColor: context.bull.surface,
            textColor: context.bull.onSurface,
            onPressed: () => context.read<BackgroundPreferencesCubit>().load(
              openSettings: true,
            ),
          ),
          if (state.failure case final failure?)
            Text(failure.toTranslated(context)),
        ],
      ),
    ),
  );

  String _label(
    BuildContext context,
    BackgroundSyncInterval interval,
  ) => switch (interval) {
    BackgroundSyncInterval.off => context.loc.backgroundSyncOff,
    BackgroundSyncInterval.minutes15 => context.loc.backgroundSyncMinutes(15),
    BackgroundSyncInterval.minutes30 => context.loc.backgroundSyncMinutes(30),
    BackgroundSyncInterval.hour1 => context.loc.backgroundSyncHours(1),
    BackgroundSyncInterval.hours6 => context.loc.backgroundSyncHours(6),
    BackgroundSyncInterval.hours24 => context.loc.backgroundSyncHours(24),
  };
}
