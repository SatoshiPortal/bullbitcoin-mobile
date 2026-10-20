import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_selected_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
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
                restarted = state.extra! as RecoverBullFlowsExtra;
                return const Scaffold(body: Text('New recovery flow'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        final selectedContext = tester.element(find.byType(VaultSelectedPage));
        final decrypt = AppLocalizations.of(
          selectedContext,
        ).recoverbullDecryptVault;

        await tester.tap(find.text(decrypt));
        await tester.pumpAndSettle();

        if (condition != 'ready') {
          expect(newFlows, 1);
          expect(find.byType(PasswordInputPage), findsNothing);
          expect(restarted!.flow, flow);
          expect(restarted!.vault, same(vault));
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
        expect(nested.currentState!.canPop(), isTrue);

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
