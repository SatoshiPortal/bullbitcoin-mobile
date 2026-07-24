import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_warning.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_sync_progress_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchWalletSyncProgressUsecase extends Mock
    implements WatchWalletSyncProgressUsecase {}

class _MockCancelWalletSyncUsecase extends Mock
    implements CancelWalletSyncUsecase {}

class _MockStartWalletSyncUsecase extends Mock
    implements StartWalletSyncUsecase {}

const _walletId = 'w1';

void main() {
  late _MockWatchWalletSyncProgressUsecase watchUsecase;
  late _MockCancelWalletSyncUsecase cancelUsecase;
  late _MockStartWalletSyncUsecase startUsecase;
  late StreamController<WalletSyncProgress> controller;
  late WalletSyncProgressCubit cubit;

  setUp(() {
    watchUsecase = _MockWatchWalletSyncProgressUsecase();
    cancelUsecase = _MockCancelWalletSyncUsecase();
    startUsecase = _MockStartWalletSyncUsecase();
    controller = StreamController<WalletSyncProgress>.broadcast();
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);
    when(
      () => cancelUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => startUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(() {
    cubit.close();
    controller.close();
  });

  // The cubit is deliberately built here rather than in `setUp` — `setUp`
  // and the `testWidgets` body run in different zones, and
  // `WalletSyncProgressCubit`'s constructor synchronously subscribes to the
  // progress stream; a subscription created in `setUp`'s zone binds the
  // `emit()` microtasks it later triggers to that zone too, which
  // `tester.pump()` never drains, so the widget would never see the
  // update. Building the cubit inside `wrap()` — called from within the
  // test body — keeps everything in the zone `pump()` actually drains.
  Widget wrap() {
    cubit = WalletSyncProgressCubit(
      watchWalletSyncProgressUsecase: watchUsecase,
      cancelWalletSyncUsecase: cancelUsecase,
      startWalletSyncUsecase: startUsecase,
    );
    return BlocProvider<WalletSyncProgressCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: WalletSyncProgressCard(walletId: _walletId)),
      ),
    );
  }

  // Delivering [event] to the widget crosses two chained broadcast
  // streams — `controller` (this test's stand-in for
  // `WatchWalletSyncProgressUsecase`) into the cubit's `_onProgress`, then
  // the cubit's own state stream into `BlocProvider`'s listener — each an
  // async (non-`sync`) `StreamController`, so each hop only delivers on
  // its own microtask. A single `tester.pump()` reliably drains the first
  // hop but not reliably the second, so every emission is settled with
  // two pumps.
  Future<void> emitProgress(
    WidgetTester tester,
    WalletSyncProgress event,
  ) async {
    controller.add(event);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing when nothing is tracked for the wallet', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.byType(WalletSyncProgressCard), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text), findsNothing);
  });

  testWidgets('renders nothing for a Started tagged electrum (ordinary '
      'Electrum sync)', (tester) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncStarted(_walletId, BitcoinSyncBackend.electrum),
    );

    expect(find.byWidgetPredicate((w) => w is Text), findsNothing);
  });

  testWidgets('shows the connecting status immediately for a Started tagged '
      'compactBlockFilters — no heuristic delay waiting for Scanning', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncStarted(
        _walletId,
        BitcoinSyncBackend.compactBlockFilters,
      ),
    );

    expect(
      find.text(AppLocalizationsEn().walletOptionsSyncBackendStatusConnecting),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows the scanning percent, with no stop/cancel control while active — '
    'CbfWalletDatasource runs a long-lived session no ordinary cancellation '
    'can interrupt',
    (tester) async {
      await tester.pumpWidget(wrap());

      await emitProgress(
        tester,
        const WalletSyncScanning(_walletId, scannedPercent: 55),
      );

      expect(find.textContaining('55'), findsOneWidget);
      expect(find.byType(BBButton), findsNothing);
    },
  );

  testWidgets('shows the connected stage label', (tester) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(_walletId, stage: WalletSyncScanStage.connected),
    );

    expect(
      find.text(AppLocalizationsEn().walletSyncProgressStageConnected),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows the syncingHeaders label with chainHeight as plain text and no '
    'percent, then the downloadingFilters label with a percent once filter '
    'progress starts',
    (tester) async {
      await tester.pumpWidget(wrap());

      await emitProgress(
        tester,
        const WalletSyncScanning(
          _walletId,
          stage: WalletSyncScanStage.syncingHeaders,
          chainHeight: 123456,
        ),
      );
      expect(
        find.text(AppLocalizationsEn().walletSyncProgressStageSyncingHeaders),
        findsOneWidget,
      );
      expect(find.textContaining('123456'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      await emitProgress(
        tester,
        const WalletSyncScanning(
          _walletId,
          stage: WalletSyncScanStage.downloadingFilters,
          scannedPercent: 30,
        ),
      );
      expect(
        find.text(
          AppLocalizationsEn().walletSyncProgressStageDownloadingFilters,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('30'), findsOneWidget);
    },
  );

  testWidgets('shows the matchingBlocks label', (tester) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(
        _walletId,
        stage: WalletSyncScanStage.matchingBlocks,
        receivedBlockCount: 2,
      ),
    );

    expect(
      find.text(AppLocalizationsEn().walletSyncProgressStageMatchingBlocks),
      findsOneWidget,
    );
  });

  testWidgets('shows the applyingUpdate label', (tester) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(
        _walletId,
        stage: WalletSyncScanStage.applyingUpdate,
      ),
    );

    expect(
      find.text(AppLocalizationsEn().walletSyncProgressStageApplyingUpdate),
      findsOneWidget,
    );
  });

  testWidgets(
    'a non-fatal warning shows the generic notice, never the raw warning',
    (tester) async {
      await tester.pumpWidget(wrap());

      await emitProgress(
        tester,
        const WalletSyncWarningRaised(
          _walletId,
          WalletSyncNeedsConnectionsWarning(),
        ),
      );

      expect(
        find.text(AppLocalizationsEn().walletSyncProgressNonFatalNotice),
        findsOneWidget,
      );
      expect(find.textContaining('cbf_need_connections'), findsNothing);
    },
  );

  testWidgets('shows a completed confirmation with no stop/cancel control once '
      'finished', (tester) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(_walletId, scannedPercent: 100),
    );
    await emitProgress(tester, const WalletSyncCompleted(_walletId));

    expect(
      find.text(AppLocalizationsEn().walletOptionsSyncBackendStatusCompleted),
      findsOneWidget,
    );
    expect(find.byType(BBButton), findsNothing);

    // WalletSyncCompleted starts a real completion-confirmation Timer (see
    // WalletSyncProgressCubit) that would otherwise still be pending when
    // flutter_test's end-of-test invariant check runs — before this test's
    // own tearDown gets a chance to close the cubit and cancel it.
    await cubit.close();
  });

  testWidgets('shows the generic failure message and only a Retry button once '
      'a CBF attempt fails, with no raw failure detail and no stop/cancel '
      'control', (tester) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(_walletId, scannedPercent: 30),
    );
    await emitProgress(
      tester,
      const WalletSyncFailed(
        _walletId,
        WalletSyncFailureCategory.compactBlockFilters,
      ),
    );

    expect(
      find.text(AppLocalizationsEn().walletOptionsSyncBackendStatusFailed),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().walletOptionsSyncBackendRetryButton),
      findsOneWidget,
    );
    // Retry is the only button ever offered once failed — no separate
    // stop/cancel control alongside it.
    expect(find.byType(BBButton), findsOneWidget);
  });

  testWidgets('tapping Retry forwards to StartWalletSyncUsecase', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(_walletId, scannedPercent: 30),
    );
    await emitProgress(
      tester,
      const WalletSyncFailed(
        _walletId,
        WalletSyncFailureCategory.compactBlockFilters,
      ),
    );

    await tester.tap(
      find.text(AppLocalizationsEn().walletOptionsSyncBackendRetryButton),
    );
    await tester.pump();

    verify(() => startUsecase.execute(walletId: _walletId)).called(1);
  });

  testWidgets('renders nothing once WalletSyncCancelled arrives', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await emitProgress(
      tester,
      const WalletSyncScanning(_walletId, scannedPercent: 10),
    );
    expect(find.byWidgetPredicate((w) => w is Text), findsWidgets);

    await emitProgress(tester, const WalletSyncCancelled(_walletId));

    expect(find.byWidgetPredicate((w) => w is Text), findsNothing);
  });

  testWidgets(
    'never offers a stop/cancel control while connecting either — only '
    'once failed does any button (Retry) appear',
    (tester) async {
      await tester.pumpWidget(wrap());

      await emitProgress(
        tester,
        const WalletSyncStarted(
          _walletId,
          BitcoinSyncBackend.compactBlockFilters,
        ),
      );

      expect(find.byType(BBButton), findsNothing);
      verifyNever(
        () => cancelUsecase.execute(walletId: any(named: 'walletId')),
      );
    },
  );
}
