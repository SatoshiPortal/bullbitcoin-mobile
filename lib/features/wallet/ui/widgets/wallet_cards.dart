import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletCards extends StatelessWidget {
  const WalletCards({
    super.key,
    this.padding,
    this.onTap,
    this.localSignersOnly = false,
    this.fiatCurrency,
  });

  final EdgeInsetsGeometry? padding;
  final bool localSignersOnly;
  final Function(Wallet wallet)? onTap;
  final String? fiatCurrency;

  /// Whether [w] should show the syncing indicator, combining
  /// [WalletBloc]'s [syncStatus] with any active compact-filter (CBF)
  /// progress entry. [WalletBloc.syncStatus] only ever turns true for a
  /// sync driven through `WalletRepository.sync` — a foreground CBF attempt
  /// bypasses that path entirely (see `CbfWalletDatasource`), so relying on
  /// `syncStatus` alone would leave the determinate progress bar never
  /// rendering for a CBF wallet. Public (like [cardDetails]) so this
  /// backend-agnostic OR logic is unit-testable without mounting the
  /// widget.
  @visibleForTesting
  static bool isCardSyncing(
    Wallet w,
    Map<String, bool> syncStatus,
    WalletSyncProgressState syncProgressState,
  ) {
    final entry = syncProgressState.forWallet(w.id);
    final isCbfSyncing =
        entry != null &&
        entry.phase != WalletSyncProgressPhase.completed &&
        entry.phase != WalletSyncProgressPhase.failed;
    return (syncStatus[w.id] ?? false) || isCbfSyncing;
  }

  static Color cardDetails(BuildContext context, Wallet wallet) {
    final isTestnet = wallet.isTestnet;
    final isLiquid = wallet.isLiquid;
    final watchOrSignsRemotely = wallet.isWatchOnly || wallet.signsRemotely;

    final watchonlyColor = context.appColors.secondary;

    if (watchOrSignsRemotely && !isTestnet) return watchonlyColor;
    if (watchOrSignsRemotely && isTestnet) return watchonlyColor;

    if (isLiquid) return context.appColors.tertiary;

    if (isTestnet) return context.appColors.onTertiary;
    return context.appColors.onTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.select(
      (WalletBloc bloc) => localSignersOnly
          ? bloc.state.wallets.where((w) => w.signsLocally)
          : bloc.state.wallets,
    );
    final syncStatus = context.select(
      (WalletBloc bloc) => bloc.state.syncStatus,
    );

    final arkBalanceSat = context.select(
      (WalletBloc bloc) => bloc.state.arkBalanceSat,
    );
    final isArkWalletSetup = context.select(
      (WalletBloc bloc) => bloc.state.isArkWalletSetup,
    );
    final isArkWalletLoading = context.select(
      (WalletBloc bloc) => bloc.state.isArkWalletLoading,
    );
    final arkWallet = context.select((WalletBloc bloc) => bloc.state.arkWallet);

    // Read via the explicit `bloc:` param (not `context.watch`) so this
    // widget stays safe in the wallet-selection screens that render
    // WalletCards without a WalletSyncProgressCubit ancestor provider —
    // only WalletRouter's wallet-home/detail routes provide one. The
    // cubit is a lazy singleton, so this always resolves the same
    // already-subscribed instance.
    return BlocBuilder<WalletSyncProgressCubit, WalletSyncProgressState>(
      bloc: locator<WalletSyncProgressCubit>(),
      builder: (context, syncProgressState) {
        return Padding(
          padding: padding ?? const EdgeInsets.all(13.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              for (final w in wallets) ...[
                WalletCard(
                  tagColor: cardDetails(context, w),
                  title: w.displayLabel(context),
                  description: w.walletTypeString,
                  balanceSat: w.balanceSat.toInt(),
                  isSyncing: isCardSyncing(w, syncStatus, syncProgressState),
                  syncProgressPercent: syncProgressState
                      .forWallet(w.id)
                      ?.scannedPercent,
                  fiatCurrency: fiatCurrency,
                  onTap: () => onTap?.call(w),
                ),
                const Gap(8),
              ],
              if (isArkWalletSetup) ...[
                WalletCard(
                  tagColor: context.appColors.tertiary,
                  title: context.loc.walletArkInstantPayments,
                  description: context.loc.walletArkExperimental,
                  balanceSat: arkBalanceSat,
                  isSyncing: isArkWalletLoading,
                  onTap: () {
                    if (arkWallet == null) return;
                    context.pushNamed(ArkRoute.arkWalletDetail.name);
                  },
                ),
                const Gap(8),
              ],
            ],
          ),
        );
      },
    );
  }
}
