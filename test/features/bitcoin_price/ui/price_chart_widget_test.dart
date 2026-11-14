import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetBitcoinPriceUsecase extends Mock
    implements GetBitcoinPriceUsecase {}

class _MockGetPriceHistoryUsecase extends Mock
    implements GetPriceHistoryUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockWatchCurrencyChangesUsecase extends Mock
    implements WatchCurrencyChangesUsecase {}

PricePoint _point(double price, int day) => PricePoint(
  currency: SupportedCurrency.cad,
  fiatAmount: price,
  time: DateTime.utc(2026, 1, day),
);

void main() {
  Future<PriceChartCubit> pumpChart(
    WidgetTester tester,
    List<PricePoint> prices, {
    int? selectedDataPointIndex,
  }) async {
    final watchCurrencyChanges = _MockWatchCurrencyChangesUsecase();
    when(() => watchCurrencyChanges.execute())
        .thenAnswer((_) => const Stream<String>.empty());

    final bitcoinPriceBloc = BitcoinPriceBloc(
      getSettingsUsecase: _MockGetSettingsUsecase(),
      getBitcoinPriceUsecase: _MockGetBitcoinPriceUsecase(),
      watchCurrencyChangesUsecase: watchCurrencyChanges,
    );
    final priceChartCubit =
        PriceChartCubit(
          getPriceHistoryUsecase: _MockGetPriceHistoryUsecase(),
          getSettingsUsecase: _MockGetSettingsUsecase(),
        )..emit(
          PriceChartState(
            prices: prices,
            currency: 'CAD',
            selectedDataPointIndex: selectedDataPointIndex,
          ),
        );
    addTearDown(bitcoinPriceBloc.close);
    addTearDown(priceChartCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: bitcoinPriceBloc),
              BlocProvider.value(value: priceChartCubit),
            ],
            child: const PriceChartWidget(),
          ),
        ),
      ),
    );
    return priceChartCubit;
  }

  // A single point used to divide the chart width by zero and paint NaN
  // offsets on every frame.
  testWidgets('a single point paints without error', (tester) async {
    await pumpChart(tester, [_point(100, 1)]);
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  // Equal prices used to divide by a zero price range.
  testWidgets('a flat line paints without error', (tester) async {
    await pumpChart(tester, [_point(100, 1), _point(100, 2), _point(100, 3)]);
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('settles after the chart animations finish', (tester) async {
    final priceChartCubit = await pumpChart(tester, [
      _point(100, 1),
      _point(120, 2),
      _point(110, 3),
    ], selectedDataPointIndex: 1);

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);

    final chart = find.byType(CustomPaint).last;
    final chartRect = tester.getRect(chart);
    await tester.tapAt(Offset(chartRect.right - 1, chartRect.center.dy));
    await tester.pump();

    expect(priceChartCubit.state.selectedDataPointIndex, 2);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
