import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSettingsEntryItem, BullShimmerLine, BullText;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletsListScreen extends StatelessWidget {
  final List<Wallet> wallets;
  final bool isLoading;
  final String? failureMessage;

  const WalletsListScreen({
    super.key,
    required this.wallets,
    required this.isLoading,
    this.failureMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.walletsListTitle)),
      body: SafeArea(
        child: isLoading
            ? ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: 2,
                itemBuilder: (context, index) => const BullShimmerLine(),
              )
            : wallets.isEmpty
            ? Center(
                child: BullText(
                  failureMessage ?? context.loc.walletsListNoWalletsMessage,
                  style: context.font.bodyLarge?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  return BullSettingsEntryItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: wallet.displayLabel(context),
                    onTap: () => context.pushNamed(
                      SettingsRoute.walletDetailsSelectedWallet.name,
                      pathParameters: {'walletId': wallet.id},
                    ),
                  );
                },
              ),
      ),
    );
  }
}
