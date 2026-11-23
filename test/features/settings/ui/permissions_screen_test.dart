import 'package:background_tasks/background_tasks.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/settings/domain/repositories/background_preferences_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/background_preferences_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_preferences_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/permissions_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoBar, BullSwitch;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

/// The system refuses every notification request; [allowed] stands for the
/// user's choice in the system settings.
class _Preferences implements BackgroundPreferencesRepository {
  var selected = BackgroundSyncInterval.hours6;
  var settingsOpened = 0;

  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async =>
      Ok(selected);

  @override
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval value,
  ) async {
    selected = value;
    return const Ok(null);
  }

  var allowed = false;

  @override
  Future<Result<bool, SettingsFailure>> notificationsAllowed() async =>
      Ok(allowed);

  @override
  Future<Result<bool, SettingsFailure>> requestNotifications() async =>
      const Ok(false);

  @override
  Future<Result<void, SettingsFailure>> openNotificationSettings() async {
    settingsOpened++;
    return const Ok(null);
  }
}

Finder _switchOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
  matching: find.byType(BullSwitch),
);

void main() {
  testWidgets('notifications follow background tasks and a refusal', (
    tester,
  ) async {
    final preferences = _Preferences();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => BackgroundPreferencesCubit(
            BackgroundPreferencesUsecase(preferences),
          )..load(),
          child: const PermissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BullSwitch>(_switchOf('Background Tasks')).value,
      true,
    );
    expect(tester.widget<BullSwitch>(_switchOf('Notifications')).value, false);
    expect(find.byType(BullInfoBar), findsNothing);

    await tester.tap(_switchOf('Notifications'));
    await tester.pumpAndSettle();
    expect(
      find.text('Notifications are blocked in system settings.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open system settings'));
    await tester.pumpAndSettle();
    expect(preferences.settingsOpened, 1);

    // Allowed in the system settings: coming back reads it again.
    preferences.allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<BullSwitch>(_switchOf('Notifications')).value, true);
    expect(find.byType(BullInfoBar), findsNothing);

    await tester.tap(_switchOf('Background Tasks'));
    await tester.pumpAndSettle();
    expect(preferences.selected, BackgroundSyncInterval.off);
    expect(find.text('Notifications'), findsNothing);
    expect(find.byType(BullInfoBar), findsNothing);

    // Back on: the interval chosen before is gone, the default returns.
    await tester.tap(_switchOf('Background Tasks'));
    await tester.pumpAndSettle();
    expect(preferences.selected, BackgroundSyncInterval.fallback);
  });
}
