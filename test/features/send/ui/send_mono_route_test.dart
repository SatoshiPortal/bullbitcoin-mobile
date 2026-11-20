import 'package:go_router/go_router.dart';

import 'dart:async';

// The legacy screen already has a public shell import target.
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/send/domain/send_amount_conversion.dart';
import 'package:primitives/primitives.dart' show Sats;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Cubit extends Mock implements SendCubit {}

void main() {
  setUpAll(() => registerFallbackValue(const RelativeFee(500)));
  final wallet = Wallet(
    origin: 'mono',
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
    GoRouter? router,
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
          localizationsDelegates: const [
            ...bullUiLocalizationsDelegates,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

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
      expect(source, same(wallet));
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
