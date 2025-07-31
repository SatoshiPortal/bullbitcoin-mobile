import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RecoveredWalletCards extends StatelessWidget {
  final List<Wallet> wallets;

  const RecoveredWalletCards({required this.wallets, super.key});

  Color _cardDetails(BuildContext context, Wallet wallet) {
    final isTestnet = wallet.isTestnet;
    final isLiquid = wallet.isLiquid;
    final isWatchOnly = wallet.isWatchOnly;
    final watchonlyColor = context.colour.secondary;
    if (isWatchOnly) return watchonlyColor;
    if (isLiquid) return context.colour.tertiary;
    return isTestnet ? context.colour.onTertiary : context.colour.onTertiary;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in wallets) ...[
            WalletCard(
              tagColor: _cardDetails(context, w),
              title: w.label ?? '',
              description: w.walletTypeString,
              wallet: w,
              isSyncing: false,
              onTap: () {},
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
