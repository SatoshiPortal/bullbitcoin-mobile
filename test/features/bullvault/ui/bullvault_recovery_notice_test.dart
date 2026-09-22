import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_funded_predecessor_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_recovery_notice_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_home_alert.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_recovery_notice.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Funded extends Mock implements GetBullVaultFundedPredecessorUsecase {}

void main() {
  test(
    'opening an older notice cannot clear a newer recovered vault',
    () async {
      final cubit = BullVaultRecoveryNoticeCubit();
      addTearDown(cubit.close);
      cubit.record(walletId: 'first', label: 'First vault');
      cubit.record(walletId: 'second', label: 'Second vault');
      cubit.opened('first');
      expect(cubit.state?.walletId, 'second');
      cubit.opened('second');
      expect(cubit.state, isNull);
    },
  );
  testWidgets(
    'a named recovery notice coexists with the funded alert and opens only that vault',
    (tester) async {
      final notice = BullVaultRecoveryNoticeCubit()
        ..record(walletId: 'recovered', label: 'Family vault');
      final funded = _Funded();
      when(
        () => funded.execute(any()),
      ).thenAnswer((_) async => const Ok('active'));
      final home = BullVaultHomeAlertCubit(funded);
      final destinations = <GoRouterState>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: notice),
                BlocProvider.value(value: home),
              ],
              child: const Scaffold(
                body: Column(
                  children: [
                    BullVaultRecoveryNotice(),
                    BullVaultHomeAlert(wallets: []),
                  ],
                ),
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
        await notice.close();
        await home.close();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Family vault'), findsOneWidget);
      expect(
        find.text(AppLocalizationsEn().bullVaultPreviousFundsAction),
        findsOneWidget,
      );
      await tester.tap(find.text('Family vault'));
      await tester.pumpAndSettle();
      expect(destinations.last.name, BullVaultFacade.settingsRouteName);
      expect(destinations.last.pathParameters['walletId'], 'recovered');
      expect(notice.state, isNull);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Family vault'), findsNothing);
      await tester.tap(
        find.text(AppLocalizationsEn().bullVaultPreviousFundsAction),
      );
      await tester.pumpAndSettle();
      expect(destinations.last.name, BullVaultFacade.renewRouteName);
      expect(destinations.last.pathParameters['walletId'], 'active');
    },
  );
}
