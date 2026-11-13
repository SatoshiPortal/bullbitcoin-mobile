import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_history_screen.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart' show BullTheme;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chart extends MockCubit<PriceChartState> implements PriceChartCubit {}

class _Price extends MockBloc<BitcoinPriceEvent, BitcoinPriceState>
    implements BitcoinPriceBloc {}

void main() {
  for (final mode in AppThemeType.values) {
    for (final status in ['loading', 'error', 'data']) {
      testWidgets('history uses neutral theme colors in ${mode.name} $status', (
        tester,
      ) async {
        final theme = AppTheme.themeData(mode);
        final colors =
            theme.extension<BullTheme>() ??
            (throw StateError('Missing palette'));
        final chart = _Chart();
        final price = _Price();
        whenListen(
          price,
          const Stream<BitcoinPriceState>.empty(),
          initialState: const BitcoinPriceState(),
        );
        whenListen(
          chart,
          const Stream<PriceChartState>.empty(),
          initialState: PriceChartState(
            currency: 'CAD',
            isLoading: status == 'loading',
            failure: status == 'error' ? const PriceChartLoadFailure() : null,
            prices: status == 'data'
                ? [
                    PricePoint(
                      currency: SupportedCurrency.cad,
                      fiatAmount: 100,
                      time: DateTime.utc(2026),
                    ),
                  ]
                : [],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<BitcoinPriceBloc>.value(value: price),
                BlocProvider<PriceChartCubit>.value(value: chart),
              ],
              child: PriceHistoryScreen(onBack: () {}),
            ),
          ),
        );
        await tester.pump();
        final panel = tester.widget<Container>(
          find.descendant(
            of: find.byType(PriceHistoryScreen),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.color != null,
            ),
          ),
        );
        expect(
          panel.color,
          mode == AppThemeType.dark ? colors.background : colors.surface,
        );
        if (status == 'loading') {
          expect(
            tester
                .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator),
                )
                .color,
            colors.text,
          );
        } else if (status == 'error') {
          expect(
            tester.widget<Icon>(find.byIcon(Icons.refresh)).color,
            colors.text,
          );
        } else {
          expect(
            tester.widget<Text>(find.text('100.00')).style?.color,
            colors.text,
          );
          final painter = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((w) => w.painter)
              .where((p) => p.runtimeType.toString() == '_ChartPainter')
              .single;
          final dynamic style = painter;
          expect(style.lineColor, colors.text);
          expect(style.borderColor, colors.text);
          expect(style.dotColor, colors.text);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final mode in AppThemeType.values) {
    testWidgets('embedded chart retains its inherited colors in ${mode.name}', (
      tester,
    ) async {
      final theme = AppTheme.themeData(mode);
      final colors =
          theme.extension<BullTheme>() ?? (throw StateError('Missing palette'));
      final chart = _Chart();
      final price = _Price();
      whenListen(
        price,
        const Stream<BitcoinPriceState>.empty(),
        initialState: const BitcoinPriceState(),
      );
      whenListen(
        chart,
        const Stream<PriceChartState>.empty(),
        initialState: PriceChartState(
          currency: 'CAD',
          prices: [
            PricePoint(
              currency: SupportedCurrency.cad,
              fiatAmount: 100,
              time: DateTime.utc(2026),
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<BitcoinPriceBloc>.value(value: price),
              BlocProvider<PriceChartCubit>.value(value: chart),
            ],
            child: const Scaffold(body: PriceChartWidget()),
          ),
        ),
      );
      await tester.pump();
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .where((p) => p.runtimeType.toString() == '_ChartPainter')
          .single;
      final dynamic style = painter;
      expect(style.lineColor, colors.onPrimary);
      expect(style.borderColor, colors.onPrimary);
      expect(style.dotColor, colors.onTertiary);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
