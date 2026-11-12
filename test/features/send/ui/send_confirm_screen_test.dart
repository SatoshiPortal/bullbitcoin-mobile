import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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
          network: Network.bitcoinMainnet,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
            Wallet(
              origin: 'liquid-wallet',
              network: Network.liquidMainnet,
              xpubFingerprint: '00000000',
              scriptType: ScriptType.bip84,
              xpub: '',
              externalPublicDescriptor: '',
              internalPublicDescriptor: '',
              signer: SignerEntity.local,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendConfirmScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(SendConfirmScreen));
      final label = AppLocalizations.of(context).sendAdvancedSettings;
      final button = tester.widget<BullButton>(
        find.ancestor(of: find.text(label), matching: find.byType(BullButton)),
      );
      expect(button.disabled, phase != 'idle');
    });
  }
}
