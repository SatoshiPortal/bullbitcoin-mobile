import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import '../support/ui_labels.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:bull_recoverbull/src/ui/widgets/provider_cart.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/ui/screens/fetch_vault_key_page.dart';
import 'package:bull_recoverbull/src/ui/screens/password_input_page.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_provider_selection_page.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_selected_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vault extends Fake implements EncryptedVault {
  @override
  String get id => 'retry-test-vault';

  @override
  DateTime get createdAt => DateTime.utc(2026, 10, 14);
}

class _Bloc extends Fake implements RecoverBullBloc {
  final _states = StreamController<RecoverBullState>.broadcast();
  final EncryptedVault vault;
  final events = <RecoverBullEvent>[];

  @override
  RecoverBullState state;

  _Bloc(RecoverBullFlow flow, this.vault)
    : state = RecoverBullState(
        flow: flow,
        keyServerStatus: KeyServerStatus.online,
        torConnection: TorReady(
          TorRoute(
            source: TorSource.embedded,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: TorTransport.direct,
          ),
        ),
      );

  @override
  bool get hasPendingProviderSave => false;

  @override
  bool get isClosed => _states.isClosed;

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  void publish(RecoverBullState next) {
    state = next;
    _states.add(next);
  }

  @override
  void add(RecoverBullEvent event) {
    events.add(event);
    switch (event) {
      case OnVaultProviderSelection(:final provider):
        publish(state.copyWith(vaultProvider: provider, vault: vault));
      case OnClearError():
        publish(state.copyWith(failure: null));
      default:
        break;
    }
  }

  Future<void> disposeStream() => _states.close();
}

class _PushObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  for (final flow in [
    RecoverBullFlow.recoverVault,
    RecoverBullFlow.testVault,
  ]) {
    for (final provider in [
      VaultProvider.customLocation,
      VaultProvider.googleDrive,
    ]) {
      testWidgets(
        '${flow.name} ${provider.name} returns to the same PIN form after invalid credentials',
        (tester) async {
          tester.view.physicalSize = const Size(430, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bloc = _Bloc(flow, _Vault());
          addTearDown(bloc.disposeStream);
          final observer = _PushObserver();
          await tester.pumpWidget(
            BlocProvider<RecoverBullBloc>.value(
              value: bloc,
              child: MaterialApp(
                builder: (context, child) {
                  if (child == null) return const SizedBox.shrink();
                  return withTestUiLabels(context, child);
                },
                theme: ThemeData(extensions: const [testBullTheme]),
                navigatorObservers: [observer],
                localizationsDelegates:
                    RecoverBullLocalizations.localizationsDelegates,
                supportedLocales: RecoverBullLocalizations.supportedLocales,
                home: const VaultProviderSelectionPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final loc = RecoverBullLocalizations.of(
            tester.element(find.byType(VaultProviderSelectionPage)),
          );
          await tester.tap(
            find.byWidgetPredicate(
              (widget) => widget is ProviderCard && widget.provider == provider,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(VaultSelectedPage), findsOneWidget);
          await tester.tap(find.text(loc.recoverbullDecryptVault));
          await tester.pumpAndSettle();
          expect(find.byType(PasswordInputPage), findsOneWidget);
          final originalPasswordState = tester.state(
            find.byType(PasswordInputPage),
          );

          for (final digit in '975318'.split('')) {
            await tester.tap(find.text(digit));
            await tester.pump();
          }
          await tester.tap(find.text(loc.recoverbullContinue));
          await tester.pumpAndSettle();
          expect(find.byType(FetchVaultKeyPage), findsOneWidget);
          expect(
            bloc.events.whereType<OnVaultPasswordSet>().single.password,
            '975318',
          );
          final pushesBeforeFailure = observer.pushes;
          expect(pushesBeforeFailure, 4);

          bloc.publish(
            bloc.state.copyWith(
              failure: const InvalidVaultCredentialsFailure(),
            ),
          );
          await tester.pumpAndSettle();

          expect(bloc.state.failure, isNull);
          expect(
            observer.pushes,
            pushesBeforeFailure,
            reason:
                'Neither the fetch error nor clearing it selects another vault.',
          );
          expect(find.byType(PasswordInputPage), findsOneWidget);
          expect(
            tester.state(find.byType(PasswordInputPage)),
            same(originalPasswordState),
          );
          expect(
            find.byType(VaultSelectedPage, skipOffstage: false),
            findsOneWidget,
          );
          expect(
            find.byType(FetchVaultKeyPage, skipOffstage: false),
            findsNothing,
          );
          expect(bloc.events.whereType<OnClearError>(), hasLength(1));

          await tester.tap(find.text(loc.recoverbullContinue));
          await tester.pumpAndSettle();
          expect(find.byType(FetchVaultKeyPage), findsOneWidget);
          expect(bloc.events.whereType<OnVaultPasswordSet>(), hasLength(2));
          BullSnackBar.dismiss();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets('finishing recovery clears the retained form input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = _Bloc(RecoverBullFlow.recoverVault, _Vault());
    addTearDown(bloc.disposeStream);
    await tester.pumpWidget(
      BlocProvider<RecoverBullBloc>.value(
        value: bloc,
        child: MaterialApp(
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return withTestUiLabels(context, child);
          },
          theme: ThemeData(extensions: const [testBullTheme]),
          localizationsDelegates:
              RecoverBullLocalizations.localizationsDelegates,
          supportedLocales: RecoverBullLocalizations.supportedLocales,
          home: const PasswordInputPage(),
        ),
      ),
    );
    for (final digit in '975318'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    final controller = tester
        .widget<TextFormField>(find.byType(TextFormField).first)
        .controller;
    if (controller == null) fail('Expected the form controller');
    expect(controller.text.length, 6);
    bloc.publish(bloc.state.copyWith(isFlowFinished: true));
    await tester.pump();
    expect(controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
