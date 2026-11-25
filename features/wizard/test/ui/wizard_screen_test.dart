import 'dart:ui' show Tristate;

import 'package:background_tasks/background_tasks.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/domain/repository/wizard_repository.dart';
import 'package:wizard/src/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:wizard/src/domain/usecase/notification_permission_usecase.dart';
import 'package:wizard/src/domain/usecase/read_background_tasks_usecase.dart';
import 'package:wizard/src/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:wizard/src/presentation/bloc/wizard_bloc.dart';
import 'package:wizard/src/ui/screens/wizard_screen.dart';
import 'package:wizard/src/ui/widgets/customize_step.dart';
import 'package:wizard/src/ui/widgets/mission_consent_row.dart';
import 'package:wizard/generated/l10n/wizard_localizations.dart';
import 'package:bull_exchange/bull_exchange.dart'
    show ExchangeLocalizations, WizardExchangeOption;
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/settings.dart' show SettingsLocalizations;

import 'test_branding.dart';

class _FakeWizardRepository implements WizardRepository {
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

class _Intervals implements BackgroundSyncIntervalRepository {
  @override
  Future<BackgroundSyncInterval> read() async => BackgroundSyncInterval.hour1;

  @override
  Future<Result<void, BackgroundTasksFailure>> write(
    BackgroundSyncInterval interval,
  ) async => const Ok(null);
}

/// The system refuses every request.
class _Permissions implements NotificationPermissionPort {
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

WizardBloc _bloc(
  WizardRepository repository,
  NotificationPermissionPort port,
) => WizardBloc(
  savePending: SavePendingWizardChoicesUsecase(repository: repository),
  markComplete: MarkWizardCompleteUsecase(repository: repository),
  readBackgroundTasks: ReadBackgroundTasksUsecase(intervals: _Intervals()),
  notificationPermission: NotificationPermissionUsecase(
    permissions: NotificationPermissionsFacade(gateway: port),
  ),
)..add(const WizardEvent.started());

Future<void> _pump(WidgetTester tester, Widget home) async {
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

void main() {
  for (final allowed in [false, true]) {
    testWidgets(
      'the exchange switch follows the platform permission $allowed',
      (tester) async {
        final repository = _FakeWizardRepository();
        await _pump(
          tester,
          BlocProvider(
            create: (_) => _bloc(repository, _Permissions()),
            child: WizardScreen(
              branding: testBranding,
              exchangeAllowed: allowed,
              backgroundTasksAvailable: false,
            ),
          ),
        );
        final pages =
            tester.widget<PageView>(find.byType(PageView)).childrenDelegate
                as SliverChildListDelegate;
        expect(pages.children, hasLength(4));

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        final switches = find.descendant(
          of: find.byType(CustomizeStep),
          matching: find.byType(BullSwitch),
        );
        // Dark mode, then the exchange where the platform allows it.
        expect(switches, findsNWidgets(allowed ? 2 : 1));
        expect(
          find.byType(WizardExchangeOption),
          allowed ? findsOneWidget : findsNothing,
        );
        if (allowed) {
          await tester.tap(switches.at(1));
          await tester.pump();
        }

        // Skip on the settings page confirms the exchange choice shown there,
        // then sends the user to the mandatory mission question.
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.byType(MissionConsentRow), findsOneWidget);
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        final saved = repository.pending;
        expect(saved, isNotNull);
        expect(saved?.reportingConsent, isFalse);
        expect(saved?.touched.contains(WizardField.exchangeAccess), allowed);
        if (allowed) expect(saved?.exchangeAccess, isFalse);
        // Lets the mission-required snackbar time out.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets('background tasks lead to notifications on the settings page', (
    tester,
  ) async {
    final repository = _FakeWizardRepository();
    final permissions = _Permissions();
    await _pump(
      tester,
      BlocProvider(
        create: (_) => _bloc(repository, permissions),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: true,
          backgroundTasksAvailable: true,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final order = [
      'Language',
      'Default currency',
      'Dark Mode',
      'BULL Exchange',
      'Background Tasks',
      'Notifications',
    ];
    final tops = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i] > tops[i - 1], isTrue, reason: order[i]);
    }

    // The system refuses: the row says so instead of its description.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Notifications'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(BullSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(permissions.requests, 1);
    expect(find.text('Blocked in system settings'), findsOneWidget);

    // Notifications only make sense while background tasks run.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Background Tasks'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(BullSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    final saved = repository.pending;
    expect(saved?.touched.contains(WizardField.backgroundTasks), isTrue);
    expect(saved?.backgroundTasks, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final consent in <bool?>[null, true, false]) {
    testWidgets('consent selection is announced once: $consent', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var yesTaps = 0;
        var noTaps = 0;
        await _pump(
          tester,
          Scaffold(
            body: MissionConsentRow(
              consent: consent,
              onYes: () => yesTaps++,
              onNo: () => noTaps++,
              yesFirst: true,
            ),
          ),
        );
        for (final answer in [true, false]) {
          final label = answer ? 'Yes' : 'No';
          final nodes = find.semantics.byPredicate(
            (node) => node.label == label && node.flagsCollection.isButton,
          );
          expect(nodes, findsOne);
          final node = nodes.evaluate().single;
          expect(
            node.flagsCollection.isSelected,
            consent == answer ? Tristate.isTrue : Tristate.isFalse,
          );
        }
        await tester.tap(find.text('Yes'));
        await tester.tap(find.text('No'));
        expect(yesTaps, 1);
        expect(noTaps, 1);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final yesFirst in [true, false]) {
    testWidgets('the consent row puts Yes on the left: $yesFirst', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: MissionConsentRow(
            consent: null,
            onYes: () {},
            onNo: () {},
            yesFirst: yesFirst,
          ),
        ),
      );
      final yesX = tester.getCenter(find.text('Yes')).dx;
      final noX = tester.getCenter(find.text('No')).dx;
      expect(yesX < noX, yesFirst);
    });
  }
}
