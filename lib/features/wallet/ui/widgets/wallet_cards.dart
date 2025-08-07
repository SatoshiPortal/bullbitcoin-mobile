import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletCards extends StatelessWidget {
  const WalletCards({super.key, this.onTap, this.localSignersOnly = false});

  final bool localSignersOnly;
  final Function(Wallet wallet)? onTap;

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

    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = EdgeInsets.only(
      left: screenWidth * 0.03,
      right: screenWidth * 0.03,
      top: screenWidth * 0.01,
      bottom: screenWidth * 0.01,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in wallets) ...[
          Padding(
            padding: responsivePadding,
            child: WalletCard(
              tagColor: cardDetails(context, w),
              title: w.displayLabel,
              description: w.walletTypeString,
              wallet: w,
              isSyncing: syncStatus[w.id] ?? false,
              onTap: () => onTap?.call(w),
            ),
          ),
        ],
      ],
    );
  }
}
