import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:receive/testing.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Receive extends Mock implements ReceiveBloc {}

void main() {
  testWidgets(
    'a network reset replaces the canonical text, never the previous request',
    (tester) async {
      final bloc = _Receive();
      final states = StreamController<ReceiveState>.broadcast();
      addTearDown(states.close);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var state = const ReceiveState(
        type: ReceiveType.bitcoin,
        walletAdmitted: true,
        inputAmount: '10000',
        inputAmountCurrencyCode: 'sats',
        fiatCurrencyCode: 'CAD',
      );
      when(() => bloc.state).thenAnswer((_) => state);
      when(() => bloc.stream).thenAnswer((_) => states.stream);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: bullUiLocalizationsDelegates,
          supportedLocales: BullUiLocalizations.supportedLocales,
          home: BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: Scaffold(body: ReceiveAmountInput(focusNode: focus)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      TextEditingController canonical() => tester
          .widget<BullAmountInput>(find.byType(BullAmountInput))
          .amountController;
      expect(canonical().text, '10000');
      state = state.copyWith(
        type: ReceiveType.liquid,
        inputAmount: '',
        walletAdmitted: false,
      );
      states.add(state);
      await tester.pumpAndSettle();
      expect(canonical().text, isEmpty);
      state = state.copyWith(inputAmount: '5000', walletAdmitted: true);
      states.add(state);
      await tester.pumpAndSettle();
      expect(canonical().text, '5000');
    },
  );

  testWidgets('the amount cannot be edited while the request is created', (
    tester,
  ) async {
    final bloc = _Receive();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    const state = ReceiveState(
      type: ReceiveType.lightning,
      walletAdmitted: true,
      inputAmount: '1000',
      inputAmountCurrencyCode: 'sats',
      fiatCurrencyCode: 'CAD',
      creatingSwap: true,
    );
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: bullUiLocalizationsDelegates,
        supportedLocales: BullUiLocalizations.supportedLocales,
        home: BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: Scaffold(body: ReceiveAmountInput(focusNode: focus)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BullAmountInput>(find.byType(BullAmountInput)).readOnly,
      isTrue,
    );
  });
}
