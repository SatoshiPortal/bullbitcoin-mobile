import 'package:send/generated/l10n/send_localizations.dart'
    show lookupSendLocalizations;

import '../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;
import 'package:primitives/primitives.dart' show BitcoinNetwork, LiquidNetwork;

import '../testing/send_source_fixture.dart';

import 'package:go_router/go_router.dart';

import 'dart:async';

// The legacy screen already has a public shell import target.
import 'package:send/src/payment/ui/screens/send_payment_page.dart';
import 'package:send/src/payment/ui/screens/send_screen.dart';
import 'package:send/src/payment/ui/send_payment_ui.dart';
import 'package:sync/sync.dart' show WalletKey;

import 'package:fees/fees.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:send/src/payment/ui/screens/send_payment_review.dart';
import 'package:send/src/payment/domain/send_amount_conversion.dart';
import 'package:primitives/primitives.dart' show Sats;
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:send/generated/l10n/send_localizations_en.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart' show Device;
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Cubit extends Mock implements SendCubit {}

class _DuplicateFeeLabels extends SendLocalizationsEn {
  @override
  String get sendFastFee => 'Same preset label';

  @override
  String get sendEconomyFee => 'Same preset label';
}

class _DuplicateFeeLabelsDelegate
    extends LocalizationsDelegate<SendLocalizations> {
  const _DuplicateFeeLabelsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<SendLocalizations> load(Locale locale) =>
      SynchronousFuture(_DuplicateFeeLabels());

  @override
  bool shouldReload(_DuplicateFeeLabelsDelegate old) => false;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const RelativeFee(500));
    registerFallbackValue(FeeSelection.fastest);
  });
  final wallet = sendSourceFixture(
    id: 'mono',
    network: BitcoinNetwork.mainnet,
    signerDevice: null,
    balanceSat: BigInt.from(1000000),
  );
  final regtestWallet = sendSourceFixture(
    id: 'mono-regtest',
    network: BitcoinNetwork.regtest,
    signerDevice: null,
    balanceSat: BigInt.from(1000000),
  );
  SendState state({
    SendStep step = SendStep.amount,
    bool max = false,
    bool regtest = false,
    PaymentRequest request = const PaymentRequest.bitcoin(
      address: 'bc1qfixture',
      isTestnet: false,
    ),
  }) => SendState(
    step: step,
    selectedWallet: SendWalletBitcoin(regtest ? regtestWallet : wallet),
    paymentRequest: request,
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
        address: regtest ? 'bcrt1qfixture' : 'bc1qfixture',
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
    GoRouter? router,
    Locale? locale,
    LocalizationsDelegate<SendLocalizations>? localizationOverride,
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
      BlocProvider<SendCubit>.value(
        value: cubit,
        child: MaterialApp.router(
          locale: locale,
          builder: (context, child) => SendPaymentUi(
            openHome: (context) => GoRouter.of(context).go('/'),
            openCoins: (context, wallet) =>
                GoRouter.of(context)
                    .pushReplacementNamed('coins', extra: wallet),
            orderUnderReview: (_) => const SizedBox.shrink(),
            arrowImage: const AssetImage('unused-arrow'),
            successImage: const AssetImage('unused-success'),
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig:
              router ??
              GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => BlocProvider<SendCubit>.value(
                      value: cubit,
                      child: const SendScreen(),
                    ),
                  ),
                ],
              ),
          theme: ThemeData(
            extensions: testBullExtensions,
            textTheme: testBullTypography.toTextTheme(),
          ),
          localizationsDelegates: [
            ?localizationOverride,
            ...bullUiLocalizationsDelegates,
            ...sendTestLocalizationsDelegates,
          ],
          supportedLocales: SendLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('a bare regtest address uses the redesigned Send page', (
    tester,
  ) async {
    await pump(
      tester,
      state(
        regtest: true,
        request: const PaymentRequest.bip21(
          network: BitcoinNetwork.regtest,
          uri: 'bcrt1qfixture',
          address: 'bcrt1qfixture',
        ),
      ),
    );

    expect(find.byType(SendPaymentPage), findsOneWidget);
  });

  testWidgets('Continue confirms a recipient kept after Edit', (tester) async {
    final cubit = await pump(tester, state(step: SendStep.address));
    when(cubit.continueOnAddressConfirmed).thenAnswer((_) async {});

    expect(find.byType(SendPaymentPage), findsOneWidget);
    final button = find.widgetWithText(BullButton, 'Continue');
    expect(tester.widget<BullButton>(button).disabled, isFalse);
    await tester.tap(button);
    verify(cubit.continueOnAddressConfirmed).called(1);
  });

  testWidgets('From lists the Liquid wallet without subtitles', (tester) async {
    final liquid = sendSourceFixture(
      id: 'mono-liquid',
      network: LiquidNetwork.mainnet,
      balanceSat: BigInt.from(1000000),
      label: 'Instant',
    );
    await pump(
      tester,
      state().copyWith(
        wallets: [
          sendSourceFixture(
            id: 'mono',
            network: BitcoinNetwork.mainnet,
            balanceSat: BigInt.from(1000000),
            label: 'Secure',
          ),
          liquid,
        ],
      ),
    );

    await tester.tap(find.text('Secure'));
    await tester.pumpAndSettle();
    expect(find.text('Instant'), findsWidgets);
    expect(find.textContaining('Secure Bitcoin wallet'), findsNothing);
  });

  testWidgets('a plain Liquid payment confirms on the shared review', (
    tester,
  ) async {
    final liquid = sendSourceFixture(
      id: 'liquid',
      network: LiquidNetwork.mainnet,
      balanceSat: BigInt.from(4909),
      label: 'Instant payments',
    );
    await pump(
      tester,
      state(step: SendStep.confirm).copyWith(
        sendType: SendType.liquid,
        selectedWallet: SendWalletBitcoin(liquid),
        paymentRequest: const PaymentRequest.liquid(
          address: 'lq1qqwzrpfmt9d7tx76jq6lgr7ylkg',
          isTestnet: false,
        ),
        recipientDrafts: [],
        recipientAmountsSat: [],
        confirmedAmountSat: 1000,
        liquidAbsoluteFees: 26,
      ),
    );

    expect(find.byType(SendPaymentReview), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.byType(SendConfirmScreen), findsNothing);
  });

  testWidgets('the classic amount step chooses the fee in Advanced settings', (
    tester,
  ) async {
    Device.screen = const Size(390, 844);
    await pump(
      tester,
      state().copyWith(
        recipientDrafts: [
          (
            id: 0,
            address: 'bc1qfixture',
            amount: '',
            receivesRemainder: true,
            isValid: true,
          ),
          (
            id: 1,
            address: 'bc1qsecond',
            amount: '2000',
            receivesRemainder: false,
            isValid: true,
          ),
        ],
        recipientAmountsSat: [8000, 2000],
      ),
    );
    expect(find.byType(SendPaymentPage), findsNothing);

    await tester.tap(
      find.widgetWithText(BullSettingsEntryTile, 'Advanced settings'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Replace-by-fee activated'), findsOneWidget);
    expect(find.text('Multiple recipients'), findsNothing);
  });

  testWidgets('several recipients confirm on the shared review', (
    tester,
  ) async {
    await pump(
      tester,
      state(step: SendStep.confirm).copyWith(
        recipientDrafts: [
          (
            id: 0,
            address: 'bc1qfixture',
            amount: '',
            receivesRemainder: true,
            isValid: true,
          ),
          (
            id: 1,
            address: 'bc1qsecond',
            amount: '2000',
            receivesRemainder: false,
            isValid: true,
          ),
        ],
        recipientAmountsSat: [8000, 2000],
        confirmedAmountSat: 10000,
      ),
    );

    expect(find.byType(SendPaymentReview), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('2,000'), findsWidgets);
  });

  testWidgets('a watch-only Liquid payment keeps the classic confirmation', (
    tester,
  ) async {
    Device.screen = const Size(390, 844);
    final liquid = sendSourceFixture(
      id: 'liquid-watch',
      network: LiquidNetwork.mainnet,
      balanceSat: BigInt.from(4909),
      signer: WalletSigner.none,
    );
    await pump(
      tester,
      state(step: SendStep.confirm).copyWith(
        sendType: SendType.liquid,
        selectedWallet: SendWalletBitcoin(liquid),
        paymentRequest: const PaymentRequest.liquid(
          address: 'lq1qqwzrpfmt9d7tx76jq6lgr7ylkg',
          isTestnet: false,
        ),
        recipientDrafts: [],
        recipientAmountsSat: [],
        confirmedAmountSat: 1000,
        liquidAbsoluteFees: 26,
      ),
    );

    // The shared review has no PSBT or device action.
    expect(find.byType(SendPaymentReview), findsNothing);
    expect(find.byType(SendConfirmScreen), findsOneWidget);
  });

  testWidgets('a regtest payment URI keeps the legacy Send page', (
    tester,
  ) async {
    Device.screen = const Size(390, 844);
    await pump(
      tester,
      state(
        regtest: true,
        request: const PaymentRequest.bip21(
          network: BitcoinNetwork.regtest,
          uri: 'bitcoin:bcrt1qfixture?label=shop',
          address: 'bcrt1qfixture',
          label: 'shop',
        ),
      ),
    );

    expect(find.byType(SendPaymentPage), findsNothing);
    expect(find.byType(SendAmountScreen), findsOneWidget);
  });

  testWidgets('identical fee labels keep distinct preset actions', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      state(),
      localizationOverride: const _DuplicateFeeLabelsDelegate(),
    );
    when(() => cubit.feeOptionSelected(any())).thenAnswer((_) async {});
    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();

    final duplicate = find.descendant(
      of: find.byType(BullSegmented),
      matching: find.text('Same preset label'),
    );
    expect(duplicate, findsNWidgets(2));
    await tester.tap(duplicate.at(1));
    await tester.pumpAndSettle();
    await tester.tap(duplicate.at(0));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => cubit.feeOptionSelected(FeeSelection.economic),
      () => cubit.feeOptionSelected(FeeSelection.fastest),
    ]);
  });

  testWidgets('Multiple recipients opens the recipient list', (tester) async {
    await pump(tester, state(step: SendStep.address));

    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multiple recipients'));
    await tester.pumpAndSettle();

    expect(find.byType(SendPaymentPage), findsNothing);
    expect(find.byType(SendAddressScreen), findsOneWidget);
  });

  testWidgets('Send UTXOs instead asks for an address first', (tester) async {
    await pump(
      tester,
      state(step: SendStep.address).copyWith(
        selectedWallet: null,
        paymentRequest: null,
        amount: '',
        recipientDrafts: [],
        recipientAmountsSat: [],
      ),
    );
    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send UTXOs instead'));
    await tester.pump();
    expect(find.text('Enter an address first'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('Advanced settings opens and reopens without a wallet', (
    tester,
  ) async {
    await pump(
      tester,
      state(step: SendStep.address).copyWith(
        selectedWallet: null,
        paymentRequest: null,
        amount: '',
        confirmedAmountSat: null,
        bitcoinFeesList: null,
        bitcoinAbsoluteFeesSat: null,
        feePreviewCache: BitcoinFeePreviewCache.empty,
        recipientDrafts: [],
        recipientAmountsSat: [],
      ),
    );
    expect(tester.takeException(), isNull);

    for (var opening = 0; opening < 2; opening++) {
      await tester.tap(find.byType(BullSettingsEntryTile));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Send UTXOs instead'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\b(?:sats|sat/vB)\b')), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Send UTXOs instead'), findsNothing);
    }
  });

  testWidgets(
    'Advanced fee summary has single-spaced separators and no layout gaps',
    (tester) async {
      await pump(tester, state());
      await tester.tap(find.byType(BullSettingsEntryTile));
      await tester.pumpAndSettle();
      final line = find
          .ancestor(
            of: find.text('~10 min · 2 sat/vB'),
            matching: find.byType(Wrap),
          )
          .first;
      expect(tester.widget<Wrap>(line).spacing, 0);
      final text = tester
          .widgetList<Text>(
            find.descendant(of: line, matching: find.byType(Text)),
          )
          .map((text) => text.data ?? '')
          .join();
      expect(text, '~10 min · 2 sat/vB · 200 sats');
    },
  );

  testWidgets(
    'Coins leave Cancel preserves payment; Open replaces Send and Back returns origin',
    (tester) async {
      Object? source;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Origin')),
          ),
          GoRoute(path: '/send', builder: (_, _) => const SendScreen()),
          GoRoute(
            path: '/coins',
            name: 'coins',
            builder: (_, state) {
              source = state.extra;
              return const Scaffold(body: Text('Coins destination'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      final cubit = await pump(tester, state(), router: router);
      router.push('/send');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send UTXOs instead'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this payment?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cubit.state.amount, '10000');
      expect(source, isNull);
      expect(find.text('Advanced settings'), findsWidgets);
      await tester.tap(find.text('Send UTXOs instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Coins'));
      await tester.pumpAndSettle();
      expect(source, WalletKey(id: wallet.id, network: wallet.network));
      expect(find.byType(SendScreen), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Origin'), findsOneWidget);
      expect(find.byType(SendScreen), findsNothing);
    },
  );

  testWidgets(
    'confirmation absolute effective rate uses final fee and size, not cached quote',
    (tester) async {
      await pump(
        tester,
        state(step: SendStep.confirm).copyWith(
          selectedFeeOption: FeeSelection.custom,
          customFee: const AbsoluteFee(300),
          bitcoinAbsoluteFeesSat: 300,
          bitcoinTxSize: 150,
          feePreviewCache: const BitcoinFeePreviewCache(
            custom: BitcoinFeePreviewSlot(feeSat: 100, txSize: 100),
          ),
        ),
      );
      expect(find.text('300 sats'), findsOneWidget);
      expect(find.text('Custom · 2 sat/vB'), findsOneWidget);
      expect(find.textContaining('1 sat/vB'), findsNothing);
    },
  );

  testWidgets('mono Confirm retains signing and broadcast admission guards', (
    tester,
  ) async {
    await pump(
      tester,
      state(step: SendStep.confirm).copyWith(signingTransaction: true),
    );
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
  });

  testWidgets('mono Confirm starts one animated payment for repeated taps', (
    tester,
  ) async {
    final cubit = await pump(
      tester,
      state(step: SendStep.confirm).copyWith(sendType: SendType.bitcoin),
    );
    final pending = Completer<void>();
    when(cubit.onConfirmTransactionClicked).thenAnswer((_) => pending.future);
    final confirm = tester.widget<BullButton>(find.byType(BullButton));

    confirm.onPressed();
    confirm.onPressed();
    await tester.pump();

    expect(find.byType(BullPaymentTransition), findsOneWidget);
    verify(cubit.onConfirmTransactionClicked).called(1);

    pending.complete();
    await tester.pump();
    expect(find.byType(BullPaymentTransition), findsNothing);
  });

  testWidgets('mono MAX review shows the actual drain recipient amount', (
    tester,
  ) async {
    await pump(
      tester,
      state(
        step: SendStep.confirm,
        max: true,
      ).copyWith(confirmedAmountSat: 999800),
    );
    expect(find.text('80,000 sats'), findsOneWidget);
    expect(find.text('80,200 sats'), findsOneWidget);
  });
  testWidgets('mono Total uses the real current preset preview size', (
    tester,
  ) async {
    await pump(tester, state());
    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total (sats)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BullInputText),
        matching: find.byType(TextField),
      ),
      '200',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BullInputText>(find.byType(BullInputText)).onDone,
      isNotNull,
    );
  });
  testWidgets('mono unchanged Custom submit invalidates an old Custom PSBT', (
    tester,
  ) async {
    final cubit = await pump(tester, state());
    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BullInputText),
        matching: find.byType(TextField),
      ),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    verifyInOrder([
      () => cubit.armCustomFee(const RelativeFee(500)),
      () => cubit.customFeesChanged(const RelativeFee(500)),
    ]);
  });
  testWidgets('mono untouched Custom cancellation preserves a MAX preview', (
    tester,
  ) async {
    final cubit = await pump(tester, state(max: true));
    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    verifyNever(cubit.clearBitcoinFeePreviews);
  });
  testWidgets(
    'mono Confirm blocks a retained fee during broadcast or failure',
    (tester) async {
      for (final value in [
        state(step: SendStep.confirm).copyWith(broadcastingTransaction: true),
        state(step: SendStep.confirm)
            .copyWith(failure: const SendInsufficientFundsForFeesFailure()),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await pump(tester, value);
        expect(
          tester.widget<BullButton>(find.byType(BullButton)).disabled,
          isTrue,
        );
      }
    },
  );
  const failureLocale = Locale('fr');
  final failureLabels = lookupSendLocalizations(failureLocale);
  for (final (kind, failure, messages) in <(String, SendFailure, List<String>)>[
    (
      'build',
      const SendTransactionBuildFailure('internal build detail'),
      [failureLabels.sendErrorBuildFailed],
    ),
    (
      'confirmation',
      const SendTransactionConfirmationFailure(
        logMessage: 'internal signing detail',
      ),
      [failureLabels.sendErrorConfirmationFailed],
    ),
    (
      'broadcast',
      const SendTransactionConfirmationFailure(
        isBroadcastFailure: true,
        logMessage: 'internal broadcast detail',
      ),
      [
        failureLabels.sendErrorConfirmationFailed,
        failureLabels.sendErrorBroadcastFailed,
      ],
    ),
  ]) {
    testWidgets('mono review presents localized $kind failure', (tester) async {
      await pump(
        tester,
        state(step: SendStep.confirm).copyWith(failure: failure),
        locale: failureLocale,
      );

      for (final message in messages) {
        expect(find.text(message).hitTestable(), findsOneWidget);
      }
      expect(find.textContaining('internal '), findsNothing);
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        failure is SendTransactionBuildFailure,
      );
    });
  }

  testWidgets(
    'mono review warns only when the legacy fee threshold is exceeded',
    (tester) async {
      final incoming = StreamController<SendState>.broadcast(sync: true);
      addTearDown(incoming.close);
      final ordinary = state(step: SendStep.confirm);
      expect(ordinary.showFeeWarning, isFalse);
      await pump(tester, ordinary, updates: incoming.stream);

      final warning = find.text('High fee warning');
      expect(warning, findsNothing);

      final boundary = ordinary.copyWith(bitcoinAbsoluteFeesSat: 500);
      expect(boundary.showFeeWarning, isFalse);
      incoming.add(boundary);
      await tester.pumpAndSettle();
      expect(warning, findsNothing);

      final high = ordinary.copyWith(bitcoinAbsoluteFeesSat: 600);
      expect(high.showFeeWarning, isTrue);
      incoming.add(high);
      await tester.pumpAndSettle();
      expect(warning.hitTestable(), findsOneWidget);
      expect(
        find.text('Total fee is 6.00% of the amount you are sending'),
        findsOneWidget,
      );
      expect(
        tester.widget<BullButton>(find.byType(BullButton)).disabled,
        isFalse,
      );

      incoming.add(ordinary);
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mono fiat review retains entered amount and rate time', (
    tester,
  ) async {
    await pump(
      tester,
      state(step: SendStep.confirm).copyWith(
        confirmedAmountSat: 25000,
        confirmedConversion: SendAmountConversion(
          enteredText: '31.25',
          currencyCode: 'CAD',
          rate: 125000,
          quotedAt: DateTime.utc(2026, 11, 19, 14, 32),
          sats: Sats.fromInt(25000),
        ),
      ),
    );
    expect(find.text('You entered 31.25 CAD · rate of 14:32'), findsOneWidget);
  });
  testWidgets('mono Total adopts a slow preset preview without reopening', (
    tester,
  ) async {
    final updates = StreamController<SendState>.broadcast(sync: true);
    addTearDown(updates.close);
    final initial = state().copyWith(
      feePreviewCache: BitcoinFeePreviewCache.empty,
    );
    await pump(tester, initial, updates: updates.stream);
    await tester.tap(find.byType(BullSettingsEntryTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total (sats)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BullInputText),
        matching: find.byType(TextField),
      ),
      '200',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BullInputText>(find.byType(BullInputText)).onDone,
      isNull,
    );
    updates.add(initial.copyWith(feePreviewCache: state().feePreviewCache));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BullInputText>(find.byType(BullInputText)).onDone,
      isNotNull,
    );
  });
}
