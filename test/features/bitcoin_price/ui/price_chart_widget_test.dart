import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockGetPriceHistoryUsecase extends Mock
    implements GetPriceHistoryUsecase {}

class _MockRefreshPriceHistoryUsecase extends Mock
    implements RefreshPriceHistoryUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockWatchCurrencyChangesUsecase extends Mock
    implements WatchCurrencyChangesUsecase {}

Rate _rate(double price, int day) => Rate(
  fromCurrency: 'BTC',
  toCurrency: 'CAD',
  interval: RateTimelineInterval.day,
  createdAt: DateTime(2026, 1, day),
  price: price,
);

void main() {
  testWidgets('settles after the chart animations finish', (tester) async {
    final watchCurrencyChanges = _MockWatchCurrencyChangesUsecase();
    when(
      () => watchCurrencyChanges.execute(),
    ).thenAnswer((_) => const Stream<String>.empty());

    final bitcoinPriceBloc = BitcoinPriceBloc(
      getAvailableCurrenciesUsecase: _MockGetAvailableCurrenciesUsecase(),
      getSettingsUsecase: _MockGetSettingsUsecase(),
      convertSatsToCurrencyAmountUsecase:
          _MockConvertSatsToCurrencyAmountUsecase(),
      watchCurrencyChangesUsecase: watchCurrencyChanges,
    );
    final priceChartCubit =
        PriceChartCubit(
          getPriceHistoryUsecase: _MockGetPriceHistoryUsecase(),
          refreshPriceHistoryUsecase: _MockRefreshPriceHistoryUsecase(),
          getSettingsUsecase: _MockGetSettingsUsecase(),
        )..emit(
          PriceChartState(
            prices: [_rate(100, 1), _rate(120, 2), _rate(110, 3)],
            currency: 'CAD',
            selectedDataPointIndex: 1,
          ),
        );
    addTearDown(bitcoinPriceBloc.close);
    addTearDown(priceChartCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
