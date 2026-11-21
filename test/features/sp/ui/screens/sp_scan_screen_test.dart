import 'package:bb_mobile/core/themes/app_theme.dart';

import 'dart:async';

import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_scan_screen.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';

import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet_data.dart';

Widget _buildPage(SpCubit cubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpScanScreen()),
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
    when(loadUsecase.scanServerTip).thenAnswer((_) async => const Ok(900000));
    when(() => stopUsecase.execute()).thenAnswer((_) async => const Ok(null));
    when(() => scanUsecase.execute(startHeight: any(named: 'startHeight')))
        .thenAnswer((_) async => const Ok<void, SpFailure>(null));
    when(() => watchUsecase.execute())
        .thenAnswer((_) => openSpNotificationStream());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  Future<void> loadWith(WidgetTester tester, SpWalletData data) async {
    when(() => loadUsecase.execute())
        .thenAnswer((_) async => Ok<SpWalletData, SpFailure>(data));
    when(() => harness.scanControl.isScanningCached)
        .thenReturn(data.wallet.isScanning);
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

    // Two pumps per event: the first lets the broadcast stream deliver to the
    // cubit, the second rebuilds on the emitted state.
    controller.add(const SpScanStarted(1, 9));
    await tester.pump();
    await tester.pump();
    controller.add(const SpScanReceiveProgress(5, 9));
    await tester.pump();
    await tester.pump();

    expect(find.text('5 / 9'), findsOneWidget);
    // Inclusive range [1, 9]: block 5 is the 5th of 9, not the 4th of 8.
    expect(find.text('56%'), findsOneWidget);
    expect(find.text('Step 1 of 2: Receiving'), findsOneWidget);
    expect(find.textContaining('Elapsed'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(5 / 9, 0.001));
  });

  testWidgets('Stop button calls stopScan usecase once', (tester) async {
    await loadWith(tester, spWalletData(isScanning: true));

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => stopUsecase.execute()).called(1);
  });

  testWidgets('a failed Stop shows its error and keeps the Stop action', (
    tester,
  ) async {
    const failure = SpUnexpected('pause could not be saved');
    when(stopUsecase.execute).thenAnswer((_) async => const Err(failure));
    await loadWith(tester, spWalletData(isScanning: true));

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(SpScanScreen));
    expect(find.text(failure.toTranslated(context)), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });

  testWidgets('never scanned with bounds shows the start-height chooser', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(chainTip: 900000, minBirthdayHeight: 709656),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Earliest'), findsOneWidget);
    expect(find.text('Start scan from 709656'), findsOneWidget);
  });

  testWidgets('clearing scan state restores the picker without a header tip', (
    tester,
  ) async {
    final tip = Completer<Result<int, SpFailure>>();
    when(loadUsecase.scanServerTip).thenAnswer((_) => tip.future);
    when(harness.clearScanStateUsecase.execute)
        .thenAnswer((_) async => const Ok(null));
    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 890000, minBirthdayHeight: 709656),
    );
    expect(find.byType(Slider), findsNothing);
    expect(await cubit.clearScanState(), isTrue);
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Getting the latest block from the scan server'),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Start scan from 709656'), findsNothing);

    tip.complete(const Ok(900000));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Earliest'), findsOneWidget);
    expect(find.text('Start scan from 709656'), findsOneWidget);
  });

  testWidgets('tapping Start from chosen height scans from that height', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(chainTip: 900000, minBirthdayHeight: 709656),
    );

    await tester.tap(find.text('Start scan from 709656'));
    await tester.pump();

    verify(() => scanUsecase.execute(startHeight: 709656)).called(1);
  });

  testWidgets('retry keeps the selected height if the scan could not start', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(chainTip: 900000, minBirthdayHeight: 709656),
    );
    when(() => scanUsecase.execute(startHeight: 899000))
        .thenAnswer((_) async => const Err(SpUnexpected()));
    final heightInput = find.byType(TextField);
    await tester.ensureVisible(heightInput);
    await tester.enterText(heightInput, '899000');
    await tester.pump();
    await tester.tap(find.text('Start scan from 899000'));
    await tester.pumpAndSettle();
    verify(() => scanUsecase.execute(startHeight: 899000)).called(1);

    when(() => scanUsecase.execute(startHeight: 899000))
        .thenAnswer((_) async => const Ok(null));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    verify(() => scanUsecase.execute(startHeight: 899000)).called(1);
  });

  testWidgets('a failed header check no longer reports synced at the old tip', (
    tester,
  ) async {
    final notifications = StreamController<SpNotification>.broadcast();
    addTearDown(notifications.close);
    when(watchUsecase.execute).thenAnswer((_) => notifications.stream);
    await loadWith(
      tester,
      spWalletData(
        chainTip: 900000,
        lastScannedHeight: 900000,
        minBirthdayHeight: 709656,
      ),
    );
    expect(find.text('Auto scan enabled, synced'), findsOneWidget);

    notifications.add(
      const SpHeaderProgressFailed(SpHeaderValidationPhase.replay),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auto scan enabled, synced'), findsNothing);
    expect(find.text('Scan status unknown'), findsOneWidget);
    expect(find.text('Check for new payments'), findsOneWidget);

    notifications.add(
      const SpHeaderProgressCompleted(SpHeaderValidationPhase.replay),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auto scan enabled, synced'), findsOneWidget);
    expect(find.text('Scan status unknown'), findsNothing);
  });

  testWidgets('a checkpoint shows where the wallet scanned through', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 800000, chainTip: 900000),
    );

    expect(find.text('Scanned through block 800000'), findsOneWidget);
    expect(find.text('100000 blocks behind'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Check for new payments'));
    await tester.pump();

    // Continue scanning from the saved checkpoint.
    verify(() => scanUsecase.execute(startHeight: null)).called(1);
  });

  testWidgets('a checkpoint without a chain tip offers to check for payments', (
    tester,
  ) async {
    await loadWith(tester, spWalletData(lastScannedHeight: 976754));

    expect(find.text('Scanned through block 976754'), findsOneWidget);
    expect(find.text('Check for new payments'), findsOneWidget);
    expect(find.text('Resume scan'), findsNothing);
  });

  testWidgets('an interrupted first scan keeps the Resume action', (
    tester,
  ) async {
    await loadWith(
      tester,
      spWalletData(minBirthdayHeight: 709656, hasPendingScan: true),
    );

    expect(find.text('Scan unfinished'), findsOneWidget);
    expect(find.text('Resume scan'), findsOneWidget);
    verifyNever(loadUsecase.scanServerTip);
  });

  testWidgets('retry fetches the scan server tip after a connection failure', (
    tester,
  ) async {
    when(loadUsecase.scanServerTip)
        .thenAnswer((_) async => const Err(SpBackendUnreachable()));
    await loadWith(tester, spWalletData(minBirthdayHeight: 709656));
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn’t get the latest block from the scan server.'),
      findsOneWidget,
    );

    when(loadUsecase.scanServerTip).thenAnswer((_) async => const Ok(900000));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('caught up with auto scanning off says so and offers a scan', (
    tester,
  ) async {
    await harness.autoScanUsecase.execute(isEnabled: false);

    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 900000, chainTip: 900000),
    );

    // One message carrying both facts, not a status line contradicting a
    // bare "Caught up" underneath it.
    expect(find.text('Synced, automatic scanning is off'), findsOneWidget);
    expect(find.text('Automatic scanning is on'), findsNothing);
    // Nothing else will scan, so the user needs the button back.
    expect(find.text('Start scan'), findsOneWidget);
  });

  testWidgets('the auto scan status shows on every state, not just caught up', (
    tester,
  ) async {
    // Behind the tip, so this renders the resume view, which said nothing about
    // automatic scanning at all.
    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 899990, chainTip: 900000),
    );

    expect(find.text('Automatic scanning is on'), findsOneWidget);
  });

  testWidgets('caught up at the tip offers no scan action', (tester) async {
    await loadWith(
      tester,
      spWalletData(lastScannedHeight: 900000, chainTip: 900000),
    );

    expect(find.text('Auto scan enabled, synced'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    // Nothing left to start by hand, so the button is gone.
    expect(find.text('Start scan'), findsNothing);
    verifyNever(
      () => scanUsecase.execute(startHeight: any(named: 'startHeight')),
    );
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

    expect(find.text('Auto scan enabled, synced'), findsOneWidget);
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
