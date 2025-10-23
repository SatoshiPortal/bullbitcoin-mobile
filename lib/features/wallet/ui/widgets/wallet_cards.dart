import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
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

  static Color cardDetails(BuildContext context, Wallet wallet) {
    final isTestnet = wallet.isTestnet;
    final isLiquid = wallet.isLiquid;
    final watchOrSignsRemotely = wallet.isWatchOnly || wallet.signsRemotely;

    final watchonlyColor = context.colour.secondary;

    if (watchOrSignsRemotely && !isTestnet) return watchonlyColor;
    if (watchOrSignsRemotely && isTestnet) return watchonlyColor;

    if (isLiquid) return context.colour.tertiary;

    if (isTestnet) return context.colour.onTertiary;
    return context.colour.onTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.select(
      (WalletBloc bloc) =>
          localSignersOnly
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

    return Padding(
      padding: padding ?? const EdgeInsets.all(13.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in wallets) ...[
            WalletCard(
              tagColor: cardDetails(context, w),
              title: w.displayLabel,
              description: w.walletTypeString,
              balanceSat: w.balanceSat.toInt(),
              isSyncing: syncStatus[w.id] ?? false,
              fiatCurrency: fiatCurrency,
              onTap: () => onTap?.call(w),
            ),
            const Gap(8),
          ],
          if (isArkWalletSetup) ...[
            WalletCard(
              tagColor: context.colour.primary,
              title: 'Ark Instant payments',
              description: 'Experimental',
              balanceSat: arkBalanceSat,
              isSyncing: isArkWalletLoading,
              onTap: () => context.pushNamed(ArkRoute.arkWalletDetail.name),
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
