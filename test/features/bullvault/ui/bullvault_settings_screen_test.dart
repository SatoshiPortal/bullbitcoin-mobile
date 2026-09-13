import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_settings_screen.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';

class _Vaults extends Mock implements BullVaultRepository {}

class _Wallets extends Mock implements GetWalletUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Seeds extends Mock implements SeedVerificationPort {}

void main() {
  final created = testBullVaultCreateResult(
    walletId: '01234567-vault',
    includesInheritance: true,
  );
  final vaults = _Vaults(), wallets = _Wallets(), settings = _Settings();
  final inspect = InspectBullVaultUsecase(vaults, wallets, settings, _Seeds());
  setUp(() {
    when(() => vaults.getAll()).thenAnswer((_) async => Ok([created.record]));
    when(
      () => vaults.getByWalletId(created.wallet.id),
    ).thenAnswer((_) async => Ok(created.record));
    when(
      () => wallets.execute(created.wallet.id),
    ).thenAnswer((_) async => created.wallet);
    when(settings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
  });

  testWidgets(
    'existing vault cards precede creation and group signer access under BullVault',
    (tester) async {
      final cubit = BullVaultSettingsCubit(inspect);
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const BullVaultSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/selected/:walletId',
            name: BullVaultFacade.settingsRouteName,
            builder: (_, state) => Scaffold(
              body: Text('Selected ${state.pathParameters['walletId']}'),
            ),
          ),
          GoRoute(
            path: '/signer',
            name: SettingsRoute.signingKeyExport.name,
            builder: (_, _) =>
                const Scaffold(body: Text('Existing signer flow')),
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
      final card = find.textContaining('01234567');
      expect(card, findsOneWidget);
      expect(find.textContaining('Balance'), findsNothing);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(
          tester
              .getTopLeft(find.text(AppLocalizationsEn().bullVaultCreateEntry))
              .dy,
        ),
      );
      expect(find.text('Use BULL as signer'), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Selected 01234567-vault'), findsOneWidget);
    },
  );

  testWidgets(
    'selected vault owns actions; policy and key inspection stay separate',
    (tester) async {
      final cubit = BullVaultSettingsCubit(inspect);
      addTearDown(cubit.close);
      await cubit.load(created.wallet.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: BullVaultSettingsScreen(
              walletId: created.wallet.id,
              page: BullVaultSettingsPage.selected,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View policy'), findsOneWidget);
      expect(find.text('View keys'), findsOneWidget);
      expect(find.text('Backup & recovery'), findsOneWidget);
      expect(find.text('Import cosigner key'), findsOneWidget);
      expect(find.text('Register vault on another device'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Use external signer'), findsNothing);
    },
  );
}
