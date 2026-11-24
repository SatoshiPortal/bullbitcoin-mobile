import 'dart:async';

import 'package:access/access.dart';
import 'package:access/setup.dart';
import 'package:access/src/locator.dart';
import 'package:access/src/presentation/access_failure_l10n.dart';
import 'package:access/src/presentation/bloc/app_unlock_bloc.dart';
import 'package:access/src/ui/pin_code_unlock_screen.dart';
import 'package:access/src/ui/pin_code_setting_flow.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:mocktail/mocktail.dart';
import 'package:access/src/domain/usecases/check_pin_code_exists_usecase.dart';

import 'support/inventory_fixture.dart';

import 'test_theme.dart';

Widget app(Widget child) => MaterialApp(
  theme: accessTestTheme(Brightness.light),
  localizationsDelegates: const [
    AccessLocalizations.delegate,
    bullUiLocalizationsDelegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: AccessLocalizations.supportedLocales,
  home: child,
);

class _DelayedPinCheck extends Mock implements CheckPinCodeExistsUsecase {}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready() && clock.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue);
}

AppUnlockBloc unlockBloc(WidgetTester tester) =>
    tester.element(find.byType(PinCodeUnlockInputScreen)).read<AppUnlockBloc>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GetIt services;
  late InventoryFixture fixture;
  late AccessFeature feature;
  var backupReads = 0;
  var backedUp = false;
  var defaultUnlocks = 0;

  setUp(() async {
    services = GetIt.asNewInstance();
    fixture = await InventoryFixture.open();
    backupReads = 0;
    backedUp = false;
    defaultUnlocks = 0;
    feature = AccessFeature.mount(
      services: services,
      inventory: fixture.inventory,
      backupVerification: fixture.backup,
      hasVerifiedBackup: () async {
        backupReads++;
        return backedUp;
      },
      onUnlocked: (_) => defaultUnlocks++,
      onBackUp: (_) async => backedUp = true,
    );
  });

  tearDown(() async {
    await services.reset();
    await fixture.close();
    accessLocator = GetIt.instance;
  });

  test('mount contributes distinct root and nested routes without reading', () {
    final root = feature.routes.root.single as GoRoute;
    final settings = feature.routes.settings.single as GoRoute;
    expect((root.name, root.path), ('appUnlock', '/app-unlock'));
    expect((settings.name, settings.path), ('pinCode', 'pin-code'));
    expect(backupReads, 0);
    expect(defaultUnlocks, 0);
  });

  test('PIN status is read from the inventory', () async {
    const access = Access();
    expect((await access.checkPinCodeExists() as Ok).value, isFalse);
    expect(
      await fixture.inventory.setCredential(
        '1234',
        backupVerification: fixture.backup,
      ),
      isA<Ok>(),
    );
    expect((await access.checkPinCodeExists() as Ok).value, isTrue);
  });

  testWidgets('every failure keeps its operation-specific localized message', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Scaffold(body: SizedBox())));
    final context = tester.element(find.byType(Scaffold));
    final loc = AccessLocalizations.of(context);
    for (final (failure, expected) in <(AccessFailure, String)>[
      (const AccessPinCheckFailure(), loc.appUnlockPinCheckError),
      (const AccessUnlockKeychainLockedFailure(), loc.appUnlockPinCheckError),
      (const AccessPinVerifyFailure(), loc.appUnlockPinVerifyError),
      (const AccessPinSaveFailure(), loc.pinCodeSaveError),
      (const AccessPinDeleteFailure(), loc.pinCodeDeleteError),
      (const AccessPinNotSetFailure(), loc.pinCodeNotSetError),
      (
        const AccessPinSettingsKeychainLockedFailure(),
        loc.oopsSomethingWentWrong,
      ),
      (
        const AccessUnlockUnexpectedFailure('private diagnostic'),
        loc.oopsSomethingWentWrong,
      ),
      (
        const AccessPinSettingsUnexpectedFailure('private diagnostic'),
        loc.oopsSomethingWentWrong,
      ),
    ]) {
      expect(failure.toTranslated(context), expected);
    }
  });

  testWidgets('no-PIN gate issues the existing typed success grant', (
    tester,
  ) async {
    final grants = <AppUnlockGrant>[];
    await tester.pumpWidget(
      app(const Access().buildReauthenticationGate(onSuccess: grants.add)),
    );
    await waitFor(tester, () => grants.isNotEmpty);
    expect(grants, hasLength(1));
  });

  testWidgets('a configured PIN requires validation before a grant', (
    tester,
  ) async {
    const pin = '1234';
    await tester.runAsync(() async {
      expect(
        await fixture.inventory.setCredential(
          pin,
          backupVerification: fixture.backup,
        ),
        isA<Ok>(),
      );
    });
    fixture.inventory.lock();
    final grants = <AppUnlockGrant>[];
    final gate = const Access().buildReauthenticationGate(
      onSuccess: grants.add,
    );
    expect(
      // Verify the widget exposes no success callback even to dynamic callers.
      () => (gate as dynamic).onSuccess,
      throwsA(isA<NoSuchMethodError>()),
    );
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(app(gate));
      await waitFor(
        tester,
        () => unlockBloc(tester).state.status == AppUnlockStatus.inProgress,
      );
      expect(grants, isEmpty);

      final loc = AccessLocalizations.of(tester.element(find.byType(Scaffold)));
      for (final digit in pin.split('')) {
        await tester.tap(find.bySemanticsLabel(digit));
        await tester.pumpAndSettle();
      }
      expect(grants, isEmpty);

      await tester.tap(find.text(loc.appUnlockButton));
      await waitFor(tester, () => grants.isNotEmpty);
      expect(grants, hasLength(1));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'disposing the gate while its PIN read is pending issues no grant',
    (tester) async {
      final pending = Completer<void>();
      final check = _DelayedPinCheck();
      when(() => check.execute())
          .thenAnswer((_) => pending.future.then((_) => const Ok(false)));
      await services.unregister<CheckPinCodeExistsUsecase>();
      services.registerFactory<CheckPinCodeExistsUsecase>(() => check);
      final grants = <AppUnlockGrant>[];
      await tester.pumpWidget(
        app(const Access().buildReauthenticationGate(onSuccess: grants.add)),
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete();
      await tester.pumpAndSettle();
      expect(grants, isEmpty);
    },
  );

  for (final scenario in ['wrong', 'cooldown', 'correct']) {
    testWidgets('gate preserves $scenario authorization', (tester) async {
      await tester.runAsync(() async {
        expect(
          await fixture.inventory.setCredential(
            '1234',
            backupVerification: fixture.backup,
          ),
          isA<Ok>(),
        );
        fixture.inventory.lock();
        if (scenario == 'cooldown') {
          for (var index = 0; index < 4; index++) {
            expect(await fixture.inventory.unlock('0000'), isA<Ok>());
          }
        }
      });
      final grants = <AppUnlockGrant>[];
      await tester.pumpWidget(
        app(const Access().buildReauthenticationGate(onSuccess: grants.add)),
      );
      final bloc = unlockBloc(tester);
      await waitFor(
        tester,
        () => bloc.state.status == AppUnlockStatus.inProgress,
      );
      for (final digit in (scenario == 'wrong' ? '0000' : '1234').split('')) {
        bloc.add(AppUnlockPinCodeNumberAdded(int.parse(digit)));
      }
      await tester.pump();
      bloc.add(const AppUnlockSubmitted());
      await tester.pump();
      if (scenario == 'correct') {
        await waitFor(tester, () => grants.isNotEmpty);
      } else if (scenario == 'wrong') {
        await waitFor(tester, () => bloc.state.showError);
      } else {
        expect(bloc.state.timeoutSeconds, greaterThan(0));
      }
      expect(grants, hasLength(scenario == 'correct' ? 1 : 0));
      // Let the real error toast dismiss before removing its overlay.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('typed routes preserve default, override and backup recheck', (
    tester,
  ) async {
    var overrides = 0;
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        ...feature.routes.root,
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('settings')),
          routes: feature.routes.settings,
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: accessTestTheme(Brightness.light),
        localizationsDelegates: const [
          AccessLocalizations.delegate,
          bullUiLocalizationsDelegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AccessLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    AppUnlockRouteData(onSuccess: () => overrides++).go(router);
    await waitFor(tester, () => overrides == 1);
    expect(overrides, 1);
    expect(defaultUnlocks, 0);
    router.go('/settings');
    await tester.pumpAndSettle();
    const AppUnlockRouteData().go(router);
    await waitFor(tester, () => defaultUnlocks == 1);
    expect(defaultUnlocks, 1);
    expect(overrides, 1);
    router.go('/settings');
    await tester.pumpAndSettle();
    final context = tester.element(find.text('settings'));
    final navigation = const PinSettingsRouteData().push(context);
    await waitFor(tester, () => backupReads == 1);
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(tester.element(find.byType(PinCodeSettingFlow)))
          .uri
          .path,
      '/settings/pin-code',
    );
    expect(backupReads, 1);
    final loc = AccessLocalizations.of(
      tester.element(find.byType(PinCodeSettingFlow)),
    );
    await tester.tap(find.text(loc.backupSettingsStartBackup));
    await tester.pumpAndSettle();
    expect(backupReads, 2);
    expect(find.text(loc.backupSettingsStartBackup), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    await navigation;
  });
}
