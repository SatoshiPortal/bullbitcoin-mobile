import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/receive/domain/receive_amount_conversion.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_amount_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/send/domain/send_amount_conversion.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_page.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Sats;

class _Send extends Mock implements SendCubit {}

class _Receive extends Mock implements ReceiveBloc {}

class _Transfer extends Mock implements TransferBloc {}

class _Settings extends Mock implements SettingsCubit {}

Wallet _wallet(bool liquid) => Wallet(
  origin: liquid ? 'liquid' : 'bitcoin',
  network: liquid ? Network.liquidMainnet : Network.bitcoinMainnet,
  xpubFingerprint: liquid ? '11111111' : '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1250000),
);

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
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
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
      'receive-fiat',
      'receive-qr',
      'swap',
      'multi',
      'multi-list',
    ]) {
      testWidgets('$name ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Device.screen = const Size(390, 844);
        final wallet = _wallet(false);
        final liquid = _wallet(true);
        final send = _Send();
        final receive = _Receive();
        final transfer = _Transfer();
        final settings = _Settings();
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
          wallets: [wallet],
          selectedWallet: SendWalletBitcoin(wallet),
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
        when(() => receive.state).thenReturn(
          ReceiveState(
            wallet: wallet,
            wallets: [wallet],
            walletAdmitted: true,
            type: ReceiveType.bitcoin,
            bitcoinUnit: BitcoinUnit.sats,
            inputAmountCurrencyCode: 'sats',
            inputAmount: '10000',
            fiatCurrencyCode: 'CAD',
            amountQuotes: quotes,
            confirmedAmountSat: 10000,
            confirmedConversion: ReceiveAmountConversion(
              enteredText: '12.50',
              currencyCode: 'CAD',
              rate: 125000,
              quotedAt: at,
              sats: Sats.fromInt(10000),
            ),
          ),
        );
        when(() => receive.stream).thenAnswer((_) => const Stream.empty());
        when(() => transfer.state).thenReturn(
          TransferState(
            wallets: [wallet, liquid],
            fromWallet: liquid,
            toWallet: wallet,
            bitcoinUnit: BitcoinUnit.sats,
            amount: '25000',
            amountQuotes: quotes,
            fiatCurrencyCode: 'CAD',
            exchangeRate: 125000,
            maxAmountSat: 1249580,
          ),
        );
        when(() => transfer.stream).thenAnswer((_) => const Stream.empty());
        when(() => settings.state).thenReturn(
          const SettingsState(
            storedSettings: SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'CAD',
              hideAmounts: false,
            ),
          ),
        );
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        final Widget screen;
        if (name == 'receive-fiat') {
          screen = const Scaffold(body: ReceiveAmountScreen());
        } else if (name == 'receive-qr') {
          screen = const Scaffold(body: Center(child: ReceiveInfoDetails()));
        } else if (name == 'swap') {
          screen = const SwapPage();
        } else {
          screen = confirmation
              ? const SendConfirmScreen()
              : const SendAmountScreen();
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('golden'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData(theme),
              localizationsDelegates: const [
                bullUiLocalizationsDelegate,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<SendCubit>.value(value: send),
                  BlocProvider<ReceiveBloc>.value(value: receive),
                  BlocProvider<TransferBloc>.value(value: transfer),
                  BlocProvider<SettingsCubit>.value(value: settings),
                ],
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
        final images = <ImageProvider<Object>>{
          ...tester
              .widgetList<Image>(find.byType(Image))
              .map((widget) => widget.image),
          ...tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .map((decoration) => decoration.image?.image)
              .whereType<ImageProvider<Object>>(),
        };
        final context = tester.element(find.byType(Scaffold).first);
        await tester.runAsync(() async {
          await Future.wait(
            images.map((image) => precacheImage(image, context)),
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('golden')),
          matchesGoldenFile('goldens/flow-$name-${theme.name}.png'),
        );
      });
    }
  }
}
