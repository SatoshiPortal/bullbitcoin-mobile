import 'package:primitives/primitives.dart' show ScriptType;

import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:address_view/address_view.dart';
import 'package:receive/testing.dart';
import 'package:receive/receive.dart' show ReceiveWallet;
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Receive extends Mock implements ReceiveBloc {}

ReceiveState _state() {
  final wallet = ReceiveWallet(
    id: 'savings',
    label: 'Savings',
    network: BitcoinNetwork.mainnet,
    scriptType: ScriptType.bip84,
    signsLocally: true,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
  final now = DateTime.utc(2026);
  return ReceiveState(
    type: ReceiveType.bitcoin,
    wallet: wallet,
    walletAdmitted: true,
    inputAmountCurrencyCode: 'sats',
    inputAmount: '25000',
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
        final bloc = _Receive();
        when(() => bloc.state).thenReturn(state);
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        await tester.pumpWidget(
          _app(
            BlocProvider<ReceiveBloc>.value(
              value: bloc,
              child: Scaffold(
                body: Builder(
                  builder: (context) => BullButton.primary(
                    label: 'Open',
                    onPressed: () => ReceiveEnlargedQr.show(context),
                  ),
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
        await tester.tapAt(
          tester.getTopLeft(find.byType(BullQrCode)) + const Offset(1, 1),
        );
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

  test(
    'on-chain QR checks draft validity, address owner and Payjoin readiness',
    () {
      final current = _state();
      final preparingPayjoin = current.copyWith(payjoinAttemptSettled: false);
      expect(preparingPayjoin.canOpenEnlargedQr, isTrue);
      expect(preparingPayjoin.displayQrData, isEmpty);
      expect(current.displayQrData, current.qrData);
      for (final state in [
        current.copyWith(amountEntryValid: false),
        current.copyWith(walletAdmitted: false),
        current.copyWith(
          bitcoinAddress: current.bitcoinAddress!.copyWith(walletId: 'old'),
        ),
      ]) {
        expect(state.canOpenEnlargedQr, isFalse);
        expect(state.displayQrData, isEmpty);
      }
    },
  );

  testWidgets('an open enlarged QR waits for live amount confirmation', (
    tester,
  ) async {
    final bloc = _Receive();
    final states = StreamController<ReceiveState>.broadcast();
    addTearDown(states.close);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var state = _state().copyWith(
      walletAdmitted: true,
      inputAmountCurrencyCode: 'sats',
      inputAmount: '321',
      confirmedAmountSat: 321,
    );
    final initialData = state.qrData;
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
    when(() => bloc.isClosed).thenReturn(false);
    when(() => bloc.add(const ReceiveAmountConfirmed())).thenAnswer((_) {
      state = state.copyWith(confirmedAmountSat: 654);
      states.add(state);
    });
    await tester.pumpWidget(
      _app(
        BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Column(
              children: [
                ReceiveAmountInput(focusNode: focus, live: true, inCard: true),
                const ReceiveQRDetails(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<BullQrCode>(find.byType(BullQrCode)).data,
      initialData,
    );
    state = state.copyWith(inputAmount: '654');
    states.add(state);
    await tester.pump();

    // Tap the normal QR target while the actual amount widget is debouncing.
    await tester.tap(find.bySemanticsLabel('Enlarge the QR code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    final modal = find.byType(ReceiveEnlargedQr);
    final modalQr = find.descendant(
      of: modal,
      matching: find.byType(BullQrCode),
    );
    expect(modal, findsOneWidget);
    final openDialog = tester.element(modal);
    expect(find.byType(BullQrCode), findsNothing);
    final dataBeforeConfirmation = tester
        .widgetList<BullQrCode>(modalQr)
        .map((qr) => qr.data)
        .toList();
    verifyNever(() => bloc.add(const ReceiveAmountConfirmed()));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    verify(() => bloc.add(const ReceiveAmountConfirmed())).called(1);
    expect(tester.element(modal), same(openDialog));
    final dataAfterConfirmation = tester
        .widgetList<BullQrCode>(modalQr)
        .map((qr) => qr.data)
        .toList();
    expect(
      [dataBeforeConfirmation, dataAfterConfirmation],
      [
        <String>[],
        [state.qrData],
      ],
    );
    expect(Uri.parse(state.qrData).queryParameters['amount'], '0.00000654');
  });

  testWidgets('the normal QR opens from its outer tap target', (tester) async {
    final bloc = _Receive();
    when(() => bloc.state).thenReturn(_state());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      _app(
        BlocProvider<ReceiveBloc>.value(
          value: bloc,
          child: const Scaffold(body: ReceiveQRDetails()),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(BullQrCode)) + const Offset(1, 1),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReceiveEnlargedQr), findsOneWidget);
  });

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
