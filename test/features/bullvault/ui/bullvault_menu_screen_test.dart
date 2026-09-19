import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_menu_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_menu_screen.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';

class _Menu extends Mock implements LoadBullVaultMenuUsecase {}

class _Inspect extends Fake implements InspectBullVaultUsecase {}

void main() {
  late _Menu menu;
  late BullVaultSettingsCubit cubit;
  late GoRouter router;
  late List<GoRouterState> destinations;
  final loc = AppLocalizationsEn();
  setUp(() {
    menu = _Menu();
    when(menu.execute).thenAnswer((_) async => const Ok([]));
    cubit = BullVaultSettingsCubit(menu, _Inspect());
    destinations = [];
    Widget destination(BuildContext context, GoRouterState state) {
      destinations.add(state);
      return const Scaffold(body: Text('destination'));
    }

    router = GoRouter(
      initialLocation: '/menu',
      routes: [
        GoRoute(
          path: '/menu',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const BullVaultMenuScreen(),
          ),
        ),
        GoRoute(
          path: '/selected/:walletId',
          name: BullVaultFacade.settingsRouteName,
          builder: destination,
        ),
        GoRoute(
          path: '/create',
          name: BullVaultFacade.createRouteName,
          builder: destination,
        ),
        GoRoute(
          path: '/recover',
          name: BullVaultFacade.restoreRouteName,
          builder: destination,
        ),
        GoRoute(
          path: '/signer',
          name: SettingsRoute.signingKeyExport.name,
          builder: destination,
        ),
      ],
    );
  });
  tearDown(() async {
    router.dispose();
    await cubit.close();
  });
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  testWidgets(
    'a card names its actual identifier, opens that vault, and refreshes after return',
    (tester) async {
      final record = testBullVaultCreateResult(
        walletId: 'selected-vault',
      ).record;
      when(menu.execute).thenAnswer((_) async => Ok([record]));
      await cubit.load();
      await pump(tester);
      final card = find.text(loc.bullVaultIdentifier('selected'));
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(destinations.last.pathParameters['walletId'], 'selected-vault');
      router.pop();
      await tester.pumpAndSettle();
      verify(menu.execute).called(2);
    },
  );
  testWidgets(
    'an empty menu retains create, recover, signer and practice entries',
    (tester) async {
      await cubit.load();
      await pump(tester);
      expect(find.text(loc.bullVaultCreateEntry), findsOneWidget);
      expect(find.text(loc.bullVaultRecoverEntry), findsOneWidget);
      expect(find.text(loc.bullVaultUseBullAsSigner), findsOneWidget);
      expect(find.text(loc.bullVaultCreatePracticeEntry), findsOneWidget);
      await tester.tap(find.text(loc.bullVaultCreatePracticeEntry));
      await tester.pumpAndSettle();
      expect(destinations.last.uri.queryParameters, {'practice': 'true'});
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.bullVaultCreateEntry));
      await tester.pumpAndSettle();
      expect(destinations.last.uri.queryParameters, isEmpty);
    },
  );
  testWidgets(
    'loading and a failed read stay distinct from an empty vault list',
    (tester) async {
      final pending =
          Completer<Result<List<BullVaultRecord>, BullVaultFailure>>();
      when(menu.execute).thenAnswer((_) => pending.future);
      final load = cubit.load();
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(const Err(BullVaultBackupStatusFailure()));
      await load;
      await tester.pumpAndSettle();
      expect(find.text(loc.walletDetailsUnavailableLabel), findsOneWidget);
      when(menu.execute).thenAnswer((_) async => const Ok([]));
      await tester.tap(find.text(loc.retry));
      await tester.pumpAndSettle();
      expect(find.text(loc.walletDetailsUnavailableLabel), findsNothing);
      expect(find.text(loc.bullVaultCreateEntry), findsOneWidget);
    },
  );
}
