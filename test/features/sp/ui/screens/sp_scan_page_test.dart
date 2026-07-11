import 'dart:async';

import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_scan_page.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

Widget _buildPage(SpCubit cubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpScanPage()),
);

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late MockStopSpScanUsecase stopUsecase;
  late MockScanSpWalletUsecase scanUsecase;
  late MockWatchSpNotificationsUsecase watchUsecase;
  late SpCubit cubit;

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    stopUsecase = harness.stopUsecase;
    scanUsecase = harness.scanUsecase;
    watchUsecase = harness.watchUsecase;

    when(() => loadUsecase.execute())
        .thenAnswer((_) async => Ok<SpWalletData, SpFailure>(spWalletData()));
    when(() => stopUsecase.execute()).thenAnswer((_) async {});
    when(
      () => scanUsecase.execute(startHeight: any(named: 'startHeight')),
    ).thenAnswer((_) async => const Ok<void, SpFailure>(null));
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  Future<void> loadWith(WidgetTester tester, SpWalletData data) async {
    when(() => loadUsecase.execute())
        .thenAnswer((_) async => Ok<SpWalletData, SpFailure>(data));
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();
  }

  testWidgets('renders scan page title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('scanning shows progress indicator and Stop', (tester) async {
    await loadWith(tester, spWalletData(isScanning: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });

  testWidgets('scan progress shows determinate circular and current/target', (
    tester,
  ) async {
    final controller = StreamController<SpNotification>.broadcast();
    addTearDown(controller.close);
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);

    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));

    controller.add(const SpScanStarted(1, 9));
    await tester.pump();
    controller.add(const SpScanReceiveProgress(5, 9));
    await tester.pump();

    expect(find.text('5 / 9'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Step 1 of 2: Receiving'), findsOneWidget);
    expect(find.textContaining('Elapsed'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('Stop button calls stopScan usecase once', (tester) async {
    await loadWith(tester, spWalletData(isScanning: true));

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => stopUsecase.execute()).called(1);
  });

  testWidgets('never scanned with bounds shows the start-height chooser', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(chainTip: 900000, minBirthdayHeight: 709632),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Earliest'), findsOneWidget);
    expect(find.text('Start scan from 709632'), findsOneWidget);
  });

  testWidgets('tapping Start from chosen height scans from that height', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(chainTip: 900000, minBirthdayHeight: 709632),
    );

    await tester.tap(find.text('Start scan from 709632'));
    await tester.pump();

    verify(() => scanUsecase.execute(startHeight: 709632)).called(1);
  });

  testWidgets('already scanned shows the next start read-only and resumes', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 800000, chainTip: 900000),
    );

    expect(find.text('100000 blocks behind'), findsOneWidget);
    expect(find.text('~1 year 10 months'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Start scan'));
    await tester.pump();

    // Resume: no start height (null) is forwarded.
    verify(() => scanUsecase.execute(startHeight: null)).called(1);
  });

  testWidgets('caught up at the tip shows a working Start scan button', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 900000, chainTip: 900000),
    );

    expect(find.text('Caught up at block 900000'), findsOneWidget);
    // No height chooser after the initial scan; just a resume button.
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Start scan'));
    await tester.pump();

    // Resume: no start height (null) is forwarded; bwk scans to the live tip.
    verify(() => scanUsecase.execute(startHeight: null)).called(1);
  });

  testWidgets('shows total scan duration after a completed scan', (
    tester,
  ) async {
    final controller = StreamController<SpNotification>.broadcast();
    addTearDown(controller.close);
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(
        spWalletData(lastScannedHeight: 900000, chainTip: 900000),
      ),
    );

    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));

    controller.add(const SpScanStarted(800000, 900000));
    await tester.pump();
    controller.add(const SpScanCompleted());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Caught up at block 900000'), findsOneWidget);
    expect(find.textContaining('Scanned in'), findsOneWidget);
  });

  testWidgets('does not call stopScan on dispose', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('other'))),
    );
    await tester.pump();

    expect(find.text('other'), findsOneWidget);
    verifyNever(() => stopUsecase.execute());
  });
}
