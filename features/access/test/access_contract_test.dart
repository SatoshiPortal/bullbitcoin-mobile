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
import 'package:access/src/domain/usecases/delete_pin_code_usecase.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';

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

class _DelayedPinDelete extends Mock implements DeletePinCodeUsecase {}

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
  var defaultUnlocks = 0;

  setUp(() async {
    services = GetIt.asNewInstance();
    fixture = await InventoryFixture.open();
    defaultUnlocks = 0;
    feature = AccessFeature.mount(
      services: services,
      inventory: fixture.inventory,
      onUnlocked: (_) => defaultUnlocks++,
      onBackUp: (_) async => fixture.backup.verified = true,
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
    expect(fixture.backup.reads, 0);
    expect(defaultUnlocks, 0);
  });

  test('PIN status is read from the inventory', () async {
    const access = Access();
    expect((await access.checkPinCodeExists() as Ok).value, isFalse);
    expect(await fixture.inventory.setCredential('1234'), isA<Ok>());
    expect((await access.checkPinCodeExists() as Ok).value, isTrue);
  });

  test('lock revokes admission before returning its future', () async {
    expect(await fixture.inventory.setCredential('1234'), isA<Ok>());

    final locking = const Access().lock();

    expect(fixture.inventory.isLocked, isTrue);
    await locking;
  });

  test(
    'a committed PIN deletion does not emit after the session locks',
    () async {
      expect(await fixture.inventory.setCredential('1234'), isA<Ok>());
      final committed = Completer<void>();
      final release = Completer<void>();
      final delete = _DelayedPinDelete();
      when(() => delete.execute()).thenAnswer((_) async {
        final result = await fixture.inventory.removeCredential();
        expect(result, isA<Ok>());
        committed.complete();
        await release.future;
        return const Ok(null);
      });
      await services.unregister<DeletePinCodeUsecase>();
      services.registerFactory<DeletePinCodeUsecase>(() => delete);
      final bloc = services<PinCodeSettingBloc>();
      addTearDown(bloc.close);
      await bloc.stream.firstWhere(
        (state) => state.status == PinCodeSettingStatus.unlock,
      );
      final emitted = <PinCodeSettingStatus>[];
      final subscription = bloc.stream.listen(
        (state) => emitted.add(state.status),
      );
      bloc.add(const PinCodeDelete());
      await committed.future.timeout(const Duration(seconds: 5));
      expect((await fixture.inventory.isProtected() as Ok).value, isFalse);
      await const Access().lock();
      release.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emitted, isNot(contains(PinCodeSettingStatus.deleted)));
      await subscription.cancel();
    },
  );

  test('an unprotected session stays locked until foreground resume', () async {
    const access = Access();
    access.onLifecycle(AppLifecycleState.paused);
    await access.lock();
    expect(fixture.inventory.isLocked, isTrue);

    final resumed = access.locked.firstWhere((locked) => !locked);
    access.onLifecycle(AppLifecycleState.resumed);
    await resumed.timeout(const Duration(seconds: 5));
    expect(fixture.inventory.isLocked, isFalse);
  });

  test(
    'a later foreground request survives a paused in-flight resume',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final write = fixture.inventory.registerWallet(
        localWallet(),
        prepareProperties: (_) async {
          entered.complete();
          await release.future;
          return const Ok(null);
        },
      );
      await entered.future.timeout(const Duration(seconds: 5));
      const access = Access();
      access.onLifecycle(AppLifecycleState.paused);
      final locking = access.lock();
      final reopened = access.locked.firstWhere((locked) => !locked);
      access.onLifecycle(AppLifecycleState.resumed);
      access.onLifecycle(AppLifecycleState.paused);
      expect(fixture.inventory.isLocked, isTrue);
      access.onLifecycle(AppLifecycleState.resumed);
      release.complete();
      await locking;
      expect(await write, isA<Err>());
      await reopened.timeout(const Duration(seconds: 5));
      expect(fixture.inventory.isLocked, isFalse);
    },
  );

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
      expect(await fixture.inventory.setCredential(pin), isA<Ok>());
      await fixture.inventory.lock();
    });
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
        expect(await fixture.inventory.setCredential('1234'), isA<Ok>());
        await fixture.inventory.lock();
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
    await tester.runAsync(() async {
      expect(await fixture.inventory.registerWallet(localWallet()), isA<Ok>());
    });
    fixture.backup
      ..verified = false
      ..reads = 0;
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
    await waitFor(tester, () => fixture.backup.reads == 1);
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(tester.element(find.byType(PinCodeSettingFlow)))
          .uri
          .path,
      '/settings/pin-code',
    );
    expect(fixture.backup.reads, 1);
    final loc = AccessLocalizations.of(
      tester.element(find.byType(PinCodeSettingFlow)),
    );
    await tester.tap(find.text(loc.backupSettingsStartBackup));
    await tester.pumpAndSettle();
    expect(fixture.backup.reads, 2);
    expect(find.text(loc.backupSettingsStartBackup), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    await navigation;
  });
}
