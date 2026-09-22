import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_menu_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_settings_screen.dart';
import 'package:bb_mobile/features/psbt_signing/public/psbt_signing_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';

class _Inspect extends Mock implements InspectBullVaultUsecase {}

class _Menu extends Fake implements LoadBullVaultMenuUsecase {}

void main() {
  testWidgets(
    'every selected-vault action keeps that wallet id and reloads on return',
    (tester) async {
      final fixture = testBullVaultCreateResult(walletId: 'historical');
      final inspect = _Inspect();
      when(() => inspect.execute('historical')).thenAnswer(
        (_) async =>
            Ok(BullVaultInspection(fixture.record, fixture.wallet, {})),
      );
      final cubit = BullVaultSettingsCubit(_Menu(), inspect);
      final loc = AppLocalizationsEn();
      final actions = {
        BullVaultFacade.policyRouteName: loc.bullVaultViewPolicy,
        BullVaultFacade.keysRouteName: loc.bullVaultViewKeys,
        BullVaultFacade.backupRouteName: loc.bullVaultBackupRecovery,
        BullVaultFacade.renewRouteName: loc.bullVaultRenew,
        BullVaultFacade.cosignerRouteName: loc.bullVaultImportCosigner,
        SettingsRoute.walletRegistration.name: loc.bullVaultRegisterVault,
        const PsbtSigningFacade().routeName: loc.psbtSigningTitle,
      };
      final destinations = <GoRouterState>[];
      final router = GoRouter(
        initialLocation: '/selected',
        routes: [
          GoRoute(
            path: '/selected',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const BullVaultSettingsScreen(walletId: 'historical'),
            ),
          ),
          for (final route in actions.keys)
            GoRoute(
              name: route,
              path: '/$route/:walletId',
              builder: (_, state) {
                destinations.add(state);
                return const Scaffold(body: Text('destination'));
              },
            ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        await cubit.close();
      });
      await cubit.load('historical');
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      for (final action in actions.entries) {
        final finder = find.text(action.value);
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(destinations.last.name, action.key);
        expect(destinations.last.pathParameters['walletId'], 'historical');
        if (action.key == SettingsRoute.walletRegistration.name) {
          expect(
            (destinations.last.extra as WalletRegistrationRequest).wallet.id,
            'historical',
          );
        }
        router.pop();
        await tester.pumpAndSettle();
      }
      verify(() => inspect.execute('historical')).called(actions.length + 1);
    },
  );
}
