import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_wallet_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_wallet_settings_action.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';

class _Details extends Mock implements GetBullVaultDetailsUsecase {}

void main() {
  for (final funded in [false, true]) {
    testWidgets(
      funded
          ? 'the funded-predecessor action still opens renewal'
          : 'inspection opens the selected historical wallet, not its active successor',
      (tester) async {
        final selected = testBullVaultCreateResult(
          walletId: 'selected',
          status: .migrating,
        );
        final successor = testBullVaultCreateResult(
          walletId: 'successor',
          status: .active,
        );
        final usecase = _Details();
        when(() => usecase.execute('selected')).thenAnswer(
          (_) async => Ok(
            BullVaultDetails(
              record: successor.record,
              timeUntilFirstRecovery: null,
              showEarlyRenewalWarning: false,
              migrationAddress: funded ? 'address' : null,
              previousVaults: funded
                  ? [
                      BullVaultPreviousVault(
                        record: selected.record,
                        wallet: selected.wallet.copyWith(
                          balanceSat: BigInt.one,
                        ),
                      ),
                    ]
                  : [],
            ),
          ),
        );
        final cubit = BullVaultWalletSettingsCubit(usecase);
        final destinations = <GoRouterState>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: Scaffold(
                  body: BullVaultWalletSettingsAction(wallet: selected.wallet),
                ),
              ),
            ),
            for (final name in [
              BullVaultFacade.settingsRouteName,
              BullVaultFacade.renewRouteName,
            ])
              GoRoute(
                name: name,
                path: '/$name/:walletId',
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
        await cubit.load('selected');
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(
          destinations.single.name,
          funded
              ? BullVaultFacade.renewRouteName
              : BullVaultFacade.settingsRouteName,
        );
        expect(
          destinations.single.pathParameters['walletId'],
          funded ? 'successor' : 'selected',
        );
      },
    );
  }
}
