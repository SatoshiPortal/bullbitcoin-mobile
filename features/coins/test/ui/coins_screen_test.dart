import 'package:bull_ui/app_theme.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Outpoint;
import 'package:coins/src/presentation/coins_cubit.dart';
import 'package:coins/src/presentation/coins_state.dart';
import 'package:coins/src/ui/screens/coins_screen.dart';
import 'package:coins/setup.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:coins/testing.dart';

class _MockCoinsCubit extends Mock implements CoinsCubit {}

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
      final coinsState = CoinsState(
        amountDisplay: (
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          hideAmounts: false,
        ),
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
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: [
            CoinsLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: CoinsLocalizations.supportedLocales,
          routerConfig: router,
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
