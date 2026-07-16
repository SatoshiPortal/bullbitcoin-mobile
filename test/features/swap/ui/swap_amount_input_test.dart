import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_amount_input.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

class _LiquidWallet extends Fake implements Wallet {
  @override
  bool get isLiquid => true;
}

void main() {
  late _MockTransferBloc bloc;
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    bloc = _MockTransferBloc();
    controller = TextEditingController();
    focusNode = FocusNode();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pumpInput(
    WidgetTester tester, {
    TransferState state = const TransferState(
      inputAmountCurrencyCode: 'sats',
      fiatCurrencyCodes: ['CAD'],
      fiatCurrencyCode: 'CAD',
      exchangeRate: 100000,
      maxAmountSat: 1000,
    ),
  }) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<TransferBloc>.value(
            value: bloc,
            child: SwapAmountInput(
              amountController: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses Buy-style card layout with currency and Max actions', (
    tester,
  ) async {
    await pumpInput(tester);

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('sats'), findsOneWidget);
    expect(find.text('CAD'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert), findsOneWidget);
  });

  testWidgets('shows approximate sats for fiat input when sats are preferred', (
    tester,
  ) async {
    await pumpInput(
      tester,
      state: const TransferState(
        bitcoinUnit: BitcoinUnit.sats,
        inputAmountCurrencyCode: 'CAD',
        fiatCurrencyCodes: ['CAD'],
        fiatCurrencyCode: 'CAD',
        exchangeRate: 100000,
        amount: '50',
      ),
    );

    expect(find.text('~50,000 sats'), findsOneWidget);
  });

  testWidgets('shows approximate BTC for fiat input when BTC is preferred', (
    tester,
  ) async {
    await pumpInput(
      tester,
      state: const TransferState(
        bitcoinUnit: BitcoinUnit.btc,
        inputAmountCurrencyCode: 'CAD',
        fiatCurrencyCodes: ['CAD'],
        fiatCurrencyCode: 'CAD',
        exchangeRate: 100000,
        amount: '50',
      ),
    );

    expect(find.text('~0.00050000 BTC'), findsOneWidget);
  });

  testWidgets('Bitcoin arrow only offers Liquid bitcoin units', (tester) async {
    await pumpInput(
      tester,
      state: TransferState(
        inputAmountCurrencyCode: 'sats',
        fiatCurrencyCodes: const ['CAD', 'USD'],
        fiatCurrencyCode: 'CAD',
        exchangeRate: 100000,
        fromWallet: _LiquidWallet(),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    final sheet = find.byType(CurrencyBottomSheet);
    expect(find.text('Currency'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('L-BTC')),
      findsWidgets,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('L-sats')),
      findsWidgets,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('CAD')),
      findsNothing,
    );
  });

  testWidgets('fiat arrow only offers supported fiat currencies', (
    tester,
  ) async {
    await pumpInput(
      tester,
      state: const TransferState(
        inputAmountCurrencyCode: 'CAD',
        fiatCurrencyCodes: ['CAD', 'USD'],
        fiatCurrencyCode: 'CAD',
        exchangeRate: 100000,
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    final sheet = find.byType(CurrencyBottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Canada')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('United States')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('BTC')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('sats')),
      findsNothing,
    );
  });

  testWidgets('normalizes selected Liquid units before dispatching', (
    tester,
  ) async {
    when(
      () => bloc.add(const TransferEvent.amountCurrencyChanged('BTC')),
    ).thenReturn(null);
    await pumpInput(
      tester,
      state: TransferState(
        inputAmountCurrencyCode: 'sats',
        fiatCurrencyCodes: const ['CAD'],
        fiatCurrencyCode: 'CAD',
        fromWallet: _LiquidWallet(),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('L-BTC').first);
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(const TransferEvent.amountCurrencyChanged('BTC')),
    ).called(1);
  });

  testWidgets('switcher toggles Bitcoin input to selected fiat', (
    tester,
  ) async {
    when(
      () => bloc.add(const TransferEvent.amountCurrencyChanged('CAD')),
    ).thenReturn(null);
    await pumpInput(tester);

    await tester.tap(find.byIcon(Icons.swap_vert));

    verify(
      () => bloc.add(const TransferEvent.amountCurrencyChanged('CAD')),
    ).called(1);
  });

  testWidgets('dispatches Max selection through TransferBloc', (tester) async {
    when(
      () => bloc.add(const TransferEvent.maxAmountSelected()),
    ).thenReturn(null);
    await pumpInput(tester);

    await tester.tap(find.text('MAX'));

    verify(() => bloc.add(const TransferEvent.maxAmountSelected())).called(1);
  });

  testWidgets('shows Max as disabled when the wallet has no spendable funds', (
    tester,
  ) async {
    await pumpInput(
      tester,
      state: const TransferState(
        inputAmountCurrencyCode: 'CAD',
        fiatCurrencyCodes: ['CAD'],
        fiatCurrencyCode: 'CAD',
        exchangeRate: 100000,
        maxAmountSat: 0,
      ),
    );

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'MAX'),
    );
    final label = tester.widget<Text>(find.text('MAX'));
    final context = tester.element(find.byType(SwapAmountInput));

    expect(button.onPressed, isNull);
    expect(label.style?.color, context.appColors.onSurfaceVariant);
    expect(label.style?.color, isNot(context.appColors.primary));
  });
}
