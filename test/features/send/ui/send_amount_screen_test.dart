import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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
  testWidgets('offers Add Recipient on the address page', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1600);
    final state = SendState(
      sendType: SendType.bitcoin,
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
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAddressScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Add Recipient'), findsOneWidget);
  });

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
      selectedWallet: wallet,
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
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => cubit.amountChanged(amount: null, isMax: true),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    final input = tester.widget<PriceInput>(find.byType(PriceInput));
    expect(input.readOnly, isFalse);
    expect(input.isMax, isFalse);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('Add Recipient'), findsNothing);
    expect(find.text('Send remaining balance'), findsNothing);
    expect(
      tester.widget<BalanceRow>(find.byType(BalanceRow)).title,
      'Selected coins',
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.tap(find.byType(Switch));
    verify(() => cubit.amountChanged(amount: null, isMax: true)).called(1);
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
      selectedWallet: selectedWallet,
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
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      selectedWallet.id,
    );
    expect(tester.widget<BalanceRow>(find.byType(BalanceRow)).title, 'Balance');
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
      selectedWallet: wallet,
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
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => cubit.amountChanged(amount: '999000', isMax: false),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    final input = tester.widget<PriceInput>(find.byType(PriceInput));
    expect(input.readOnly, isTrue);
    expect(input.isMax, isTrue);
    expect(find.text('MAX'), findsNWidgets(2));
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
      selectedWallet: wallet,
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
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendAmountScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PriceInput), findsNothing);
    expect(find.text('Send remaining balance'), findsNWidgets(2));
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(Radio<int>), findsNothing);
    expect(find.text('Add Recipient'), findsNothing);
    expect(find.text('MAX'), findsNothing);
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
      selectedWallet: wallet,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        selectedWallet: wallet,
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
      when(() => cubit.state).thenReturn(state);
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendAmountScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Send remaining balance'), findsNWidgets(2));
      expect(find.byType(Radio<int>), findsNWidgets(2));
      expect(find.byType(Switch), findsNothing);

      await tester.tap(find.byType(Radio<int>).last);
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
        selectedWallet: wallet,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          .widgetList<BBButton>(find.byType(BBButton))
          .singleWhere((button) => button.label == 'Confirm');
      expect(confirmButton.disabled, isTrue);
    },
  );
}
