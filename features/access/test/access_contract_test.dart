import 'dart:async';
import 'dart:io';

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
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

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

class _DelayedStorage extends FakeSecureStoragePlatform {
  Completer<void>? readGate;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (key == 'securityKey') await readGate?.future;
    return super.read(key: key, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GetIt services;
  late _DelayedStorage storage;
  late AccessFeature feature;
  var backupReads = 0;
  var backedUp = false;
  var defaultUnlocks = 0;

  setUp(() {
    services = GetIt.asNewInstance();
    storage = _DelayedStorage()..install();
    backupReads = 0;
    backedUp = false;
    defaultUnlocks = 0;
    // Mount before registering Secrets: factories and host callbacks stay lazy.
    feature = AccessFeature.mount(
      services: services,
      hasVerifiedBackup: () async {
        backupReads++;
        return backedUp;
      },
      onUnlocked: (_) => defaultUnlocks++,
      onBackUp: (_) async => backedUp = true,
    );
    services.registerSingleton<Secrets>(
      Secrets(scratchDirectory: () async => Directory.systemTemp.path),
    );
  });

  tearDown(() async {
    await services.reset();
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

  test('PIN status preserves absent, present and locked results', () async {
    const access = Access();
    expect(
      await access.checkPinCodeExists(),
      isA<Ok<bool, AccessFailure>>().having((r) => r.value, 'absent', false),
    );
    storage.entries['securityKey'] = '1234';
    expect(
      await access.checkPinCodeExists(),
      isA<Ok<bool, AccessFailure>>().having((r) => r.value, 'present', true),
    );
    storage.locked = true;
    expect(
      await access.checkPinCodeExists(),
      isA<Err<bool, AccessFailure>>().having(
        (r) => r.failure,
        'locked',
        isA<AccessUnlockKeychainLockedFailure>(),
      ),
    );
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
    await tester.pumpAndSettle();
    expect(grants, hasLength(1));
  });

  testWidgets('a configured PIN requires validation before a grant', (
    tester,
  ) async {
    const pin = '1234';
    storage.entries['securityKey'] = pin;
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
      await tester.pumpAndSettle();
      expect(grants, isEmpty);

      final loc = AccessLocalizations.of(tester.element(find.byType(Scaffold)));
      for (final digit in pin.split('')) {
        await tester.tap(find.bySemanticsLabel(digit));
        await tester.pumpAndSettle();
      }
      expect(grants, isEmpty);

      await tester.tap(find.text(loc.appUnlockButton));
      await tester.pumpAndSettle();
      expect(grants, hasLength(1));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'disposing the gate while its PIN read is pending issues no grant',
    (tester) async {
      final pending = Completer<void>();
      storage.readGate = pending;
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

  for (final scenario in [
    'locked',
    'wrong',
    'cooldown',
    'write failure',
    'correct',
  ]) {
    testWidgets('gate preserves $scenario authorization', (tester) async {
      storage.entries['securityKey'] = '1234';
      if (scenario == 'locked') storage.locked = true;
      if (scenario == 'write failure') storage.writesFail = true;
      if (scenario == 'cooldown') {
        storage.entries['failedUnlockAttemptsKey'] = '4';
        storage.entries['unlockLockedUntilKey'] = DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch
            .toString();
      }
      final grants = <AppUnlockGrant>[];
      await tester.pumpWidget(
        app(const Access().buildReauthenticationGate(onSuccess: grants.add)),
      );
      await tester.pump();
      final bloc = tester
          .element(find.byType(PinCodeUnlockInputScreen))
          .read<AppUnlockBloc>();
      for (final digit in (scenario == 'wrong' ? '0000' : '1234').split('')) {
        bloc.add(AppUnlockPinCodeNumberAdded(int.parse(digit)));
      }
      await tester.pump();
      bloc.add(const AppUnlockSubmitted());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
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
    await tester.pumpAndSettle();
    expect(overrides, 1);
    expect(defaultUnlocks, 0);
    router.go('/settings');
    await tester.pumpAndSettle();
    const AppUnlockRouteData().go(router);
    await tester.pumpAndSettle();
    expect(defaultUnlocks, 1);
    expect(overrides, 1);
    router.go('/settings');
    await tester.pumpAndSettle();
    final context = tester.element(find.text('settings'));
    final navigation = const PinSettingsRouteData().push(context);
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
