import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

    final spBalanceSat = context.select(
      (WalletBloc bloc) => bloc.state.spBalanceSat,
    );
    // Read the SP feature gate (superuser + dev mode) and setup state from the
    // wallet's own bloc, so this widget doesn't import the settings feature's
    // presentation (rule #1). WalletBloc mirrors the gate into its state.
    final showSpWallet = context.select(
      (WalletBloc bloc) => bloc.state.showSpWallet,
    );
    final isSpWalletLoading = context.select(
      (WalletBloc bloc) => bloc.state.isSpWalletLoading,
    );

    return Padding(
      padding: padding ?? const EdgeInsets.all(13.0),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final (index, w) in wallets.indexed) ...[
            if (index > 0) const Gap(8),
            WalletCard(
              tagColor: cardDetails(context, w),
              title: w.displayLabel(context),
              description: w.walletTypeString,
              balanceSat: w.balanceSat.toInt(),
              isSyncing: syncStatus[w.id] ?? false,
              fiatCurrency: fiatCurrency,
              onTap: () => onTap?.call(w),
            ),
          ],
          if (showSpWallet) ...[
            WalletCard(
              tagColor: context.appColors.tertiary,
              title: context.loc.walletSpTitle,
              description: context.loc.walletSpExperimental,
              balanceSat: spBalanceSat,
              isSyncing: isSpWalletLoading,
              onTap: () => context.pushNamed(SpRoute.spWalletDetail.name),
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
