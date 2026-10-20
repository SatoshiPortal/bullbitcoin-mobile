import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/provider_cart.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/fetch_vault_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_provider_selection_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_selected_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
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
                theme: AppTheme.themeData(AppThemeType.light),
                navigatorObservers: [observer],
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const VaultProviderSelectionPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
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
}
