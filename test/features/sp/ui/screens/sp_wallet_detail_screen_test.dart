import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_wallet_detail_screen.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_detail_balance_card.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

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
}) => spWalletData(
  confirmedSat: BigInt.from(5000),
  history: history,
  coins: coins,
  isScanning: isScanning,
  lastScannedHeight: lastScannedHeight,
);

Widget _buildPage({
  required SpCubit cubit,
  required SettingsCubit settingsCubit,
  required BitcoinPriceBloc bitcoinPriceBloc,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SpCubit>.value(value: cubit),
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
    ],
    child: const SpWalletDetailScreen(),
  ),
);

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late _MockSettingsCubit settingsCubit;
  late _MockBitcoinPriceBloc bitcoinPriceBloc;
  late MockScanSpWalletUsecase scanUsecase;
  late SpCubit cubit;

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    scanUsecase = harness.scanUsecase;
    settingsCubit = _MockSettingsCubit();
    bitcoinPriceBloc = _MockBitcoinPriceBloc();
    when(() => settingsCubit.state).thenReturn(_settingsState());
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
    when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => loadUsecase.execute())
        .thenAnswer((_) async => Ok<SpWalletData, SpFailure>(_walletData()));
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
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('uses wallet detail balance card', (tester) async {
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(WalletDetailBalanceCard), findsOneWidget);
  });

  testWidgets('shows Activity section header', (tester) async {
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('Activity'), findsOneWidget);
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
              amountSat: BigInt.from(1000),
            ),
          ],
        ),
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('1 000 sats'), findsOneWidget);
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

  testWidgets('Scan button navigates to the scan page without scanning', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<SpCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
              BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
            ],
            child: const SpWalletDetailScreen(),
          ),
        ),
        GoRoute(
          name: SpRoute.spScan.name,
          path: '/scan',
          builder: (context, state) =>
              const Scaffold(body: Text('scan page reached')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('scan page reached'), findsOneWidget);
    // The button must only navigate; starting the scan is the scan view's job.
    verifyNever(() => scanUsecase.execute());
  });
}
