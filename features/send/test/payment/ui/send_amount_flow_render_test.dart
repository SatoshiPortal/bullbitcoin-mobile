import 'dart:async';
import 'dart:io';

import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Sats;
import 'package:satoshifier/payment_request.dart';
import 'package:send/setup.dart' show SendLocalizations;
import 'package:send/src/payment/domain/send_amount_conversion.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:send/src/payment/ui/screens/send_screen.dart';
import 'package:send/src/payment/ui/send_payment_ui.dart';

import '../testing/send_source_fixture.dart';
import '../testing/send_test_localizations.dart';

final _workspace = File('assets/fonts/GolosText.ttf').existsSync()
    ? '.'
    : '../..';

late Uint8List _successBytes;

class _Send extends Mock implements SendCubit {}

void main() {
  final at = DateTime.utc(2026, 11, 19, 14, 32);
  final quotes = {
    SupportedCurrency.cad: BitcoinPrice(
      currency: SupportedCurrency.cad,
      fiatAmount: 125000,
      fetchedAt: at,
    ),
  };
  setUpAll(() async {
    _successBytes = await File('$_workspace/assets/animations/success_tick.gif')
        .readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('Golos Text')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$_workspace/assets/fonts/GolosText.ttf')
                  .readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final name in [
      'send-bitcoin',
      'send-fiat',
      'send-list',
      'send-no-price',
      'send-max',
      'send-confirm-bitcoin',
      'send-confirm-fiat',
      'multi',
      'multi-list',
    ]) {
      testWidgets('$name ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Device.screen = const Size(390, 844);
        final sendWallet = sendSourceFixture(
          id: 'bitcoin',
          network: BitcoinNetwork.mainnet,
          balanceSat: BigInt.from(1250000),
        );
        final send = _Send();
        final fiat = name.contains('fiat') || name == 'send-no-price';
        final confirmation = name.contains('confirm');
        final multi = name == 'multi' || name == 'multi-list';
        final max = name == 'send-max';
        final conversion = SendAmountConversion(
          enteredText: '31.25',
          currencyCode: 'CAD',
          rate: 125000,
          quotedAt: at,
          sats: Sats.fromInt(25000),
        );
        var sendState = SendState(
          step: confirmation ? SendStep.confirm : SendStep.amount,
          sendType: SendType.bitcoin,
          wallets: [sendWallet],
          selectedWallet: SendWalletBitcoin(sendWallet),
          paymentRequest: const PaymentRequest.bitcoin(
            address: 'bc1q7z9q2f4k8m3n5p6r7s8t9u0v2w3x4y5z6a7b8c',
            isTestnet: false,
          ),
          copiedRawPaymentRequest: 'bc1q7z9q2f4k8m3n5p6r7s8t9u0v2w3x4y5z6a7b8c',
          amount: max ? '1250000' : '25000',
          bitcoinUnit: BitcoinUnit.sats,
          inputAmountCurrencyCode: 'sats',
          fiatCurrencyCode: 'CAD',
          fiatCurrencyCodes: const ['CAD'],
          exchangeRate: 125000,
          amountQuotes: quotes,
          confirmedConversion: name == 'send-confirm-fiat' ? conversion : null,
          confirmedAmountSat: confirmation ? 25000 : null,
          bitcoinAbsoluteFeesSat: 420,
          recipientAmountsSat: max ? [1249580] : [],
          unsignedPsbt: confirmation ? 'unsigned' : null,
          recipientDrafts: [
            (
              id: 0,
              address: 'bc1q7z9q2f4k8m3n5p6r7s8t9u0v2w3x4y5z6a7b8c',
              amount: '25000',
              receivesRemainder: max,
              isValid: true,
            ),
            if (multi)
              (
                id: 1,
                address: 'bc1q5x2w8t3r6p9n4m7k0h2g5f8d3s6a9z4y7v0u2c',
                amount: '10000',
                receivesRemainder: false,
                isValid: true,
              ),
          ],
        );
        final sendStates = StreamController<SendState>.broadcast();
        addTearDown(sendStates.close);
        when(() => send.state).thenAnswer((_) => sendState);
        when(() => send.stream).thenAnswer((_) => sendStates.stream);
        when(() => send.isSpMode).thenReturn(false);
        when(() => send.preparedMaxAmountSat).thenReturn(max ? 1249580 : null);
        final Widget screen = confirmation
            ? const SendConfirmScreen()
            : const SendAmountScreen();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData(theme),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              ...sendTestLocalizationsDelegates,
            ],
            supportedLocales: SendLocalizations.supportedLocales,
            home: SendPaymentUi(
              openHome: (_) {},
              openCoins: (_, _) {},
              orderUnderReview: (_) => const SizedBox.shrink(),
              successImage: MemoryImage(_successBytes),
              child: BlocProvider<SendCubit>.value(
                value: send,
                child: BullAmountScope(
                  snapshot: BullAmountSnapshot(
                    unit: BitcoinUnit.sats,
                    hideAmounts: false,
                    isReady: true,
                    defaultCurrencyCode: 'CAD',
                    startInFiat: fiat,
                  ),
                  writeUnit: (_) async => true,
                  writeInputMode: (_) async => true,
                  child: screen,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (name == 'send-no-price') {
          sendState = sendState.copyWith(
            amountQuotes: const {},
            amountEntryValid: false,
          );
          sendStates.add(sendState);
          await tester.pumpAndSettle();
          expect(find.text('31.25'), findsOneWidget);
          expect(
            tester
                .widgetList<BullButton>(find.byType(BullButton))
                .singleWhere((button) => button.label == 'Continue')
                .disabled,
            isTrue,
          );
        }
        if (name == 'send-list') {
          await tester.tap(find.byTooltip('Currency: Bitcoin'));
          await tester.pumpAndSettle();
        }
        if (name == 'multi-list') {
          await tester.tap(find.byTooltip('Currency'));
          await tester.pumpAndSettle();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
