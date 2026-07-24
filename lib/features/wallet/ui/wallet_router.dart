import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_initial_sync_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_initial_sync_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WalletRoute {
  walletHome('/wallet'),
  walletDetail('/wallet/:walletId'),
  walletInitialSync('/wallet/:walletId/initial-sync');

  const WalletRoute(this.path);

  final String path;
}

class WalletRouter {
  static final walletHomeRoute = GoRoute(
    name: WalletRoute.walletHome.name,
    path: WalletRoute.walletHome.path,
    pageBuilder: (context, state) {
      return NoTransitionPage(
        key: state.pageKey,
        // Resolved as part of this page's own build, which — by Flutter's
        // top-down mounting order — always happens before WalletHomeScreen's
        // initState() below fires its own visibility-triggered refresh (see
        // that screen's `_refreshOnVisible`). Since WalletSyncProgressCubit
        // is a lazy singleton, this resolves the same already-subscribed
        // instance on every remount rather than creating a new one — see
        // that cubit's class doc. `.value` (not `create:`) means this
        // BlocProvider never closes it on route disposal.
        child: BlocProvider<WalletSyncProgressCubit>.value(
          value: locator<WalletSyncProgressCubit>(),
          child: BlocListener<WalletBloc, WalletState>(
            listenWhen: (previous, current) =>
                !previous.noWalletsFound && current.noWalletsFound,
            listener: (context, state) {
              // If no wallets are found, redirect to the onboarding screen
              //  to allow the user to create or restore a wallet.
              context.goNamed(OnboardingRoute.onboarding.name);
            },
            child: const WalletHomeScreen(),
          ),
        ),
      );
    },
  );

