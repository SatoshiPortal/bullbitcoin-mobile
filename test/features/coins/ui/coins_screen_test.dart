import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/coins_state.dart';
import 'package:bb_mobile/features/coins/ui/screens/coins_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../wallet_utxo_fixture.dart';

class _MockCoinsCubit extends Mock implements CoinsCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  for (final isSweep in [false, true]) {
    final action = isSweep ? 'Sweep' : 'Send';

    testWidgets('$action returns to the selected coins screen', (tester) async {
      final utxo = walletUtxoFixture(
        walletId: 'wallet',
        txId: 'selected',
        sats: 75000,
      );
      final coinsCubit = _MockCoinsCubit();
      final settingsCubit = _MockSettingsCubit();
      final coinsState = CoinsState(
        walletId: utxo.walletId,
        utxos: [utxo],
        selecting: true,
        selectedOutpoints: {'${utxo.txId}:${utxo.vout}'},
      );
      Set<Outpoint>? openedOutpoints;
      bool? openedAsSweep;

      when(() => coinsCubit.state).thenReturn(coinsState);
      when(() => coinsCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => coinsCubit.load()).thenAnswer((_) async {});
      when(() => settingsCubit.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.testnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
            hideAmounts: false,
          ),
        ),
      );
      when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());

      final router = GoRouter(
        initialLocation: '/coins',
        routes: [
          GoRoute(
            path: '/coins',
            builder: (context, _) => BlocProvider<CoinsCubit>.value(
              value: coinsCubit,
              child: CoinsScreen(
                onSend: (outpoints) async {
                  openedOutpoints = outpoints;
                  openedAsSweep = false;
                  await context.push<void>('/transaction');
                },
                onSweep: (outpoints) async {
                  openedOutpoints = outpoints;
                  openedAsSweep = true;
                  await context.push<void>('/transaction');
                },
              ),
            ),
          ),
          GoRoute(
            path: '/transaction',
            builder: (_, _) =>
                Scaffold(appBar: AppBar(), body: Text('$action flow')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        BlocProvider<SettingsCubit>.value(
          value: settingsCubit,
          child: MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('$action flow'), findsOneWidget);
      expect(openedAsSweep, isSweep);
      expect(openedOutpoints, {(txId: utxo.txId, vout: utxo.vout)});

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('$action flow'), findsNothing);
      verify(() => coinsCubit.load()).called(1);
    });
  }
}
