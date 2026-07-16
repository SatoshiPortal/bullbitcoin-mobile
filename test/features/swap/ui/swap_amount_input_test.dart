import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_amount_input.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

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

  testWidgets('opens the existing currency sheet when currency is tapped', (
    tester,
  ) async {
    await pumpInput(tester);

    await tester.tap(find.text('sats'));
    await tester.pumpAndSettle();

    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('BTC'), findsWidgets);
    expect(find.text('CAD'), findsWidgets);
  });

  testWidgets('dispatches the selected currency from the sheet', (
    tester,
  ) async {
    when(
      () => bloc.add(const TransferEvent.amountCurrencyChanged('CAD')),
    ).thenReturn(null);
    await pumpInput(tester);

    await tester.tap(find.text('sats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canada'));
    await tester.pumpAndSettle();

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
}
