import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import '../support/ui_labels.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/recoverbull_router.dart';
import 'package:bull_recoverbull/src/ui/screens/password_input_page.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_selected_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Vault extends Fake implements EncryptedVault {
  @override
  String get id => 'test-vault';

  @override
  DateTime get createdAt => DateTime.utc(2026, 10, 14);
}

class _RecoverBullBloc extends Fake implements RecoverBullBloc {
  @override
  final RecoverBullState state;
  final events = <RecoverBullEvent>[];

  _RecoverBullBloc(this.state);

  @override
  Stream<RecoverBullState> get stream => const Stream.empty();

  @override
  void add(RecoverBullEvent event) => events.add(event);
}

void main() {
  for (final (flow, condition) in [
    (RecoverBullFlow.recoverVault, 'ready'),
    (RecoverBullFlow.testVault, 'ready'),
    (RecoverBullFlow.recoverVault, 'offline'),
    (RecoverBullFlow.recoverVault, 'tor unavailable'),
    (RecoverBullFlow.recoverVault, 'different flow'),
    (RecoverBullFlow.recoverVault, 'different vault'),
  ]) {
    testWidgets(
      'decrypt ${flow.name} with $condition preserves the appropriate flow',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final vault = _Vault();
        final bloc = _RecoverBullBloc(
          RecoverBullState(
            flow: condition == 'different flow'
                ? RecoverBullFlow.testVault
                : flow,
            vault: condition == 'different vault' ? _Vault() : vault,
            torConnection: condition == 'tor unavailable'
                ? const TorStopped(TorSource.embedded)
                : TorReady(
                    TorRoute(
                      source: TorSource.embedded,
                      endpoint: TorProxyEndpoint(
                        host: '127.0.0.1',
                        port: 41001,
                      ),
                      evidence: TorReadinessEvidence.embeddedBootstrap,
                      transport: TorTransport.direct,
                    ),
                  ),
            vaultProvider: VaultProvider.customLocation,
            keyServerStatus: condition == 'offline'
                ? KeyServerStatus.offline
                : KeyServerStatus.online,
          ),
        );
        final nested = GlobalKey<NavigatorState>();
        var newFlows = 0;
        RecoverBullFlowsExtra? restarted;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider<RecoverBullBloc>.value(
                value: bloc,
                child: NavigatorPopHandler<Object?>(
                  onPopWithResult: (_) => nested.currentState?.maybePop(),
                  child: Navigator(
                    key: nested,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => VaultSelectedPage(
                        provider: VaultProvider.customLocation,
                        vault: vault,
                        flow: flow,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: RecoverBullRoute.recoverbullFlows.path,
              name: RecoverBullRoute.recoverbullFlows.name,
              builder: (_, state) {
                newFlows++;
                final extra = state.extra;
                if (extra is! RecoverBullFlowsExtra) {
                  throw StateError('Missing flow');
                }
                restarted = extra;
                return const Scaffold(body: Text('New recovery flow'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return withTestUiLabels(context, child);
            },
            routerConfig: router,
            theme: ThemeData(extensions: const [testBullTheme]),
            localizationsDelegates:
                RecoverBullLocalizations.localizationsDelegates,
            supportedLocales: RecoverBullLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        final selectedContext = tester.element(find.byType(VaultSelectedPage));
        final decrypt = RecoverBullLocalizations.of(
          selectedContext,
        ).recoverbullDecryptVault;

        await tester.tap(find.text(decrypt));
        await tester.pumpAndSettle();

        if (condition != 'ready') {
          expect(newFlows, 1);
          expect(find.byType(PasswordInputPage), findsNothing);
          final restartedFlow = restarted;
          if (restartedFlow == null) fail('Expected a restarted flow');
          expect(restartedFlow.flow, flow);
          expect(restartedFlow.vault, same(vault));
          router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(VaultSelectedPage), findsOneWidget);
          expect(bloc.events, isEmpty);
          return;
        }

        expect(newFlows, 0);
        expect(find.byType(PasswordInputPage), findsOneWidget);
        final pinContext = tester.element(find.byType(PasswordInputPage));
        expect(pinContext.read<RecoverBullBloc>(), same(bloc));
        expect(bloc.state.vault, same(vault));
        expect(bloc.events, isEmpty);
        final nestedState = nested.currentState;
        if (nestedState == null) fail('Missing nested navigator');
        expect(nestedState.canPop(), isTrue);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.byType(PasswordInputPage), findsNothing);
        expect(find.byType(VaultSelectedPage), findsOneWidget);
        expect(newFlows, 0);

        await tester.tap(find.text(decrypt));
        await tester.pumpAndSettle();
        expect(find.byType(PasswordInputPage), findsOneWidget);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(PasswordInputPage), findsNothing);
        expect(find.byType(VaultSelectedPage), findsOneWidget);
        expect(newFlows, 0);
        expect(bloc.state.vault, same(vault));
      },
    );
  }
}
