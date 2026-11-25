import 'package:background_tasks/background_tasks.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/domain/repository/wizard_repository.dart';
import 'package:wizard/src/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:wizard/src/domain/usecase/notification_permission_usecase.dart';
import 'package:wizard/src/domain/usecase/read_background_tasks_usecase.dart';
import 'package:wizard/src/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:wizard/src/presentation/bloc/wizard_bloc.dart';
import 'package:wizard/generated/l10n/wizard_localizations.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/settings.dart' show SettingsLocalizations;

class FakeWizardRepository implements WizardRepository {
  WizardChoices? pending;

  @override
  Future<bool> isComplete() async => false;

  @override
  Future<void> markComplete() async {}

  @override
  Future<void> savePending(WizardChoices choices) async => pending = choices;

  @override
  Future<WizardChoices?> readPending() async => pending;

  @override
  Future<void> clearPending() async => pending = null;
}

class FakeIntervals implements BackgroundSyncIntervalRepository {
  @override
  Future<BackgroundSyncInterval> read() async => BackgroundSyncInterval.hour1;

  @override
  Future<Result<void, BackgroundTasksFailure>> write(
    BackgroundSyncInterval interval,
  ) async => const Ok(null);
}

/// The system refuses every request.
class FakePermissions implements NotificationPermissionPort {
  bool allowed = false;
  int requests = 0;

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(allowed);

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    requests++;
    return Ok(allowed);
  }

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
}

WizardBloc buildWizardBloc(
  WizardRepository repository,
  NotificationPermissionPort port,
) => WizardBloc(
  savePending: SavePendingWizardChoicesUsecase(repository: repository),
  markComplete: MarkWizardCompleteUsecase(repository: repository),
  readBackgroundTasks: ReadBackgroundTasksUsecase(intervals: FakeIntervals()),
  notificationPermission: NotificationPermissionUsecase(
    permissions: NotificationPermissionsFacade(gateway: port),
  ),
)..add(const WizardEvent.started());

Future<void> pumpWizard(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Device.screen = const Size(400, 800);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: [
        ...WizardLocalizations.localizationsDelegates,
        ExchangeLocalizations.delegate,
        SettingsLocalizations.delegate,
      ],
      supportedLocales: WizardLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}
