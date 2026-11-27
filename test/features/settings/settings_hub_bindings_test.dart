import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:exchange/setup.dart' show ExchangeAccessLifecycle;
import 'package:exchange/testing.dart' show exchangeForTesting;
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:settings/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/network.dart' show NoDefaultWalletFailure;
import 'package:network/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Err;
import 'package:settings/settings.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Settings extends MockCubit<SettingsState> implements SettingsCubit {}

class _Exchange extends Mock implements ExchangeAccessLifecycle {}

void main() {
  testWidgets('hub and search follow preferences and live exchange access', (
    tester,
  ) async {
    final settings = _Settings();
    final settingsChanges = StreamController<SettingsState>();
    final accessChanges = StreamController<ExchangeAccess>.broadcast();
    final exchange = _Exchange();
    whenListen(
      settings,
      settingsChanges.stream,
      initialState: const SettingsState(),
    );
    ExchangeAccess current = const ExchangeAccessSignedIn(_testSession);
    when(() => exchange.current).thenAnswer((_) => current);
    when(exchange.watch).thenAnswer((_) => accessChanges.stream);
    locator.pushNewScope();
    locator.registerSingleton<Exchange>(exchangeForTesting(access: exchange));
    addTearDown(locator.popScope);
    addTearDown(settingsChanges.close);
    addTearDown(accessChanges.close);

    var resolutions = 0;
    final hub = SettingsFeature.mount(
      exchange: () {
        resolutions++;
        return locator<Exchange>();
      },
      status: networkStatusForTest(
        () async => const Err(NoDefaultWalletFailure()),
      ),
      childRoutes: const [],
    );
    final router = GoRouter(initialLocation: '/settings', routes: [hub.route]);
    addTearDown(router.dispose);
    expect(resolutions, 0);
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.themeData(AppThemeType.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account Settings'), findsNothing);

    settingsChanges.add(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account Settings'), findsOneWidget);

    current = const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
    accessChanges.add(current);
    await tester.pumpAndSettle();
    expect(find.text('Account Settings'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-search-bar')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'account settings',
    );
    await tester.pumpAndSettle();
    expect(find.text('Account Settings'), findsNothing);

    current = const ExchangeAccessSignedIn(_testSession);
    accessChanges.add(current);
    await tester.pumpAndSettle();
    expect(find.text('Account Settings'), findsOneWidget);

    current = const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
    accessChanges.add(current);
    await tester.pumpAndSettle();
    expect(find.text('Account Settings'), findsNothing);
    expect(find.text('account settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
