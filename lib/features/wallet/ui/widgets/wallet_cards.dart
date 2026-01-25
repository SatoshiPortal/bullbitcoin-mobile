import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/core/widgets/snap_scroll_list.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

sealed class WalletCardItem {}

class RegularWalletItem extends WalletCardItem {
  final Wallet wallet;
  RegularWalletItem(this.wallet);
}

class ArkWalletItem extends WalletCardItem {
  final int balanceSat;
  final bool isLoading;
  ArkWalletItem({required this.balanceSat, required this.isLoading});
}

class WalletCards extends StatelessWidget {
  const WalletCards({
    super.key,
    this.padding,
    this.onTap,
    this.localSignersOnly = false,
    this.fiatCurrency,
    this.useSnapScroll = true,
  });

  final EdgeInsetsGeometry? padding;
  final bool localSignersOnly;
  final Function(Wallet wallet)? onTap;
  final String? fiatCurrency;
  final bool useSnapScroll;

  static const double cardHeight = 72.0;

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

    final List<WalletCardItem> items = [
      ...wallets.map((w) => RegularWalletItem(w)),
      if (isArkWalletSetup)
        ArkWalletItem(balanceSat: arkBalanceSat, isLoading: isArkWalletLoading),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildCard(WalletCardItem item) {
      return switch (item) {
        RegularWalletItem(:final wallet) => WalletCard(
            tagColor: cardDetails(context, wallet),
            title: wallet.displayLabel(context),
            description: wallet.walletTypeString,
            balanceSat: wallet.balanceSat.toInt(),
            isSyncing: syncStatus[wallet.id] ?? false,
            fiatCurrency: fiatCurrency,
            onTap: () => onTap?.call(wallet),
          ),
        ArkWalletItem(:final balanceSat, :final isLoading) => WalletCard(
            tagColor: context.appColors.tertiary,
            title: context.loc.walletArkInstantPayments,
            description: context.loc.walletArkExperimental,
            balanceSat: balanceSat,
            isSyncing: isLoading,
            onTap: () {
              if (arkWallet == null) return;
              context.pushNamed(ArkRoute.arkWalletDetail.name);
            },
          ),
      };
    }

    if (!useSnapScroll) {
      return Padding(
        padding: padding ?? const EdgeInsets.all(13.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.map((item) => buildCard(item)).toList(),
        ),
      );
    }

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 13.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: context.appColors.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: SnapScrollList<WalletCardItem>(
          items: items,
          itemHeight: cardHeight,
          visibleItemCount: 2,
          onExpand: () {
            if (items.isNotEmpty) {
              final firstItem = items.first;
              if (firstItem is RegularWalletItem) {
                onTap?.call(firstItem.wallet);
              }
            }
          },
          itemBuilder: (context, item, index) => buildCard(item),
        ),
      ),
    );
  }
}
