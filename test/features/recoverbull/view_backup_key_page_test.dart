import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/flow.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/view_vault_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/fetch_vault_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/core/widgets/secret_reveal_gate.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';

class _Vault extends Mock implements EncryptedVault {}

class _Flow extends Fake implements RecoverBullBloc {
  RecoverBullState _state = const RecoverBullState(
    flow: RecoverBullFlow.viewVaultKey,
  );
  final _stream = StreamController<RecoverBullState>.broadcast();
  final events = <RecoverBullEvent>[];

  @override
  RecoverBullState get state => _state;
  @override
  Stream<RecoverBullState> get stream => _stream.stream;
  @override
  void add(RecoverBullEvent event) {
    events.add(event);
    if (event is OnVaultKeyCleared) update(_state.copyWith(vaultKey: null));
  }

  void update(RecoverBullState state) {
    _state = state;
    _stream.add(state);
  }

  @override
  Future<void> close() => _stream.close();
}

class _Unlock extends AppUnlockFacade {
  @override
  Widget buildReauthenticationGate({
    required ValueChanged<AppUnlockGrant> onSuccess,
    bool canPop = false,
  }) {
    final gate =
        super.buildReauthenticationGate(onSuccess: onSuccess, canPop: canPop)
            as PinCodeUnlockScreen;
    return Scaffold(
      body: TextButton(
        onPressed: gate.onSuccess,
        child: const Text('Authenticate fixture'),
      ),
    );
  }
}

