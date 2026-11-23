import 'package:bull_ui/app_theme.dart';
import 'package:overview/overview.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:settings/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmountScope,
        BullAmountSnapshot,
        BullScrollableColumn,
        bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Future<void> _pumpCard(
  WidgetTester tester, {
  required String title,
  required String description,
  required int balanceSat,
  bool inScrollableColumn = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = _MockSettingsCubit();
  when(() => settings.state).thenReturn(const SettingsState());
  when(() => settings.stream).thenAnswer((_) => const Stream.empty());

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
          BitcoinPriceFixture.prices(),
        ],
        child: BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => true,
          child: Scaffold(
            body: inScrollableColumn
                ? BullScrollableColumn(
                    children: [
                      WalletCard(
                        tagColor: const Color(0xFF000000),
                        title: title,
                        description: description,
                        balanceSat: balanceSat,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      WalletCard(
                        tagColor: const Color(0xFF000000),
                        title: title,
                        description: description,
                        balanceSat: balanceSat,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('can be measured inside an intrinsic-height scrollable column', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      title: 'Instant payments',
      description: 'Liquid and Lightning',
      balanceSat: 66000,
      inScrollableColumn: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Instant payments'), findsOneWidget);
  });

  testWidgets('a long label and a large balance fit a phone-width card', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      title: 'My imported cold storage wallet from the old laptop',
      description: 'Bitcoin network, watch-only descriptor wallet',
      balanceSat: 100000000000, // 1,000 BTC
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('100,000,000,000'), findsOneWidget);
  });

  testWidgets('centres its content vertically in the card', (tester) async {
    await _pumpCard(
      tester,
      title: 'Secure Bitcoin',
      description: 'Bitcoin network',
      balanceSat: 0,
    );

    final card = tester.getRect(
      find
          .ancestor(
            of: find.byIcon(Icons.chevron_right),
            matching: find.byType(Stack),
          )
          .first,
    );
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
    expect(chevron.center.dy, moreOrLessEquals(card.center.dy, epsilon: 0.5));
  });
}
