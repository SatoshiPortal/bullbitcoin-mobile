import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, FormatAmount, ScriptType;
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';

import 'dart:async';

import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmountScope,
        BullAmountSnapshot,
        BullAmountUnitToggle,
        BullAmountInput,
        BullButton,
        BullDropdown,
        bullUiLocalizationsDelegate;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../coins/wallet_utxo_fixture.dart';

class _MockSendCubit extends Mock implements SendCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Wallet _wallet() => Wallet(
  origin: 'wallet',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

void main() {
  testWidgets(
    'invalid canonical entry blocks Continue despite previous positive sats',
    (tester) async {
      final cubit = _MockSendCubit();
      final state = SendState(
        amount: '2500',
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
        amountEntryValid: false,
      );
      expect(state.effectiveAmountSat, greaterThan(0));
      expect(state.hasValidAmountEntry, isFalse);
      when(() => cubit.state).thenReturn(state);
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      final controller = TextEditingController(text: 'invalid');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: Scaffold(
              body: SendAmountConfirmButton(amountController: controller),
            ),
          ),
        ),
      );
      final action = find.widgetWithText(BullButton, 'Continue');
      expect(tester.widget<BullButton>(action).disabled, isTrue);
      await tester.tap(action, warnIfMissed: false);
      verifyNever(() => cubit.onAmountConfirmed());
      verifyNever(() => cubit.amountChanged(amount: any(named: 'amount')));
    },
  );

  for (final entry in <String, PaymentRequest>{
    'PSBT': const PaymentRequest.psbt(psbt: 'cHNidP8='),
    'Bitcoin address · 2,500 sats from the QR': const PaymentRequest.bip21(
      network: BitcoinNetwork.mainnet,
      uri: 'bitcoin:bc1qfirst?amount=0.000025',
      address: 'bc1qfirst',
      amountSat: 2500,
    ),
    'Lightning invoice · 2,500 sats': const PaymentRequest.bolt11(
      invoice: 'lnbc25u1fixture',
      amountSat: 2500,
      paymentHash: 'hash',
      expiresAt: 9999999999,
      isTestnet: false,
    ),
  }.entries) {
    testWidgets('destination card identifies ${entry.key}', (tester) async {
      final cubit = _MockSendCubit();
      when(() => cubit.isSpMode).thenReturn(false);
      when(() => cubit.state)
          .thenReturn(SendState(paymentRequest: entry.value));
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const Scaffold(body: AddressField()),
          ),
        ),
      );
      expect(find.text(entry.key), findsOneWidget);
    });
  }
  testWidgets('offers Add actions after enabling multiple recipients', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1600);
    final wallet = _wallet().copyWith(signer: SignerEntity.remote);
    final state = SendState(
      sendType: SendType.bitcoin,
      wallets: [wallet],
      selectedWallet: SendWalletBitcoin(wallet),
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      copiedRawPaymentRequest: 'bc1qfirst',
      recipientDrafts: const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '',
          receivesRemainder: false,
          isValid: true,
        ),
      ],
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SendAddressScreen), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('My wallet'), findsOneWidget);
  });

  testWidgets(
    'fixed BIP21 amount stays locked and continues with the request amount',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Device.screen = const Size(800, 1200);
      final wallet = _wallet();
      final state = SendState(
        step: SendStep.amount,
        sendType: SendType.bitcoin,
        wallets: [wallet],
        selectedWallet: SendWalletBitcoin(wallet),
        paymentRequest: const PaymentRequest.bip21(
          network: BitcoinNetwork.mainnet,
          uri: 'bitcoin:bc1qfirst?amount=0.000025',
          address: 'bc1qfirst',
          amountSat: 2500,
        ),
        bitcoinUnit: BitcoinUnit.sats,
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
      );
      final cubit = _MockSendCubit();
      when(() => cubit.isSpMode).thenReturn(false);
      when(() => cubit.state).thenReturn(state);
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.onAmountConfirmed()).thenAnswer((_) async {});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: _amountScope,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendAmountScreen(),
          ),
        ),
      );
      expect(find.text('Amount set by the payment request'), findsOneWidget);
      expect(find.byType(BullAmountInput), findsNothing);
      expect(find.text('MAX'), findsNothing);
      final button = tester.widget<BullButton>(
        find.widgetWithText(BullButton, 'Continue'),
      );
      expect(button.disabled, isFalse);
      await tester.tap(find.text('Continue'));
      verify(() => cubit.onAmountConfirmed()).called(1);
      verifyNever(
        () => cubit.amountChanged(
          amount: any(named: 'amount'),
          isMax: any(named: 'isMax'),
        ),
      );
    },
  );

  testWidgets('renders a fixed recipient amount as editable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1200);
    final wallet = _wallet();
    final state = SendState(
      step: SendStep.amount,
      sendType: SendType.bitcoin,
      wallets: [wallet],
      selectedWallet: SendWalletBitcoin(wallet),
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      amount: '10000',
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['USD'],
      fiatCurrencyCode: 'USD',
      exchangeRate: 50000,
      selectedUtxos: [walletUtxoFixture(walletId: wallet.id, sats: 75000)],
      recipientDrafts: const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '10000',
          receivesRemainder: false,
          isValid: true,
        ),
      ],
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.amountChanged(amount: null, isMax: true))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    final input = tester.widget<BullAmountInput>(find.byType(BullAmountInput));
    expect(input.readOnly, isFalse);
    expect(input.isMax, isFalse);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('Add Recipient'), findsNothing);
    expect(find.text('Send remaining balance'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Selected coins'),
      ),
      findsOneWidget,
    );
    expect(find.byType(BullDropdown<String>), findsNothing);

    await tester.tap(find.byType(Switch));
    verify(() => cubit.amountChanged(amount: null, isMax: true)).called(1);
  });

  testWidgets('single amount unit toggle keeps the canonical send draft', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1200);
    final wallet = _wallet();
    var state = SendState(
      step: SendStep.amount,
      sendType: SendType.bitcoin,
      wallets: [wallet],
      selectedWallet: SendWalletBitcoin(wallet),
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      amount: '10000',
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['USD'],
      fiatCurrencyCode: 'USD',
      exchangeRate: 50000,
      recipientDrafts: const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '10000',
          receivesRemainder: false,
          isValid: true,
        ),
      ],
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => cubit.amountChanged(
        amount: any(named: 'amount'),
        isMax: any(named: 'isMax'),
      ),
    ).thenAnswer((invocation) async {
      final amount = invocation.namedArguments[#amount] as String?;
      if (amount != null) state = state.copyWith(amount: amount);
    });
    when(() => cubit.onAmountConfirmed()).thenAnswer((_) async {});
    final settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          hideAmounts: false,
        ),
      ),
    );
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SendCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
          ],
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    final inputFinder = find.byType(BullAmountInput);
    final input = tester.widget<BullAmountInput>(inputFinder);
    expect(input.amountController.text, '10000');
    await tester.tap(
      find.descendant(
        of: inputFinder,
        matching: find.byType(BullAmountUnitToggle),
      ),
    );
    await tester.pump();
    expect(input.amountController.text, '10000');
    expect(find.text('0.0001'), findsOneWidget);
    verifyNever(
      () => cubit.amountChanged(
        amount: any(named: 'amount'),
        isMax: any(named: 'isMax'),
      ),
    );
    verifyNever(() => cubit.onCurrencyChanged(any()));
    verifyNever(() => settingsCubit.toggleSatsUnit(any()));

    await tester.enterText(
      find.descendant(of: inputFinder, matching: find.byType(TextField)),
      '0.0002',
    );
    await tester.pump();
    expect(input.amountController.text, '20000');
    verify(
      () => cubit.amountEntryChanged(
        sats: BigInt.from(20000),
        currencyCode: 'BTC',
        text: '0.0002',
        rate: null,
        quotedAt: null,
        isValid: true,
        isEdit: true,
      ),
    ).called(1);
    final continueButton = tester
        .widgetList<BullButton>(find.byType(BullButton))
        .singleWhere((button) => button.label == 'Continue');
    expect(continueButton.disabled, isFalse);
    await tester.tap(find.byWidget(continueButton));
    await tester.pump();
    verify(() => cubit.onAmountConfirmed()).called(1);
    verifyNever(() => cubit.onCurrencyChanged(any()));
    verifyNever(() => settingsCubit.toggleSatsUnit(any()));
  });

  testWidgets('matches a refreshed wallet option by id', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1200);
    final selectedWallet = _wallet();
    final refreshedWallet = selectedWallet.copyWith(
      balanceSat: BigInt.from(900000),
    );
    final state = SendState(
      step: SendStep.amount,
      sendType: SendType.bitcoin,
      wallets: [refreshedWallet],
      selectedWallet: SendWalletBitcoin(selectedWallet),
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['USD'],
      fiatCurrencyCode: 'USD',
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<BullDropdown<String>>(find.byType(BullDropdown<String>))
          .value,
      selectedWallet.id,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('Balance'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders a single remainder recipient with the MAX UI', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1200);
    final wallet = _wallet();
    final state = SendState(
      step: SendStep.amount,
      sendType: SendType.bitcoin,
      wallets: [wallet],
      selectedWallet: SendWalletBitcoin(wallet),
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      amount: '999000',
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['USD'],
      fiatCurrencyCode: 'USD',
      exchangeRate: 50000,
      recipientDrafts: const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '',
          receivesRemainder: true,
          isValid: true,
        ),
      ],
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.amountChanged(amount: '999000', isMax: false))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    final input = tester.widget<BullAmountInput>(find.byType(BullAmountInput));
    expect(input.readOnly, isFalse);
    expect(input.isMax, isTrue);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('MAX · balance minus fees'), findsOneWidget);
    expect(find.text('Add Recipient'), findsNothing);
    expect(find.text('Send remaining balance'), findsNothing);

    await tester.tap(find.byType(Switch));
    verify(() => cubit.amountChanged(amount: '999000', isMax: false)).called(1);
  });

  testWidgets('keeps recipient controls on the multi-recipient amount page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1600);
    final wallet = _wallet();
    final state = SendState(
      step: SendStep.amount,
      sendType: SendType.bitcoin,
      wallets: [wallet],
      selectedWallet: SendWalletBitcoin(wallet),
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qfirst',
        isTestnet: false,
      ),
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['USD'],
      fiatCurrencyCode: 'USD',
      exchangeRate: 50000,
      amountQuotes: {
        SupportedCurrency.usd: BitcoinPrice(
          currency: SupportedCurrency.usd,
          fiatAmount: 100000,
          fetchedAt: DateTime.utc(2026),
        ),
      },
      recipientAmountsSat: const [10000, 10000],
      recipientDrafts: const [
        (
          id: 0,
          address: 'bc1qfirst',
          amount: '10000',
          receivesRemainder: false,
          isValid: true,
        ),
        (
          id: 1,
          address: 'bc1qsecond',
          amount: '',
          receivesRemainder: true,
          isValid: true,
        ),
      ],
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('≈ 20.00 USD'), findsOneWidget);
    expect(find.text('Rest goes to'), findsOneWidget);
    expect(find.byType(BullDropdown<int>), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Radio<int>), findsNothing);
    expect(find.text('Add Recipient'), findsNothing);
    expect(find.text('MAX'), findsNothing);
    final input = tester.widget<BullAmountInput>(find.byType(BullAmountInput));
    expect(input.amountController.text, '10000');
    await tester.tap(find.byType(BullAmountUnitToggle));
    await tester.pump();
    expect(find.text('0.0001'), findsOneWidget);
    expect(input.amountController.text, '10000');
    await tester.enterText(
      find.descendant(
        of: find.byType(BullAmountInput),
        matching: find.byType(TextField),
      ),
      '0.0002',
    );
    await tester.pump();
    expect(input.amountController.text, '20000');
    verify(
      () => cubit.recipientEntryChanged(
        0,
        BigInt.from(20000),
        isValid: true,
        isEdit: true,
        currencyCode: 'BTC',
        text: '0.0002',
        rate: null,
        quotedAt: null,
      ),
    ).called(1);
  });

  testWidgets('confirmation shows the selected coin count and total', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1600);
    final wallet = _wallet();
    final state = SendState(
      step: SendStep.confirm,
      sendType: SendType.bitcoin,
      wallets: [wallet],
      selectedWallet: SendWalletBitcoin(wallet),
      selectedUtxos: [walletUtxoFixture(walletId: wallet.id, sats: 75000)],
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qrecipient',
        isTestnet: false,
      ),
      bitcoinUnit: BitcoinUnit.sats,
      inputAmountCurrencyCode: BitcoinUnit.sats.code,
      fiatCurrencyCodes: const ['USD'],
      fiatCurrencyCode: 'USD',
      exchangeRate: 50000,
      confirmedAmountSat: 50000,
      bitcoinAbsoluteFeesSat: 1000,
      unsignedPsbt: 'unsigned',
      signedBitcoinPsbt: 'signed',
    );
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    final settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          hideAmounts: false,
        ),
      ),
    );
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        builder: _amountScope,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SendCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
          ],
          child: const SendConfirmScreen(),
        ),
      ),
    );

    expect(find.text('Coin Control'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text(FormatAmount.sats(75000)), findsOneWidget);
  });

  testWidgets(
    'uses a required recipient selection for a multi-recipient sweep',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Device.screen = const Size(800, 1600);
      final wallet = _wallet();
      final state = SendState(
        step: SendStep.amount,
        sendType: SendType.bitcoin,
        wallets: [wallet],
        selectedWallet: SendWalletBitcoin(wallet),
        paymentRequest: const PaymentRequest.bitcoin(
          address: 'bc1qfirst',
          isTestnet: false,
        ),
        bitcoinUnit: BitcoinUnit.sats,
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
        fiatCurrencyCodes: const ['USD'],
        fiatCurrencyCode: 'USD',
        exchangeRate: 50000,
        sweepOutpoints: const {(txId: 'selected', vout: 0)},
        recipientDrafts: const [
          (
            id: 0,
            address: 'bc1qfirst',
            amount: '',
            receivesRemainder: true,
            isValid: true,
          ),
          (
            id: 1,
            address: 'bc1qsecond',
            amount: '10000',
            receivesRemainder: false,
            isValid: true,
          ),
        ],
      );
      final cubit = _MockSendCubit();
      when(() => cubit.isSpMode).thenReturn(false);
      when(() => cubit.state).thenReturn(state);
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          builder: _amountScope,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendAmountScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rest goes to'), findsOneWidget);
      expect(find.byType(BullDropdown<int>), findsOneWidget);
      expect(find.byType(Radio<int>), findsNothing);
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.byType(BullDropdown<int>));
      await tester.pumpAndSettle();
      expect(find.text('None'), findsNothing);
      await tester.tap(find.text('Recipient 2').last);
      await tester.pumpAndSettle();
      verify(() => cubit.setRemainderRecipient(1, true)).called(1);
    },
  );

  testWidgets(
    'confirmation lists recipients and clears amounts after a failed rebuild',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Device.screen = const Size(800, 1600);
      final wallet = _wallet();
      var state = SendState(
        step: SendStep.confirm,
        sendType: SendType.bitcoin,
        wallets: [wallet],
        selectedWallet: SendWalletBitcoin(wallet),
        paymentRequest: const PaymentRequest.bitcoin(
          address: 'bc1qfirst',
          isTestnet: false,
        ),
        bitcoinUnit: BitcoinUnit.sats,
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
        fiatCurrencyCodes: const ['USD'],
        fiatCurrencyCode: 'USD',
        exchangeRate: 50000,
        recipientDrafts: const [
          (
            id: 0,
            address: 'bc1qfirst',
            amount: '10000',
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
        recipientAmountsSat: const [97000, 2000],
        confirmedAmountSat: 99000,
        bitcoinAbsoluteFeesSat: 1000,
        unsignedPsbt: 'unsigned',
        signedBitcoinPsbt: 'signed',
      );
      final states = StreamController<SendState>.broadcast();
      addTearDown(states.close);
      final cubit = _MockSendCubit();
      when(() => cubit.isSpMode).thenReturn(false);
      when(() => cubit.state).thenAnswer((_) => state);
      when(() => cubit.stream).thenAnswer((_) => states.stream);
      final settingsCubit = _MockSettingsCubit();
      when(() => settingsCubit.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
            hideAmounts: false,
          ),
        ),
      );
      when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          builder: _amountScope,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<SendCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
            ],
            child: const SendConfirmScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('bc1qfirst'), findsOneWidget);
      expect(find.text('bc1qsecond'), findsOneWidget);
      expect(find.text(FormatAmount.sats(97000)), findsOneWidget);
      expect(find.text(FormatAmount.sats(2000)), findsOneWidget);
      expect(find.text(FormatAmount.sats(1000)), findsOneWidget);

      state = state.copyWith(
        failure: const SendInsufficientFundsForFeesFailure(),
        recipientAmountsSat: const [],
        confirmedAmountSat: null,
        bitcoinAbsoluteFeesSat: null,
        unsignedPsbt: null,
        signedBitcoinPsbt: null,
      );
      states.add(state);
      await tester.pumpAndSettle();

      expect(find.text(FormatAmount.sats(97000)), findsNothing);
      expect(
        find.text('Not enough funds to cover amount and fees'),
        findsOneWidget,
      );
      final confirmButton = tester
          .widgetList<BullButton>(find.byType(BullButton))
          .singleWhere((button) => button.label == 'Confirm');
      expect(confirmButton.disabled, isTrue);
    },
  );
}

Widget _amountScope(BuildContext context, Widget? child) => BullAmountScope(
  snapshot: const BullAmountSnapshot(
    unit: BitcoinUnit.sats,
    hideAmounts: false,
    isReady: true,
  ),
  writeUnit: (_) async => true,
  child: child ?? const SizedBox.shrink(),
);
