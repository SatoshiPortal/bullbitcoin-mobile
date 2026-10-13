import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_action_buttons.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendCubit extends Mock implements SendCubit {}

void main() {
  testWidgets('Silent Payments confirmation needs no descriptor wallet', (
    tester,
  ) async {
    final cubit = _MockSendCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.isSpMode).thenReturn(true);
    when(() => cubit.state).thenReturn(
      SendState(
        step: SendStep.confirm,
        sendType: SendType.bitcoin,
        selectedWallet: SendWalletSp(
          label: 'Silent Payments',
          network: Network.bitcoinMainnet,
          balanceSat: BigInt.from(20000),
        ),
        paymentRequest: const PaymentRequest.bitcoin(
          address: 'bc1-recipient',
          isTestnet: false,
        ),
        amount: '1000',
        inputAmountCurrencyCode: 'sats',
        bitcoinUnit: BitcoinUnit.sats,
        confirmedAmountSat: 1000,
        bitcoinAbsoluteFeesSat: 100,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendConfirmScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ConfirmSendButton), findsOneWidget);
    expect(find.byType(ShowPsbtButton), findsNothing);
  });
}
