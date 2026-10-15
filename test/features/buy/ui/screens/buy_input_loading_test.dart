import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_input_screen.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_amount_input_fields.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullFadingLinearProgress;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const BuyEvent.createOrder()));

  testWidgets(
    'order creation does not show a progress bar on the input screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = _MockBuyBloc();
      final states = StreamController<BuyState>.broadcast();
      addTearDown(states.close);
      var state = const BuyState(
        isStarted: true,
        userSummary: UserSummary(
          userNumber: 1,
          groups: ['KYC_IDENTITY_VERIFIED'],
          profile: UserProfile(firstName: 'Test', lastName: 'User'),
          email: 'test@example.com',
          balances: [],
          dca: UserDca(isActive: false),
          autoBuy: UserAutoBuy(
            isActive: false,
            addresses: UserAutoBuyAddresses(),
          ),
        ),
        isFiatCurrencyInput: false,
        bitcoinUnit: BitcoinUnit.sats,
        currencyInput: 'CAD',
        amountInput: '50000',
        exchangeRate: 100000,
        balances: {'CAD': 1000},
        bitcoinAddressInput: 'tb1qtest',
      );
      when(() => bloc.state).thenAnswer((_) => state);
      when(() => bloc.stream).thenAnswer((_) => states.stream);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<BuyBloc>.value(
              value: bloc,
              child: const BuyInputScreen(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pump();

      final amountFields = find.byType(BuyAmountInputFields);
      final continueButton = find.byWidgetPredicate(
        (widget) => widget is BullButton && widget.label == 'Continue',
      );
      final amountRect = tester.getRect(amountFields);
      final buttonRect = tester.getRect(continueButton);

      state = state.copyWith(isCreatingOrder: true);
      states.add(state);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BullFadingLinearProgress), findsNothing);
      expect(tester.getRect(amountFields), amountRect);
      expect(tester.getRect(continueButton), buttonRect);
      expect(tester.widget<BullButton>(continueButton).disabled, isTrue);
      await tester.tap(continueButton);
      verifyNever(() => bloc.add(any()));

      state = state.copyWith(isCreatingOrder: false);
      states.add(state);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BullFadingLinearProgress), findsNothing);
      expect(tester.getRect(amountFields), amountRect);
      expect(tester.getRect(continueButton), buttonRect);
      expect(tester.widget<BullButton>(continueButton).disabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
