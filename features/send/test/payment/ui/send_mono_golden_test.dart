import '../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;
import 'package:primitives/primitives.dart' show BitcoinNetwork;

import '../testing/send_source_fixture.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:bull_pricer/bull_pricer.dart';

import 'package:send/src/payment/ui/widgets/send_whole_balance_dialog.dart';

// The legacy screen already has a public shell import target.
import 'package:send/src/payment/ui/screens/send_screen.dart';
import 'package:send/src/payment/ui/send_payment_ui.dart';

import 'package:fees/fees.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/send_amount_conversion.dart';
import 'package:primitives/primitives.dart' show Sats;
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

final _workspace = File('assets/fonts/GolosText.ttf').existsSync()
    ? '.'
    : '../..';

late Uint8List _arrowBytes;
late Uint8List _successBytes;

class _Cubit extends Mock implements SendCubit {}

void main() {
  setUpAll(() async {
    _arrowBytes = await File('$_workspace/assets/icons/right-arrow.png')
        .readAsBytes();
    _successBytes = await File('$_workspace/assets/animations/success_tick.gif')
        .readAsBytes();
    registerFallbackValue(const RelativeFee(500));
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
  final wallet = sendSourceFixture(
    id: 'mono',
    label: 'bitcoin',
    network: BitcoinNetwork.mainnet,
    signerDevice: null,
    balanceSat: BigInt.from(1000000),
  );
  SendState state({SendStep step = SendStep.amount, bool max = false}) =>
      SendState(
        step: step,
        selectedWallet: SendWalletBitcoin(wallet),
        paymentRequest: const PaymentRequest.bitcoin(
          address: 'bc1qfixture',
          isTestnet: false,
        ),
        bitcoinUnit: BitcoinUnit.sats,
        inputAmountCurrencyCode: 'sats',
        amount: '10000',
        confirmedAmountSat: 10000,
        bitcoinAbsoluteFeesSat: 200,
        bitcoinFeesList: const FeeOptions(
          fastest: RelativeFee(500),
          economic: RelativeFee(250),
          slow: RelativeFee(125),
          minRelay: RelativeFee(25),
        ),
        feePreviewCache: const BitcoinFeePreviewCache(
          fastest: BitcoinFeePreviewSlot(
            feeSat: 200,
            txSize: 140,
            unsignedPsbt: 'current',
            recipientAmountsSat: [10000],
          ),
        ),
        recipientDrafts: [
          (
            id: 0,
            address: 'bc1qfixture',
            amount: '10000',
            receivesRemainder: max,
            isValid: true,
          ),
        ],
        recipientAmountsSat: max ? [80000] : [10000],
      );

  Future<_Cubit> pump(
    WidgetTester tester,
    SendState value, {
    Stream<SendState>? updates,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = _Cubit();
    when(() => cubit.state).thenReturn(value);
    when(() => cubit.stream)
        .thenAnswer((_) => updates ?? const Stream<SendState>.empty());
    final subscription = updates?.listen(
      (next) => when(() => cubit.state).thenReturn(next),
    );
    if (subscription != null) addTearDown(subscription.cancel);
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.preparedMaxAmountSat)
        .thenReturn(value.isMaxSend ? 80000 : null);
    when(() => cubit.customFeesChanged(any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('mono-review'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData(
            dark ? AppThemeType.dark : AppThemeType.light,
          ),
          localizationsDelegates: const [
            ...bullUiLocalizationsDelegates,
            ...sendTestLocalizationsDelegates,
          ],
          supportedLocales: SendLocalizations.supportedLocales,
          home: SendPaymentUi(
            openHome: (_) {},
            openCoins: (_, _) {},
            orderUnderReview: (_) => const SizedBox.shrink(),
            arrowImage: MemoryImage(_arrowBytes),
            successImage: MemoryImage(_successBytes),
            child: BlocProvider<SendCubit>.value(
              value: cubit,
              child: const SendScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  final at = DateTime.utc(2026, 11, 19, 14, 32);
  for (final dark in [false, true]) {
    for (final scene in [
      'recipient',
      'recipient-keyboard',
      'amount',
      'amount-max',
      'amount-keyboard',
      'settings',
      'custom-rate',
      'custom-total',
      'custom-invalid',
      'custom-warning',
      'max-dialog',
      'confirmation',
      'confirmation-fiat',
      'currency',
      'wallet-picker',
      'leave-payment',
    ]) {
      testWidgets('mono $scene ${dark ? 'dark' : 'light'}', (tester) async {
        var value = state(max: scene == 'amount-max').copyWith(
          exchangeRate: 125000,
          fiatCurrencyCode: 'CAD',
          fiatCurrencyCodes: ['CAD'],
          amountQuotes: {
            SupportedCurrency.cad: BitcoinPrice(
              currency: SupportedCurrency.cad,
              fiatAmount: 125000,
              fetchedAt: at,
            ),
          },
          wallets: [wallet],
        );
        const address = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
        value = value.copyWith(
          paymentRequest: const PaymentRequest.bitcoin(
            address: address,
            isTestnet: false,
          ),
          copiedRawPaymentRequest: address,
          recipientDrafts: [
            (
              id: 0,
              address: address,
              amount: '10000',
              receivesRemainder: scene == 'amount-max',
              isValid: true,
            ),
          ],
        );
        value = value.copyWith(
          bitcoinAbsoluteFeesSat: 280,
          bitcoinTxSize: 140,
          feePreviewCache: const BitcoinFeePreviewCache(
            fastest: BitcoinFeePreviewSlot(
              feeSat: 280,
              txSize: 140,
              unsignedPsbt: 'current',
              recipientAmountsSat: [10000],
            ),
          ),
        );
        if (scene.startsWith('custom-')) {
          value = value.copyWith(
            selectedFeeOption: FeeSelection.custom,
            customFee: const RelativeFee(500),
            feePreviewCache: value.feePreviewCache.withSlot(
              FeeSelection.custom,
              value.feePreviewCache.fastest,
            ),
          );
        }
        if (scene.startsWith('recipient')) {
          value = value.copyWith(
            step: SendStep.address,
            paymentRequest: null,
            copiedRawPaymentRequest: '',
            recipientDrafts: [],
            selectedWallet: null,
            amount: '',
          );
        }
        if (scene.startsWith('confirmation')) {
          value = value.copyWith(
            step: SendStep.confirm,
            confirmedConversion: scene == 'confirmation-fiat'
                ? SendAmountConversion(
                    enteredText: '12.50',
                    currencyCode: 'CAD',
                    rate: 125000,
                    quotedAt: at,
                    sats: Sats.fromInt(10000),
                  )
                : null,
          );
        }
        await pump(tester, value, dark: dark);
        if (scene == 'amount') {
          final expectedBorder = dark
              ? const Color(0xFF58585A)
              : const Color(0xFFC9CACD);
          final expectedFill = dark
              ? const Color(0xFF1C1C1E)
              : const Color(0xFFF5F5F5);
          for (final field in [
            find.byType(BullBorderedTile).first,
            find.byType(BullAmountInput),
          ]) {
            final decorations = tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: field,
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .map((widget) => widget.decoration)
                .whereType<BoxDecoration>();
            expect(
              decorations.any(
                (decoration) =>
                    decoration.color == expectedFill &&
                    decoration.border is Border &&
                    (decoration.border! as Border).top.color == expectedBorder,
              ),
              isTrue,
              reason: 'To and amount fields must share actual theme surface and border',
            );
          }
        }

        if (scene == 'settings' ||
            scene == 'leave-payment' ||
            scene.startsWith('custom-')) {
          await tester.tap(find.byType(BullSettingsEntryTile));
          await tester.pumpAndSettle();
        }
        if (scene == 'leave-payment') {
          await tester.tap(find.text('Send UTXOs instead'));
          await tester.pumpAndSettle();
        }
        if (scene.startsWith('custom-')) {
          await tester.tap(find.text('Custom').last);
          await tester.pumpAndSettle();
          if (scene == 'custom-total') {
            await tester.tap(find.text('Total (sats)'));
            await tester.pumpAndSettle();
          }
          final raw = scene == 'custom-total'
              ? '200'
              : scene == 'custom-invalid'
              ? '0.05'
              : scene == 'custom-warning'
              ? '0.5'
              : '2';
          await tester.enterText(
            find.descendant(
              of: find.byType(BullInputText),
              matching: find.byType(TextField),
            ),
            raw,
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
        }
        if (scene == 'amount-keyboard' || scene == 'recipient-keyboard') {
          await tester.tap(find.byType(TextField));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
        }
        if (scene == 'recipient-keyboard') {
          expect(
            tester.getBottomLeft(find.byType(TextField)).dy,
            lessThan(tester.getTopLeft(find.text('Continue')).dy),
          );
        }
        if (scene == 'currency') {
          await tester.tap(
            find
                .descendant(
                  of: find.byType(BullAmountInput),
                  matching: find.byType(BullFieldAction),
                )
                .last,
          );
          await tester.pumpAndSettle();
        }
        if (scene == 'wallet-picker') {
          await tester.tap(find.text('bitcoin').last);
          await tester.pumpAndSettle();
        }
        if (scene == 'max-dialog') {
          final context = tester.element(find.byType(SendScreen));
          unawaited(
            BullDialog.show<void>(
              context: context,
              builder: (dialogContext) => SendWholeBalanceDialog(
                title: 'Send your whole balance?',
                description: 'Everything in bitcoin leaves this wallet. The network fee is taken from it, so nothing stays.',
                balanceLabel: 'Balance',
                balance: const Text('1,000,000 sats'),
                feeLabel: 'Network fee · Fast',
                fee: const Text('− 280 sats'),
                receivesLabel: 'Recipient gets',
                receives: const Text('999,720 sats'),
                cancelLabel: 'Cancel',
                sendAllLabel: 'Send all',
                onCancel: () {},
                onSendAll: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        if (scene == 'amount-keyboard' || scene == 'recipient-keyboard') {
          // Paint another raster frame after the keyboard viewport settles.
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('mono-review')),
          matchesGoldenFile(
            'goldens/send-mono/$scene-${dark ? 'dark' : 'light'}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
