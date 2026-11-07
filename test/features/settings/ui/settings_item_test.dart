import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_settings_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WalletSettingsScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final items = buildSettingsItems(
        localization: AppLocalizationsEn(),
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
      // The only other explicit order is backup; all its entries remain available.
      expect(backupSettingsDataItemOrder.map(items.byId), hasLength(2));
    });
  }

  testWidgets('a registry item opens its dedicated route directly', (
    tester,
  ) async {
    final localization = AppLocalizationsEn();
    final item = buildSettingsItems(
      localization: localization,
    ).byId(SettingsItemId.importWallet);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: item.buildTile(context)),
        ),
        GoRoute(
          name: ImportWalletRoute.importWalletHome.name,
          path: ImportWalletRoute.importWalletHome.path,
          builder: (context, state) => const Text('Import wallet destination'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.tap(find.text(localization.walletSettingsImportWalletTitle));
    await tester.pumpAndSettle();

    expect(find.text('Import wallet destination'), findsOneWidget);
  });
}
