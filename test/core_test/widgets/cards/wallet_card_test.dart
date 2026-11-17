import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmountScope, BullAmountSnapshot, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

void main() {
  testWidgets('a long label and a large balance fit a phone-width card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _MockSettingsCubit();
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    final price = _MockBitcoinPriceBloc();
    when(() => price.state).thenReturn(const BitcoinPriceState());
    when(() => price.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settings),
            BlocProvider<BitcoinPriceBloc>.value(value: price),
          ],
          child: BullAmountScope(
            snapshot: const BullAmountSnapshot(
              unit: BitcoinUnit.sats,
              hideAmounts: false,
              isReady: true,
            ),
            writeUnit: (_) async => true,
            child: Scaffold(
              body: WalletCard(
                tagColor: const Color(0xFF000000),
                title: 'My imported cold storage wallet from the old laptop',
                description: 'Bitcoin network, watch-only descriptor wallet',
                balanceSat: 100000000000, // 1,000 BTC
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('100,000,000,000'), findsOneWidget);
  });
}
