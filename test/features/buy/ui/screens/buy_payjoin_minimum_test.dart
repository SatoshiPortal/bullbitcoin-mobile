import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_input_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

class _MockWallet extends Mock implements Wallet {}

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(const BuyEvent.payjoinToggled(true));
  });

  for (final amount in [49999, 50000]) {
    testWidgets('buy toggle and minimum snackbar at $amount sats', (
      tester,
    ) async {
      final bloc = _MockBuyBloc();
      final wallet = _MockWallet();
      when(() => wallet.id).thenReturn('wallet');
      when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
      when(() => wallet.isDefault).thenReturn(false);
      when(() => wallet.displayLabel(any())).thenReturn('Bitcoin');
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bloc.state).thenReturn(
        BuyState(
          userSummary: const UserSummary(
            userNumber: 1,
            groups: [],
            profile: UserProfile(firstName: 'Test', lastName: 'User'),
            email: 'test@example.com',
            balances: [],
            dca: UserDca(isActive: false),
            autoBuy: UserAutoBuy(
              isActive: false,
              addresses: UserAutoBuyAddresses(),
            ),
            payjoinReceiveEnabled: true,
          ),
          selectedWallet: wallet,
          wallets: [wallet],
          payjoinGloballyEnabled: true,
          isFiatCurrencyInput: false,
          bitcoinUnit: BitcoinUnit.sats,
          currencyInput: 'CAD',
          amountInput: '$amount',
        ),
      );
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

      final toggle = tester.widget<BullSwitch>(find.byType(BullSwitch));
      expect(toggle.value, amount >= 50000);
      expect(toggle.onChanged == null, amount < 50000);
      await tester.tap(find.byType(BullSwitch));
      await tester.pump(const Duration(milliseconds: 300));

      const message =
          'The minimum amount for Payjoin with the exchange is 50,000 sats.';
      if (amount < 50000) {
        expect(find.text(message), findsOneWidget);
        verifyNever(() => bloc.add(any()));
        SnackBarUtils.dismiss();
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));
      } else {
        expect(find.text(message), findsNothing);
        verify(() => bloc.add(const BuyEvent.payjoinToggled(false))).called(1);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
