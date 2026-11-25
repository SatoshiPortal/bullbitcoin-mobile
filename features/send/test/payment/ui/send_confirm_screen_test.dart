import '../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;
import 'package:primitives/primitives.dart' show LiquidNetwork;
import 'package:primitives/primitives.dart' show BitcoinNetwork;

import '../testing/send_source_fixture.dart';

import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:send/src/payment/ui/screens/send_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendCubit extends Mock implements SendCubit {}

void main() {
  testWidgets('Silent Payments confirms without external signing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 1600);
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(true);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      SendState(
        step: SendStep.confirm,
        sendType: SendType.bitcoin,
        selectedWallet: SendWalletSp(
          label: 'Silent Payments',
          network: BitcoinNetwork.mainnet,
          balanceSat: BigInt.from(100000),
        ),
        copiedRawPaymentRequest: 'sp1recipient',
        confirmedAmountSat: 50000,
        bitcoinAbsoluteFeesSat: 1000,
        bitcoinUnit: BitcoinUnit.sats,
        inputAmountCurrencyCode: BitcoinUnit.sats.code,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: sendTestLocalizationsDelegates,
        supportedLocales: SendLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const SendConfirmScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ConfirmSendButton), findsOneWidget);
    expect(find.byType(ShowPsbtButton), findsNothing);
  });

  for (final phase in ['idle', 'building', 'signing', 'broadcasting']) {
    testWidgets('Advanced settings respect the $phase transaction phase', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Device.screen = const Size(800, 1600);
      final cubit = _MockSendCubit();
      when(() => cubit.isSpMode).thenReturn(false);
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.state).thenReturn(
        SendState(
          step: SendStep.confirm,
          sendType: SendType.liquid,
          selectedWallet: SendWalletBitcoin(
            sendSourceFixture(
              id: 'liquid-wallet',
              network: LiquidNetwork.mainnet,
              signerDevice: null,
              balanceSat: BigInt.from(100000),
            ),
          ),
          confirmedAmountSat: 50000,
          liquidAbsoluteFees: 100,
          bitcoinUnit: BitcoinUnit.sats,
          inputAmountCurrencyCode: BitcoinUnit.sats.code,
          buildingTransaction: phase == 'building',
          signingTransaction: phase == 'signing',
          broadcastingTransaction: phase == 'broadcasting',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: sendTestLocalizationsDelegates,
          supportedLocales: SendLocalizations.supportedLocales,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendConfirmScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(SendConfirmScreen));
      final label = SendLocalizations.of(context).sendAdvancedSettings;
      final link = tester.widget<BullAdvancedOptionsLink>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(BullAdvancedOptionsLink),
        ),
      );
      expect(link.onPressed == null, phase != 'idle');
    });
  }
}
