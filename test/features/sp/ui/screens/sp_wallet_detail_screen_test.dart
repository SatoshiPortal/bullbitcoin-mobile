import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_wallet_detail_screen.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_detail_balance_card.dart';
import 'package:bb_mobile/core/widgets/lists/tx_list_item.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet_data.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

SettingsState _settingsState() => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    hideAmounts: false,
  ),
);

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

Widget _buildPage({
  required SpCubit cubit,
  required SettingsCubit settingsCubit,
  required BitcoinPriceBloc bitcoinPriceBloc,
}) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SpCubit>.value(value: cubit),
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
    ],
    child: const SpWalletDetailScreen(exitRedirectPath: '/exit-target'),
  ),
);

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late _MockSettingsCubit settingsCubit;
  late _MockBitcoinPriceBloc bitcoinPriceBloc;
  late SpCubit cubit;

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    settingsCubit = _MockSettingsCubit();
    bitcoinPriceBloc = _MockBitcoinPriceBloc();
    when(() => settingsCubit.state).thenReturn(_settingsState());
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
    when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => loadUsecase.execute(),
    ).thenAnswer((_) async => Ok<SpWalletData, SpFailure>(_walletData()));
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      _buildPage(
        cubit: cubit,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
      ),
    );
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

  testWidgets('uses wallet detail balance card', (tester) async {
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(WalletDetailBalanceCard), findsOneWidget);
  });

  testWidgets('the nudge Scan button scans in place, without routing away', (
    tester,
  ) async {
    // Auto scanning off and the wallet behind, so the nudge card renders.
    await harness.autoScanUsecase.execute(isEnabled: false);
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(
        _walletData(lastScannedHeight: 899990, chainTip: 900000),
      ),
    );

    when(
      () => harness.scanUsecase.execute(startHeight: any(named: 'startHeight')),
    ).thenAnswer((_) async => const Ok<void, SpFailure>(null));

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
      (_) async => Ok<SpWalletData, SpFailure>(
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

    expect(find.byType(TxListItem), findsOneWidget);
  });

  // The flag itself is computed by LoadSpWalletDataUsecase (see its test); the
  // screen only has to render it.
  testWidgets('shows SP badge when a payment is flagged as an SP output', (
    tester,
  ) async {
    final txid = 'aa' * 32;
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(
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
      (_) async => Ok<SpWalletData, SpFailure>(
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
      (_) async => Ok<SpWalletData, SpFailure>(
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
      (_) async => Ok<SpWalletData, SpFailure>(
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
    expect(find.byType(TxListItem), findsOneWidget);
  });

  testWidgets('shows scan strip when scanning', (tester) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(
        _walletData(isScanning: true, lastScannedHeight: 800000),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });
}
