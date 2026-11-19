import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_enlarged_qr.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Receive extends Mock implements ReceiveBloc {}

ReceiveState _state() {
  final wallet = Wallet(
    origin: 'savings',
    label: 'Savings',
    network: Network.bitcoinMainnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
  final now = DateTime.utc(2026);
  return ReceiveState(
    type: ReceiveType.bitcoin,
    wallet: wallet,
    payjoinAttemptSettled: true,
    confirmedAmountSat: 25000,
    note: 'Coffee',
    bitcoinAddress: WalletAddress(
      walletId: wallet.id,
      index: 0,
      address: 'bc1qpublic',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: const [
    bullUiLocalizationsDelegate,
    ...appLocalizationsDelegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  for (final closeWithX in [false, true]) {
    testWidgets(
      'enlarged QR preserves payload; ${closeWithX ? 'X' : 'scrim'} closes it',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = _state();
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Builder(
                builder: (context) => BullButton.primary(
                  label: 'Open',
                  onPressed: () => ReceiveEnlargedQr.show(context, state),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<BullQrCode>(find.byType(BullQrCode)).data,
          state.paymentRequest,
        );
        await tester.tap(find.byType(BullQrCode));
        await tester.pumpAndSettle();
        expect(find.byType(ReceiveEnlargedQr), findsOneWidget);
        if (closeWithX) {
          await tester.tap(find.byTooltip('Close'));
        } else {
          await tester.tapAt(const Offset(10, 100));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ReceiveEnlargedQr), findsNothing);
      },
    );
  }

  testWidgets(
    'long press on the real address viewer copies the live amount and message',
    (tester) async {
      final state = _state();
      final bloc = _Receive();
      when(() => bloc.state).thenReturn(state);
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _app(
          BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: const Scaffold(body: ReceiveQRDetails()),
          ),
        ),
      );
      await tester.longPress(find.byType(AddressViewer));
      await tester.pump();
      expect(copied, 'bitcoin:bc1qpublic?amount=0.00025&message=Coffee');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
}
