import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/fetch_vault_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MutableRecoverBullBloc extends Fake implements RecoverBullBloc {
  RecoverBullState _state;
  final StreamController<RecoverBullState> _states =
      StreamController<RecoverBullState>.broadcast();

  _MutableRecoverBullBloc(this._state);

  @override
  RecoverBullState get state => _state;

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  @override
  void add(RecoverBullEvent event) {}

  void emitState(RecoverBullState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Future<void> close() => _states.close();
}

void main() {
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
          path: '/tor-settings',
          name: TorSettingsRoute.torSettings.name,
          builder: (_, _) =>
              const Scaffold(body: Text('Tor settings destination')),
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
}
