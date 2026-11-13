import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/public/bitcoin_price_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _History extends Mock implements GetPriceHistoryUsecase {}

class _Price extends Mock implements GetBitcoinPriceUsecase {}

class _Watch extends Mock implements WatchCurrencyChangesUsecase {}

void main() {
  testWidgets(
    'history screen loads its own chart and returns through callback',
    (tester) async {
      final settings = _Settings();
      final history = _History();
      when(settings.execute).thenAnswer(
        (_) async => SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.btc,
          currencyCode: 'CAD',
        ),
      );
      when(
        () => history.execute(currencyCode: 'CAD'),
      ).thenAnswer((_) async => const Err(PriceChartLoadFailure()));
      final locator = GetIt.asNewInstance();
      locator.registerFactory<PriceChartCubit>(
        () => PriceChartCubit(
          getPriceHistoryUsecase: history,
          getSettingsUsecase: settings,
        ),
      );
      final watch = _Watch();
      when(watch.execute).thenAnswer((_) => const Stream<String>.empty());
      final priceBloc = BitcoinPriceBloc(
        getSettingsUsecase: settings,
        getBitcoinPriceUsecase: _Price(),
        watchCurrencyChangesUsecase: watch,
      );
      addTearDown(locator.reset);
      addTearDown(priceBloc.close);
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: priceBloc,
            child: BitcoinPriceFacade(
              locator,
            ).buildHistory(onBack: () => returned = true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => history.execute(currencyCode: 'CAD')).called(1);
      expect(find.text('Price history'), findsOneWidget);
      expect(
        find.text('Price chart data could not be loaded. Please try again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      verify(() => history.execute(currencyCode: 'CAD')).called(1);
      await tester.tap(find.byType(IconButton).first);
      expect(returned, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