void main() {
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
  final privacyCalls = <String>[];
  final clipboardWrites = <String>[];
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ScreenCaptureProtection.instance.enabledByUser = true;
    privacyCalls.clear();
    clipboardWrites.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          privacyCalls.add(call.method);
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  for (final local in [true, false]) {
    testWidgets(
      '${local ? 'local' : 'server'} method requires a file and passes the exact selected backup',
      (tester) async {
        final flow = _Flow();
        addTearDown(flow.close);
        RecoverBullFlowsExtra? routed;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider<RecoverBullBloc>.value(
                value: flow,
                child: const RecoverBullFlowNavigator(
                  viewKeyMethodSelection: true,
                ),
              ),
            ),
            GoRoute(
              path: RecoverBullRoute.recoverbullFlows.path,
              name: RecoverBullRoute.recoverbullFlows.name,
              builder: (_, state) {
                routed = state.extra as RecoverBullFlowsExtra;
                return const Scaffold(body: Text('Key flow destination'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        // No locator registration for Tor, permissions or secrets: the chooser
        // must be mountable without touching any of them.
        expect(flow.events, isEmpty);
        await tester.tap(
          find.text(local ? 'From backup file' : 'From recovery server'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(local ? 'Unlock & derive key' : 'Continue'),
          findsNothing,
        );
        await tester.tap(find.text('Choose backup file'));
        await tester.pump();
        expect(flow.events.whereType<OnVaultSelection>(), hasLength(1));
        final vault = _Vault();
        when(() => vault.filename).thenReturn('selected-backup.json');
        flow.update(flow.state.copyWith(vault: vault));
        await tester.pumpAndSettle();
        final proceed = find.text(local ? 'Unlock & derive key' : 'Continue');
        await tester.ensureVisible(proceed);
        await tester.tap(proceed);
        await tester.pumpAndSettle();
        expect(routed!.vault, same(vault));
        expect(routed!.deriveKeyLocally, local);
        expect(routed!.flow, RecoverBullFlow.viewVaultKey);
        expect(flow.events.whereType<OnTorInitialization>(), isEmpty);
        expect(flow.events.whereType<OnVaultKeyDerivation>(), isEmpty);
      },
    );
  }

  testWidgets('invalid file feedback keeps the user in file selection', (
    tester,
  ) async {
    final flow = _Flow();
    addTearDown(flow.close);
    await tester.pumpWidget(
      app(
        BlocProvider<RecoverBullBloc>.value(
          value: flow,
          child: const RecoverBullFlowNavigator(viewKeyMethodSelection: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('From backup file'));
    flow.update(
      flow.state.copyWith(failure: const InvalidVaultFileFormatFailure()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose backup file'), findsOneWidget);
    expect(find.text('Unlock & derive key'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture request and reauthentication precede private work', (
    tester,
  ) async {
    final pending = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          privacyCalls.add(call.method);
          return call.method == 'screenshotOff'
              ? pending.future
              : Future.value(true);
        });
    var privateWork = 0;
    await tester.pumpWidget(
      app(
        SecretRevealGate(
          appUnlock: _Unlock(),
          builder: (_) {
            privateWork++;
            return const Scaffold(body: Text('Private work started'));
          },
        ),
      ),
    );
    await tester.pump();
    expect(privateWork, 0);
    expect(find.text('Authenticate fixture'), findsNothing);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(privateWork, 0);
    await tester.tap(find.text('Authenticate fixture'));
    await tester.pumpAndSettle();
    expect(privateWork, 1);
    expect(privacyCalls, contains('screenshotOff'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(privacyCalls.last, 'screenshotOn');
  });

  testWidgets('cancelling authentication never builds the private child', (
    tester,
  ) async {
    var privateWork = 0;
    await tester.pumpWidget(
      app(
        SecretRevealGate(
          appUnlock: _Unlock(),
          builder: (_) {
            privateWork++;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(privateWork, 0);
    expect(privacyCalls.last, 'screenshotOn');
  });

  testWidgets('disabled capture protection cannot start key derivation', (
    tester,
  ) async {
    ScreenCaptureProtection.instance.enabledByUser = false;
    addTearDown(() => ScreenCaptureProtection.instance.enabledByUser = true);
    var reads = 0;
    await tester.pumpWidget(
      app(
        SecretRevealGate(
          appUnlock: _Unlock(),
          builder: (_) {
            reads++;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.byType(PrivacyUnavailableNotice), findsOneWidget);
    expect(find.text('Authenticate fixture'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'backgrounding discards the private child and requires authentication again',
    (tester) async {
      await tester.pumpWidget(
        app(
          SecretRevealGate(
            appUnlock: _Unlock(),
            builder: (_) => const Text('Private child'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Authenticate fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Private child'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Private child'), findsNothing);
      expect(find.text('Authenticate fixture'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'backgrounding a visible value modal also dismisses the reveal page',
    (tester) async {
      const key =
          '1111111111111111111111111111111111111111111111111111111111111111';
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const ViewVaultKeyPage(vaultKey: key),
                  ),
                ),
                child: const Text('Reveal fixture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reveal fixture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(ViewVaultKeyPage), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Reveal fixture'), findsOneWidget);
    },
  );

  testWidgets(
    'key reveal keeps actual pixels, copy and secret-free semantics',
    (tester) async {
      const key =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(app(const ViewVaultKeyPage(vaultKey: key)));
        await tester.pumpAndSettle();
        expect(find.text(key), findsNothing);
        expect(privacyCalls, contains('screenshotOff'));
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();
        final grouped = List.filled(16, '1111').join(' ');
        expect(find.text(grouped), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(AlertDialog)).toStringDeep(),
          isNot(contains(grouped)),
        );
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(clipboardWrites, [key]);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(privacyCalls.last, 'screenshotOn');
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final reveal in [true, false]) {
    testWidgets(
      'verified server key ${reveal ? 'reveals and returns' : 'can be cancelled'} without popping the caller',
      (tester) async {
        final flow = _Flow();
        addTearDown(flow.close);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const Scaffold(body: Text('Selected backup file')),
            ),
            GoRoute(
              path: '/view',
              builder: (_, _) => BlocProvider<RecoverBullBloc>.value(
                value: flow,
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const FetchVaultKeyPage(
                      input: 'fixture-pin',
                      inputType: InputType.pin,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        router.push('/view');
        await tester.pumpAndSettle();
        flow.update(flow.state.copyWith(vaultKey: List.filled(64, '1').join()));
        await tester.pumpAndSettle();
        expect(find.text('Security Warning'), findsOneWidget);
        expect(flow.state.vaultKey, isNull);
        await tester.tap(find.text(reveal ? 'Continue' : 'Cancel'));
        await tester.pumpAndSettle();
        if (reveal) {
          expect(find.byType(ViewVaultKeyPage), findsOneWidget);
          // Imperative pushes do not update the browser URL by default.
          expect(router.state.uri.path, '/view');
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        expect(find.text('Selected backup file'), findsOneWidget);
        expect(router.state.uri.path, '/');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
