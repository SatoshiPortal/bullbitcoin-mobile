import '../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;

import '../testing/send_source_fixture.dart';

import 'package:bull_ui/app_theme.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/ui/screens/send_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, BitcoinUnit;

class _Cubit extends Mock implements SendCubit {}

void main() {
  const address = 'bc1qfirst';
  const raw = PaymentRequest.bitcoin(address: address, isTestnet: false);
  const uri = PaymentRequest.bip21(
    address: address,
    network: BitcoinNetwork.mainnet,
    uri: 'bitcoin:bc1qfirst',
  );
  final wallet = sendSourceFixture(
    id: 'fixture',
    network: BitcoinNetwork.mainnet,
    signerDevice: null,
    balanceSat: BigInt.from(1000000),
    label: 'Fixture wallet',
  );

  Future<_Cubit> pump(
    WidgetTester tester, {
    required PaymentRequest request,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    Device.screen = const Size(800, 1600);
    final cubit = _Cubit();
    when(() => cubit.state).thenReturn(
      SendState(
        paymentRequest: request,
        sendType: SendType.bitcoin,
        copiedRawPaymentRequest: address,
        wallets: [wallet],
        recipientDrafts: const [
          (
            id: 0,
            address: address,
            amount: '',
            receivesRemainder: false,
            isValid: true,
          ),
        ],
      ),
    );
    when(() => cubit.isSpMode).thenReturn(false);
    when(() => cubit.stream).thenAnswer((_) => const Stream<SendState>.empty());
    when(() => cubit.addRecipient()).thenAnswer((_) async => true);
    when(() => cubit.addInternalRecipient(wallet.id)).thenAnswer((_) async {});
    final router = GoRouter(
      initialLocation: '/send',
      routes: [
        GoRoute(
          path: '/send',
          builder: (_, _) => BlocProvider<SendCubit>.value(
            value: cubit,
            child: const SendScreen(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...sendTestLocalizationsDelegates,
        ],
        supportedLocales: SendLocalizations.supportedLocales,
        builder: (_, child) => BullAmountScope(
          snapshot: const BullAmountSnapshot(
            unit: BitcoinUnit.sats,
            hideAmounts: false,
            isReady: true,
          ),
          writeUnit: (_) async => true,
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets(
    'legacy amountless Bitcoin BIP21 opens My wallet and selects a wallet',
    (tester) async {
      final cubit = await pump(tester, request: uri);
      expect(find.byType(SendAddressScreen), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      final toggle = find.byType(BullSwitch);
      expect(tester.widget<BullSwitch>(toggle).onChanged, isNotNull);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsOneWidget);

      await tester.tap(find.widgetWithText(BullButton, 'Recipient'));
      await tester.pumpAndSettle();
      verify(() => cubit.addRecipient()).called(1);

      await tester.tap(find.widgetWithText(BullButton, 'My wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Send to my wallet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ListTile, 'Fixture wallet'));
      await tester.pumpAndSettle();
      verify(() => cubit.addInternalRecipient(wallet.id)).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal /send plain Bitcoin Advanced settings opens multiple recipients',
    (tester) async {
      final cubit = await pump(tester, request: raw);
      expect(find.byType(SendAddressScreen), findsNothing);
      await tester.tap(find.byType(BullSettingsEntryTile));
      await tester.pumpAndSettle();
      final toggle = find.byWidgetPredicate(
        (widget) =>
            widget is BullSwitch && !widget.value && widget.onChanged != null,
      );
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(SendAddressScreen), findsOneWidget);
      // Opening the list adds nobody until the user asks.
      verifyNever(() => cubit.addRecipient());
      verifyNever(() => cubit.addInternalRecipient(wallet.id));
      expect(tester.takeException(), isNull);
    },
  );
}
