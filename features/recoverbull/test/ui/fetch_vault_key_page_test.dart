import 'dart:async';

import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/ui/screens/fetch_vault_key_page.dart';
import 'package:bull_recoverbull/src/ui/screens/password_input_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_recoverbull/src/ui/support.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/ui/screens/view_vault_key_page.dart';
import 'package:bull_recoverbull/src/ui/screens/test_completed_page.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_provider_selection_page.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bull_ui/testing.dart';

class _MutableRecoverBullBloc extends Fake implements RecoverBullBloc {
  RecoverBullState _state;
  final StreamController<RecoverBullState> _states =
      StreamController<RecoverBullState>.broadcast();
  final List<RecoverBullEvent> events = [];
  final bool pendingProviderSave;

  _MutableRecoverBullBloc(this._state, {this.pendingProviderSave = false});

  @override
  RecoverBullState get state => _state;

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  @override
  void add(RecoverBullEvent event) => events.add(event);

  @override
  bool get hasPendingProviderSave => pendingProviderSave;

  void emitState(RecoverBullState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> close() => _states.close();
}

void main() {
  testWidgets('centers the fetching progress screen in the available body', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = _MutableRecoverBullBloc(
      const RecoverBullState(
        flow: RecoverBullFlow.viewVaultKey,
        isLoading: true,
      ),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const FetchVaultKeyPage(
            input: 'test input',
            inputType: InputType.password,
          ),
        ),
      ),
    );
    await tester.pump();

    final progress = tester.getRect(find.byType(ProgressScreen));
    expect(progress.center.dx, closeTo(200, 0.5));
    expect(progress.center.dy, closeTo(428, 0.5));
  });

  testWidgets('does not return to an empty fetch page from Tor settings', (
    tester,
  ) async {
    final bloc = _MutableRecoverBullBloc(
      const RecoverBullState(flow: RecoverBullFlow.recoverVault),
    );
    addTearDown(bloc.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Previous page')),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('Settings')),
          routes: [
            GoRoute(
              path: 'app-settings',
              builder: (_, _) => const Scaffold(body: Text('App settings')),
              routes: [
                GoRoute(
                  path: 'tor-settings',
                  name: 'torSettings',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Tor settings destination')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    final previousContext = tester.element(find.text('Previous page'));
    Navigator.of(previousContext).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const FetchVaultKeyPage(
            input: 'test input',
            inputType: InputType.password,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bloc.emitState(
      const RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        failure: ExternalTorProxyUnavailableFailure(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tor settings destination'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Previous page'), findsOneWidget);
  });

  testWidgets('does not push duplicate vault key pages for repeated results', (
    tester,
  ) async {
    final bloc = _MutableRecoverBullBloc(
      const RecoverBullState(flow: RecoverBullFlow.viewVaultKey),
    );
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/fetch',
      routes: [
        GoRoute(
          path: '/fetch',
          builder: (_, _) => BlocProvider<RecoverBullBloc>.value(
            value: bloc,
            child: const FetchVaultKeyPage(
              input: 'test input',
              inputType: InputType.password,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump();

    bloc.emitState(
      const RecoverBullState(
        flow: RecoverBullFlow.viewVaultKey,
        vaultKey: 'first-key',
        decryptedVault: DecryptedVault(),
      ),
    );
    await tester.pumpAndSettle();
    bloc.emitState(
      const RecoverBullState(
        flow: RecoverBullFlow.viewVaultKey,
        vaultKey: 'second-key',
        decryptedVault: DecryptedVault(mnemonic: ['changed']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ViewVaultKeyPage), findsOneWidget);
  });

  testWidgets(
    'test completion uses isFlowFinished after sensitive values clear',
    (tester) async {
      final bloc = _MutableRecoverBullBloc(
        const RecoverBullState(flow: RecoverBullFlow.testVault),
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: BlocProvider<RecoverBullBloc>.value(
            value: bloc,
            child: const FetchVaultKeyPage(
              input: 'redacted',
              inputType: InputType.vaultKey,
            ),
          ),
        ),
      );
      await tester.pump();

      bloc.emitState(
        const RecoverBullState(
          flow: RecoverBullFlow.testVault,
          isFlowFinished: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TestCompletedPage), findsOneWidget);
    },
  );

  testWidgets(
    'test flow reaches completion after the intermediate decrypted-vault '
    'emission the bloc really produces',
    (tester) async {
      final bloc = _MutableRecoverBullBloc(
        const RecoverBullState(flow: RecoverBullFlow.testVault),
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: BlocProvider<RecoverBullBloc>.value(
            value: bloc,
            child: const FetchVaultKeyPage(
              input: 'redacted',
              inputType: InputType.vaultKey,
            ),
          ),
        ),
      );
      await tester.pump();

      bloc.emitState(
        const RecoverBullState(
          flow: RecoverBullFlow.testVault,
          vaultKey: 'fetched-key',
        ),
      );
      await tester.pumpAndSettle();
      bloc.emitState(
        const RecoverBullState(
          flow: RecoverBullFlow.testVault,
          vaultKey: 'fetched-key',
          decryptedVault: DecryptedVault(),
        ),
      );
      await tester.pumpAndSettle();
      bloc.emitState(
        const RecoverBullState(
          flow: RecoverBullFlow.testVault,
          isFlowFinished: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TestCompletedPage), findsOneWidget);
    },
  );

  testWidgets('pending provider save keeps the user on provider selection', (
    tester,
  ) async {
    final bloc = _MutableRecoverBullBloc(
      const RecoverBullState(flow: RecoverBullFlow.secureVault),
      pendingProviderSave: true,
    );
    addTearDown(bloc.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [testBullTheme]),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('previous')),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const VaultProviderSelectionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(find.text('previous'), findsNothing);
    expect(find.text('Select Vault Provider'), findsOneWidget);
    BullSnackBar.dismiss();
    await tester.pumpAndSettle();
  });
}
