import 'package:primitives/primitives.dart' show BitcoinUnit, NetworkEnv;
import 'package:settings/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:wallet_import/wallet_import.dart' show ImportNavigation;
import 'package:settings/generated/l10n/settings_localizations_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  test('Ark notification test is shown only in developer mode', () {
    final disabled = buildSettingsItems(
      localization: SettingsLocalizationsEn(),
      environment: NetworkEnv.mainnet,
    );
    final enabled = buildSettingsItems(
      localization: SettingsLocalizationsEn(),
      isDevModeEnabled: true,
      environment: NetworkEnv.mainnet,
    );
    expect(
      disabled.where((item) => item.id == SettingsItemId.arkDebugNotification),
      isEmpty,
    );
    expect(
      enabled.where((item) => item.id == SettingsItemId.arkDebugNotification),
      hasLength(1),
    );
  });
  for (final environment in Environment.values) {
    testWidgets('wallet settings skip unavailable entries on $environment', (
      tester,
    ) async {
      final cubit = _Settings();
      when(() => cubit.state).thenReturn(
        SettingsState(
          storedSettings: SettingsEntity(
            environment: environment,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(cubit.checkSpWalletSetup).thenAnswer((_) async {});
      await tester.pumpWidget(
        BlocProvider<SettingsCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: settingsTestLocalizationsDelegates,
            supportedLocales: SettingsLocalizations.supportedLocales,
            home: const WalletSettingsScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final items = buildSettingsItems(
        localization: SettingsLocalizationsEn(),
        environment: environment.networkEnv,
      );
      var previousY = double.negativeInfinity;
      for (final id in walletSettingsItemOrder) {
        final available = items.where((item) => item.id == id);
        if (available.isNotEmpty) {
          final tile = find.text(available.single.title);
          expect(tile, findsOneWidget);
          final y = tester.getTopLeft(tile).dy;
          expect(y, greaterThan(previousY));
          previousY = y;
        }
      }
    });
  }

  testWidgets('a registry item opens its dedicated route directly', (
    tester,
  ) async {
    final localization = SettingsLocalizationsEn();
    final item = buildSettingsItems(
      environment: NetworkEnv.mainnet,
      localization: localization,
    ).byId(SettingsItemId.importWallet);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: item.buildTile(context)),
        ),
        GoRoute(
          name: ImportNavigation.homeName,
          path: ImportNavigation.homePath,
          builder: (context, state) => const Text('Import wallet destination'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        routerConfig: router,
        localizationsDelegates: settingsTestLocalizationsDelegates,
        supportedLocales: SettingsLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text(localization.walletSettingsImportWalletTitle));
    await tester.pumpAndSettle();

    expect(find.text('Import wallet destination'), findsOneWidget);
  });

  test('Send feedback is listed only when a feedback form is configured', () {
    final off = buildSettingsItems(
      localization: SettingsLocalizationsEn(),
      environment: NetworkEnv.mainnet,
    );
    final on = buildSettingsItems(
      localization: SettingsLocalizationsEn(),
      feedbackAvailable: true,
      environment: NetworkEnv.mainnet,
    );

    expect(off.where((item) => item.id == SettingsItemId.feedback), isEmpty);
    final feedback = on.singleWhere(
      (item) => item.id == SettingsItemId.feedback,
    );
    expect(feedback.title, 'Send feedback');
    expect(feedback.section, SettingsItemSection.root);
    expect(feedback.keywords, contains('bug'));
  });
}
