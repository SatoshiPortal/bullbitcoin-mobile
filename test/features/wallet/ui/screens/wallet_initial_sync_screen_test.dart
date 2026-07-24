import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_initial_sync_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_initial_sync_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchWalletSyncProgressUsecase extends Mock
    implements WatchWalletSyncProgressUsecase {}

class _MockCancelWalletSyncUsecase extends Mock
    implements CancelWalletSyncUsecase {}

class _MockStartWalletSyncUsecase extends Mock
    implements StartWalletSyncUsecase {}

class _MockGetBitcoinSyncBackendUsecase extends Mock
    implements GetBitcoinSyncBackendUsecase {}

const _walletId = 'w1';

/// Focused tests for `WalletInitialSyncScreen` — the dedicated first-run CBF
/// sync page. Covers the requirement that "Continue" is only ever offered
/// once the route-scoped `WalletInitialSyncCubit`'s tracked attempt
/// completes, or as an explicit "Skip" once it fails, and that the existing
/// `WalletSyncProgressCard` (fed by the separate, app-wide
/// `WalletSyncProgressCubit`) is shown throughout for staged diagnostics —
/// never a second, competing progress presentation.
void main() {
  late _MockWatchWalletSyncProgressUsecase watchUsecase;
  late _MockCancelWalletSyncUsecase cancelUsecase;
  late _MockStartWalletSyncUsecase startUsecase;
  late _MockGetBitcoinSyncBackendUsecase getBackendUsecase;
  late StreamController<WalletSyncProgress> controller;
  late WalletSyncProgressCubit progressCubit;
  late WalletInitialSyncCubit initialSyncCubit;
  late bool landedOnWalletHome;

  setUp(() {
    watchUsecase = _MockWatchWalletSyncProgressUsecase();
    cancelUsecase = _MockCancelWalletSyncUsecase();
    startUsecase = _MockStartWalletSyncUsecase();
    getBackendUsecase = _MockGetBitcoinSyncBackendUsecase();
    // Both cubits resolve the same underlying broadcast stream in
    // production (the same locator-provided WatchWalletSyncProgressUsecase)
    // — modeled here with a single shared controller both subscribe to.
    controller = StreamController<WalletSyncProgress>.broadcast();
    landedOnWalletHome = false;
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);
    when(
      () => cancelUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async {});
    when(
      () => startUsecase.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => const Ok(null));
    when(() => getBackendUsecase.execute(walletId: any(named: 'walletId')))
        .thenAnswer(
          (_) async => const Ok(BitcoinSyncBackend.compactBlockFilters),
        );
  });

  tearDown(() {
    progressCubit.close();
    initialSyncCubit.close();
    controller.close();
  });

  // Same rationale as `wallet_sync_progress_card_test.dart`: the cubits are
  // built inside `wrap()` (called from the test body) rather than in
  // `setUp`, so their subscriptions' `emit()` microtasks run in the zone
  // `tester.pump()` actually drains.
  Widget wrap() {
    progressCubit = WalletSyncProgressCubit(
      watchWalletSyncProgressUsecase: watchUsecase,
      cancelWalletSyncUsecase: cancelUsecase,
      startWalletSyncUsecase: startUsecase,
    );
    initialSyncCubit = WalletInitialSyncCubit(
      walletId: _walletId,
      watchWalletSyncProgressUsecase: watchUsecase,
      getBitcoinSyncBackendUsecase: getBackendUsecase,
      startWalletSyncUsecase: startUsecase,
    );
    final router = GoRouter(
      initialLocation: '/initial-sync',
      routes: [
        GoRoute(
          path: '/initial-sync',
          name: 'walletInitialSync',
          builder: (context, state) =>
              const WalletInitialSyncScreen(walletId: _walletId),
        ),
        GoRoute(
          path: '/wallet',
          name: 'walletHome',
          builder: (context, state) {
            landedOnWalletHome = true;
            return const Scaffold(body: Text('wallet home'));
          },
        ),
      ],
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<WalletSyncProgressCubit>.value(value: progressCubit),
        BlocProvider<WalletInitialSyncCubit>.value(value: initialSyncCubit),
      ],
      child: MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  // Same two-pump rationale as `wallet_sync_progress_card_test.dart`: the
  // event crosses this test's stand-in stream into both cubits, then each
  // cubit's own state stream into its listeners.
  Future<void> emitProgress(
    WidgetTester tester,
    WalletSyncProgress event,
  ) async {
    controller.add(event);
    await tester.pump();
    await tester.pump();
  }

  final continueLabel = AppLocalizationsEn().continueButton;
  final skipLabel = AppLocalizationsEn().wizardSkipButton;

  testWidgets(
    'shows the sync progress card and no Continue/Skip while connecting',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await emitProgress(
        tester,
        const WalletSyncStarted(
          _walletId,
          BitcoinSyncBackend.compactBlockFilters,
        ),
      );

      expect(find.text(continueLabel), findsNothing);
      expect(find.text(skipLabel), findsNothing);
      expect(
        find.text(
          AppLocalizationsEn().walletOptionsSyncBackendStatusConnecting,
        ),
        findsOneWidget,
      );
      // Accurately states that leaving does not cancel the sync — no
      // lifecycle event in this path ever tears the CBF session down.
      expect(
        find.text(AppLocalizationsEn().walletInitialSyncBackgroundNotice),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'offers Continue once the attempt completes, which lands on wallet home',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await emitProgress(
        tester,
        const WalletSyncStarted(
          _walletId,
          BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      await emitProgress(tester, const WalletSyncCompleted(_walletId));

      expect(find.text(continueLabel), findsOneWidget);
      expect(find.text(skipLabel), findsNothing);
      // No longer relevant once the attempt has actually completed.
      expect(
        find.text(AppLocalizationsEn().walletInitialSyncBackgroundNotice),
        findsNothing,
      );

      await tester.tap(find.text(continueLabel));
      await tester.pumpAndSettle();

      expect(landedOnWalletHome, isTrue);

      // WalletSyncCompleted starts a real completion-confirmation Timer on
      // the app-wide WalletSyncProgressCubit (see its class doc) that would
      // otherwise still be pending when flutter_test's end-of-test
      // invariant check runs.
      await progressCubit.close();
    },
  );

  testWidgets(
    'Continue stays offered even after the app-wide progress cubit later '
    'removes the completed entry (the confirmation-window timer) — '
    "WalletInitialSyncCubit's own completed phase never resets on its own",
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await emitProgress(
        tester,
        const WalletSyncStarted(
          _walletId,
          BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      await emitProgress(tester, const WalletSyncCompleted(_walletId));

      expect(find.text(continueLabel), findsOneWidget);

      // Advance real time past the app-wide cubit's completion-confirmation
      // window — WalletInitialSyncCubit's own phase must be unaffected.
      await tester.pump(const Duration(seconds: 4));

      expect(find.text(continueLabel), findsOneWidget);
    },
  );

  testWidgets(
    'offers an explicit Skip once the attempt fails, alongside the card\'s '
    'own Retry — and Skip lands on wallet home',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await emitProgress(
        tester,
        const WalletSyncStarted(
          _walletId,
          BitcoinSyncBackend.compactBlockFilters,
        ),
      );
      await emitProgress(
        tester,
        const WalletSyncFailed(
          _walletId,
          WalletSyncFailureCategory.compactBlockFilters,
        ),
      );

      expect(find.text(skipLabel), findsOneWidget);
      expect(find.text(continueLabel), findsNothing);
      expect(
        find.text(AppLocalizationsEn().walletOptionsSyncBackendRetryButton),
        findsOneWidget,
      );
      // Still shown while failed — the sync isn't gone, only Retry/Skip
      // are offered, and leaving without retrying still wouldn't have been
      // a lifecycle-driven cancellation.
      expect(
        find.text(AppLocalizationsEn().walletInitialSyncBackgroundNotice),
        findsOneWidget,
      );

      await tester.tap(find.text(skipLabel));
      await tester.pumpAndSettle();

      expect(landedOnWalletHome, isTrue);
    },
  );

  testWidgets('retrying a failed attempt clears Skip until it settles again', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await emitProgress(
      tester,
      const WalletSyncStarted(
        _walletId,
        BitcoinSyncBackend.compactBlockFilters,
      ),
    );
    await emitProgress(
      tester,
      const WalletSyncFailed(
        _walletId,
        WalletSyncFailureCategory.compactBlockFilters,
      ),
    );
    expect(find.text(skipLabel), findsOneWidget);

    // A fresh WalletSyncStarted — e.g. the card's own Retry, wired to the
    // app-wide cubit — reaches WalletInitialSyncCubit through the same
    // shared stream and moves it back to connecting.
    await emitProgress(
      tester,
      const WalletSyncStarted(
        _walletId,
        BitcoinSyncBackend.compactBlockFilters,
      ),
    );

    expect(find.text(skipLabel), findsNothing);
    expect(find.text(continueLabel), findsNothing);
  });
}