  static final walletDetailRoute = GoRoute(
    name: WalletRoute.walletDetail.name,
    path: WalletRoute.walletDetail.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId']!;
      // See walletHomeRoute above: `.value` so route disposal never closes
      // the app-wide singleton.
      return BlocProvider<WalletSyncProgressCubit>.value(
        value: locator<WalletSyncProgressCubit>(),
        child: WalletDetailScreen(walletId: walletId),
      );
    },
  );

  /// Dedicated first-run compact-block-filter (CBF) sync screen, reached
  /// only through [goToWalletHomeOrInitialSync] for a recovery/import
  /// operation whose wallet already persisted
  /// [BitcoinSyncBackend.compactBlockFilters] — never for a newly created
  /// wallet (see that method's `isRecoveryOrImport` gate).
  ///
  /// This route only ever navigates; it never itself starts a sync. The
  /// route-scoped [WalletInitialSyncCubit] provided here owns that —
  /// subscribing to progress before it ever calls `StartWalletSyncUsecase`
  /// — see that cubit's class doc.
  static final walletInitialSyncRoute = GoRoute(
    name: WalletRoute.walletInitialSync.name,
    path: WalletRoute.walletInitialSync.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId']!;
      return MultiBlocProvider(
        providers: [
          // See walletHomeRoute above: `.value` so route disposal never
          // closes the app-wide singleton — still threaded through here
          // purely for WalletSyncProgressCard's own staged diagnostics.
          BlocProvider<WalletSyncProgressCubit>.value(
            value: locator<WalletSyncProgressCubit>(),
          ),
          // Route-scoped: a fresh instance every visit, keyed by
          // walletId — never reused across visits and never the
          // app-wide singleton above.
          BlocProvider<WalletInitialSyncCubit>(
            create: (_) => locator<WalletInitialSyncCubit>(param1: walletId),
          ),
        ],
        child: WalletInitialSyncScreen(walletId: walletId),
      );
    },
  );

  /// The single navigation decision every recovery/import flow makes once
  /// its recovered/imported wallet is ready: for a recovery/import
  /// operation ([isRecoveryOrImport] true), reads that wallet's
  /// already-persisted [BitcoinSyncBackend] (never changes it — this is a
  /// read-only routing decision) and either lands on
  /// [walletInitialSyncRoute] for a wallet that opted into
  /// [BitcoinSyncBackend.compactBlockFilters], or preserves today's
  /// straight-to-[WalletRoute.walletHome] navigation for every other
  /// wallet (Electrum, or a lookup failure — never blocks the user behind
  /// a routing error).
  ///
  /// [isRecoveryOrImport] must be false for a newly created wallet —
  /// [walletInitialSyncRoute] exists to narrate a recovery/import's first
  /// sync attempt against already-existing chain history, never a fresh
  /// wallet's. A false value short-circuits straight to
  /// [WalletRoute.walletHome] without even looking up the backend.
  ///
  /// Centralized here, rather than duplicated in each of those flows'
  /// screens/routers, since every one of them already imports this file
  /// for [WalletRoute] itself.
  ///
  /// This method itself only ever navigates — it never starts a sync.
  /// [walletInitialSyncRoute]'s own route-scoped [WalletInitialSyncCubit]
  /// owns kicking off the CBF attempt once landed there; see that cubit's
  /// class doc for why that moved out of here.
  static Future<void> goToWalletHomeOrInitialSync(
    BuildContext context, {
    required String walletId,
    required bool isRecoveryOrImport,
  }) async {
    if (!isRecoveryOrImport) {
      context.goNamed(WalletRoute.walletHome.name);
      return;
    }
    final result = await locator<GetBitcoinSyncBackendUsecase>().execute(
      walletId: walletId,
    );
    final isCompactBlockFilters = switch (result) {
      Ok(:final value) => value == BitcoinSyncBackend.compactBlockFilters,
      Err() => false,
    };
    if (!context.mounted) return;
    if (isCompactBlockFilters) {
      context.goNamed(
        WalletRoute.walletInitialSync.name,
        pathParameters: {'walletId': walletId},
      );
    } else {
      context.goNamed(WalletRoute.walletHome.name);
    }
  }

  /// Same decision as [goToWalletHomeOrInitialSync], for a flow that has no
  /// specific wallet reference of its own to pass — onboarding's
  /// create/recover wizard and RecoverBull's full-vault recovery, both of
  /// which go through `CreateDefaultWalletsUsecase` and only ever apply a
  /// non-Electrum backend to *the* default Bitcoin wallet. For a
  /// recovery/import operation ([isRecoveryOrImport] true), looks that
  /// wallet up fresh from storage (rather than through `WalletBloc`'s
  /// state, which a just-dispatched `WalletStarted`/`WalletRefreshed` has
  /// not necessarily finished updating yet) so this is race-free
  /// regardless of when the caller's own wallet-bloc refresh resolves. No
  /// default Bitcoin wallet found (or the lookup fails) preserves today's
  /// straight-to-[WalletRoute.walletHome] navigation, same as
  /// [goToWalletHomeOrInitialSync]'s own failure case.
  ///
  /// [isRecoveryOrImport] false (onboarding's create wizard) short-circuits
  /// straight to [WalletRoute.walletHome] without even looking the wallet
  /// up — same rationale as [goToWalletHomeOrInitialSync].
  static Future<void> goToWalletHomeOrInitialSyncForDefaultBitcoinWallet(
    BuildContext context, {
    required bool isRecoveryOrImport,
  }) async {
    if (!isRecoveryOrImport) {
      context.goNamed(WalletRoute.walletHome.name);
      return;
    }
    String? walletId;
    try {
      final wallets = await locator<GetWalletsUsecase>().execute(
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      walletId = wallets.firstOrNull?.id;
    } catch (_) {
      walletId = null;
    }
    if (!context.mounted) return;
    if (walletId == null) {
      context.goNamed(WalletRoute.walletHome.name);
      return;
    }
    await goToWalletHomeOrInitialSync(
      context,
      walletId: walletId,
      isRecoveryOrImport: true,
    );
  }
}
