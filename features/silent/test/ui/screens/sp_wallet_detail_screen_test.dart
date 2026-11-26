import 'package:bull_ui/bull_ui.dart'
    show BullTransactionListItem, bullUiLocalizationsDelegate;

import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:bull_ui/testing.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/ui/screens/sp_wallet_detail_screen.dart';
import 'package:silent/src/domain/entities/sp_coin.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';

import 'package:silent/localizations.dart';
import 'package:silent/src/domain/entities/sp_wallet_data.dart';

// A funded wallet snapshot; only the fields these tests toggle are exposed.
SpWalletData _walletData({
  List<SpPayment> history = const <SpPayment>[],
  List<SpCoin> coins = const <SpCoin>[],
  bool isScanning = false,
  int? lastScannedHeight,
  int? chainTip,
}) => spWalletData(
  confirmedSat: Sats.fromInt(5000),
  history: history,
  coins: coins,
  isScanning: isScanning,
  lastScannedHeight: lastScannedHeight,
  chainTip: chainTip,
);

Widget _buildPage({required SpCubit cubit}) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  localizationsDelegates: const [
    bullUiLocalizationsDelegate,
    ...SilentLocalizations.localizationsDelegates,
  ],
  supportedLocales: SilentLocalizations.supportedLocales,
  home: BlocProvider.value(
    value: cubit,
    child: SpWalletDetailScreen(
      exitRedirectPath: '/exit-target',
      balanceBuilder: (context, amount) => Text('host balance $amount'),
      settingsIconBuilder: (_) => const Icon(Icons.settings),
    ),
  ),
);

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;

  late SpCubit cubit;

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    when(
      () => loadUsecase.execute(),
    ).thenAnswer((_) async => Ok<SpWalletData, SilentFailure>(_walletData()));
    when(() => harness.watchUsecase.execute())
        .thenAnswer((_) => openSpNotificationStream());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(_buildPage(cubit: cubit));
  }

  testWidgets('renders wallet title', (tester) async {
    await pumpPage(tester);

    expect(find.text('Silent Payment Wallet'), findsOneWidget);
  });

  testWidgets('renders bottom action buttons', (tester) async {
    await pumpPage(tester);

    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    // Scanning moved to SP settings; the wallet keeps only receive and send.
    expect(find.text('Scan'), findsNothing);
  });

  testWidgets('passes the current sats to the host balance widget', (
    tester,
  ) async {
    await cubit.load();
    await pumpPage(tester);

    expect(find.text('host balance 5000'), findsOneWidget);
    expect(find.byTooltip('Silent Payments Wallet Settings'), findsOneWidget);
  });

  testWidgets('the nudge Scan button scans in place, without routing away', (
    tester,
  ) async {
    // Auto scanning off and the wallet behind, so the nudge card renders.
    await harness.autoScanUsecase.execute(isEnabled: false);
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(lastScannedHeight: 899990, chainTip: 900000),
      ),
    );

    when(
      () => harness.scanUsecase.execute(startHeight: any(named: 'startHeight')),
    ).thenAnswer((_) async => const Ok<void, SilentFailure>(null));

    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.textContaining('Last scanned'), findsOneWidget);

    await tester.tap(find.text('Scan'));
    await tester.pump();

    // The scan starts here; the user is not sent to the scan screen.
    verify(() => harness.scanUsecase.execute(startHeight: null)).called(1);
  });

  testWidgets('shows no Activity heading, matching the other wallets', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('shows empty state message when no history', (tester) async {
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(
      find.text('Tap Scan to look for incoming silent payments'),
      findsOneWidget,
    );
  });

  testWidgets('shows payment tiles when history is non-empty', (tester) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(
          history: [
            SpPayment(
              txid: 'aa' * 32,
              direction: SpPaymentDirection.receive,
              status: SpPaymentStatus.unconfirmed,
              amountSat: Sats.fromInt(1000),
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(BullTransactionListItem), findsOneWidget);
  });

  // The flag itself is computed by LoadSpWalletDataUsecase (see its test); the
  // screen only has to render it.
  testWidgets('shows SP badge when a payment is flagged as an SP output', (
    tester,
  ) async {
    final txid = 'aa' * 32;
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(
          history: [
            SpPayment(
              txid: txid,
              direction: SpPaymentDirection.receive,
              status: SpPaymentStatus.unconfirmed,
              amountSat: Sats.fromInt(1000),
              hasSpOutput: true,
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('SP'), findsOneWidget);
  });

  testWidgets('shows verifying payment status', (tester) async {
    final timestamp = BigInt.from(
      DateTime.now()
              .subtract(const Duration(minutes: 5))
              .millisecondsSinceEpoch ~/
          1000,
    );
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(
          history: [
            SpPayment(
              txid: 'aa' * 32,
              direction: SpPaymentDirection.receive,
              status: SpPaymentStatus.confirmedUnverified,
              amountSat: Sats.fromInt(1000),
              height: 800000,
              timestamp: timestamp,
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.textContaining('Verifying'), findsOneWidget);
    expect(find.textContaining('ago'), findsOneWidget);
    expect(find.textContaining('Block 800000'), findsNothing);
  });

  testWidgets('shows verified payment time ago with confirmation icon', (
    tester,
  ) async {
    final timestamp = BigInt.from(
      DateTime.now()
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch ~/
          1000,
    );
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(
          history: [
            SpPayment(
              txid: 'aa' * 32,
              direction: SpPaymentDirection.receive,
              status: SpPaymentStatus.verified,
              amountSat: Sats.fromInt(1000),
              height: 800000,
              timestamp: timestamp,
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.textContaining('ago'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.textContaining('Block 800000'), findsNothing);
  });

  testWidgets('shows failed verification with error background', (
    tester,
  ) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(
          history: [
            SpPayment(
              txid: 'bb' * 32,
              direction: SpPaymentDirection.send,
              status: SpPaymentStatus.verifyFailed,
              amountSat: Sats.fromInt(2000),
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('Verification failed'), findsOneWidget);
    expect(find.byType(BullTransactionListItem), findsOneWidget);
  });

  testWidgets('a confirmed payment with no time sits under Verifying', (
    tester,
  ) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(
          history: [
            SpPayment(
              txid: 'cc' * 32,
              direction: SpPaymentDirection.receive,
              status: SpPaymentStatus.verified,
              amountSat: Sats.fromInt(1000),
              height: 800000,
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('Verifying'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('warns when the Blindbit server is behind the chain', (
    tester,
  ) async {
    final notifications = StreamController<SpNotification>.broadcast();
    addTearDown(notifications.close);
    when(() => harness.watchUsecase.execute())
        .thenAnswer((_) => notifications.stream);
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(lastScannedHeight: 968876, chainTip: 970180),
      ),
    );
    await cubit.load();
    await pumpPage(tester);

    notifications.add(const SpScanStarted(957218, 968876));
    notifications.add(const SpScanCompleted());
    await tester.pump();

    expect(
      find.text(
        'The scan server is 1304 blocks behind the chain, so recent payments '
        'may be missing until it catches up.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tells the user to switch server on a checkpoint mismatch', (
    tester,
  ) async {
    final notifications = StreamController<SpNotification>.broadcast();
    addTearDown(notifications.close);
    when(() => harness.watchUsecase.execute())
        .thenAnswer((_) => notifications.stream);
    await cubit.load();
    await pumpPage(tester);

    notifications.add(const SpHeaderCheckpointMismatch());
    await tester.pump();

    expect(find.text('Electrum server sends a wrong chain'), findsOneWidget);
    expect(
      find.text(
        'This server does not follow the real Bitcoin chain. Switch to '
        'another Electrum server in the settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows scan strip when scanning', (tester) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SilentFailure>(
        _walletData(isScanning: true, lastScannedHeight: 800000),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });
}
