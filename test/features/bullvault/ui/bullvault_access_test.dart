import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bullvault/bullvault_locator.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_search.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _SettingsEntries extends Fake implements SettingsFacade {
  final entries = <SettingsEntryContribution>[];

  @override
  void registerEntry(SettingsEntryContribution entry) => entries.add(entry);
}

class _Settings extends Mock implements SettingsCubit {}

void main() {
  late _SettingsEntries contributions;
  final loc = AppLocalizationsEn();

  setUp(() {
    final locator = GetIt.asNewInstance();
    contributions = _SettingsEntries();
    locator.registerSingleton<SettingsFacade>(contributions);
    BullVaultLocator.setup(locator);
    addTearDown(locator.reset);
  });

  List<SettingsItem> items({bool superuser = false, bool dev = false}) =>
      buildSettingsItems(
        localization: loc,
        isSuperuser: superuser,
        isDevModeEnabled: dev,
        contributions: contributions.entries,
      );

  test(
    'BullVault and its search shortcuts require superuser, not dev mode',
    () {
      for (final dev in [false, true]) {
        expect(searchSettings(items(dev: dev), 'BullVault'), isEmpty);
        final enabled = searchSettings(
          items(superuser: true, dev: dev),
          'BullVault',
        );
        expect(
          enabled.map((item) => item.id),
          contains(SettingsItemId.extension),
        );
        expect(enabled.every((item) => item.isSuperuser), isTrue);
      }
    },
  );

  Future<GoRouter> pumpEntry(WidgetTester tester, {bool search = false}) async {
    final entries = items(superuser: true);
    final entry = search
        ? searchSettings(entries, 'BullVault').first
        : entries.byId(SettingsItemId.extension);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(body: entry.buildTile(context)),
        ),
        GoRoute(
          name: BullVaultFacade.menuRouteName,
          path: '/bullvault',
          builder: (_, _) =>
              const Scaffold(body: Text('Vault menu destination')),
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
    await tester.tap(find.text(loc.bullVaultMenuTitle));
    await tester.pumpAndSettle();
    expect(
      find.text('BullVault is experimental. Do not use it for real funds.'),
      findsOneWidget,
    );
    expect(find.text('Vault menu destination'), findsNothing);
    return router;
  }

  testWidgets('cancel, outside tap and Back do not enter BullVault', (
    tester,
  ) async {
    await pumpEntry(tester);
    await tester.tap(find.text(loc.cancelButton));
    await tester.pumpAndSettle();
    expect(find.text('Vault menu destination'), findsNothing);

    await tester.tap(find.text(loc.bullVaultMenuTitle));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('Vault menu destination'), findsNothing);

    await tester.tap(find.text(loc.bullVaultMenuTitle));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Vault menu destination'), findsNothing);
  });

  testWidgets(
    'search entry requires Continue and warns again on the next visit',
    (tester) async {
      final router = await pumpEntry(tester, search: true);
      await tester.tap(find.text(loc.continueButton));
      await tester.pumpAndSettle();
      expect(find.text('Vault menu destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.bullVaultMenuTitle));
      await tester.pumpAndSettle();
      expect(
        find.text('BullVault is experimental. Do not use it for real funds.'),
        findsOneWidget,
      );
      expect(find.text('Vault menu destination'), findsNothing);
    },
  );

  for (final superuser in [null, false, true]) {
    testWidgets('direct BullVault routes respect superuser=$superuser', (
      tester,
    ) async {
      final settings = _Settings();
      when(() => settings.state).thenReturn(
        SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
            isSuperuser: superuser,
          ),
        ),
      );
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      const paths = [
        '/bullvault',
        '/bullvault/create',
        '/bullvault/restore',
        '/bullvault/vault/settings',
        '/bullvault/vault/policy',
        '/bullvault/vault/keys',
        '/bullvault/vault/backup',
        '/bullvault/vault/renew',
        '/bullvault/vault/cosigner',
        '/bullvault/scan',
        '/settings/signing-key-export',
      ];
      final router = GoRouter(
        redirect: AppRouter.router.configuration.topRedirect,
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Text('Settings destination'),
          ),
          GoRoute(
            path: '/data-backup',
            builder: (_, _) => const Text('Data backup destination'),
          ),
          for (final path in paths)
            GoRoute(
              path: path,
              name: path.endsWith('signing-key-export')
                  ? SettingsRoute.signingKeyExport.name
                  : null,
              builder: (_, _) => Text('Opened $path'),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider<SettingsCubit>.value(
          value: settings,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      for (final path in paths) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          find.text('Opened $path'),
          superuser == true ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Settings destination'),
          superuser == true ? findsNothing : findsOneWidget,
        );
      }
      router.go('/data-backup');
      await tester.pumpAndSettle();
      expect(find.text('Data backup destination'), findsOneWidget);
    });
  }
}
