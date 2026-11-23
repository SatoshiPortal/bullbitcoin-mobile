import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_wallet_view.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _MockSendCubit extends Mock implements SendCubit {}

void main() {
  testWidgets('a recipient amount in the review switches unit on tap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Device.screen = const Size(800, 2400);
    final cubit = _MockSendCubit();
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      SendState(
        step: SendStep.confirm,
        sendType: SendType.bitcoin,
        selectedWallet: SendWalletSp(
          label: 'Silent Payments',
          network: Network.bitcoinMainnet,
          balanceSat: BigInt.from(1000000),
        ),
        recipientDrafts: const [
          (
            id: 1,
            address: 'bc1qrecipientone',
            amount: '12345',
            receivesRemainder: false,
            isValid: true,
          ),
          (
            id: 2,
            address: 'bc1qrecipienttwo',
            amount: '777',
            receivesRemainder: false,
            isValid: true,
          ),
        ],
        recipientAmountsSat: const [12345, 777],
        bitcoinUnit: BitcoinUnit.sats,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: [
          ...appLocalizationsDelegates,
          ...bullUiLocalizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => true,
          child: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendConfirmScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('12,345 sats'));
    await tester.pump();
    expect(find.text('0.00012345 BTC'), findsOneWidget);
    expect(find.text('777 sats'), findsOneWidget);
  });
}
