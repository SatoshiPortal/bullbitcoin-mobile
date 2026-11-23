import 'package:coins/src/presentation/coins_state.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bull_ui/app_theme.dart';
import 'package:coins/src/ui/widgets/coins_selection_bar.dart';
import 'package:coins/src/presentation/coins_cubit.dart';
import 'package:coins/setup.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoinsCubit extends Mock implements CoinsCubit {}

void main() {
  testWidgets('shows Send and Sweep only for fully spendable coins', (
    tester,
  ) async {
    var sends = 0;
    var sweeps = 0;
    final coinsCubit = _MockCoinsCubit();
    when(() => coinsCubit.state).thenReturn(
      const CoinsState(
        walletId: 'wallet',
        amountDisplay: (
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          hideAmounts: false,
        ),
      ),
    );
    when(() => coinsCubit.stream).thenAnswer((_) => const Stream.empty());

    Widget buildApp({required bool anyFrozen}) => MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: [
        CoinsLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: CoinsLocalizations.supportedLocales,
      home: BlocProvider<CoinsCubit>.value(
        value: coinsCubit,
        child: Scaffold(
          bottomNavigationBar: CoinsSelectionBar(
            selectedCount: 2,
            selectedTotalSat: BigInt.from(75000),
            anyUnfrozen: true,
            anyFrozen: anyFrozen,
            onSend: () => sends++,
            onSweep: () => sweeps++,
            onFreeze: () {},
            onUnfreeze: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildApp(anyFrozen: false));

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Sweep'), findsOneWidget);
    expect(find.textContaining('75,000'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.tap(find.text('Sweep'));

    expect(sends, 1);
    expect(sweeps, 1);

    await tester.pumpWidget(buildApp(anyFrozen: true));

    expect(find.text('Send'), findsNothing);
    expect(find.text('Sweep'), findsNothing);
  });
}
