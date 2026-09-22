import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletsListScreen extends StatelessWidget {
  final List<Wallet> wallets;
  final bool isLoading;

  const WalletsListScreen({
    super.key,
    required this.wallets,
    required this.isLoading,
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
                itemBuilder: (context, index) => const LoadingLineContent(),
              )
            : wallets.isEmpty
            ? Center(
                child: BBText(
                  context.loc.walletsListNoWalletsMessage,
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
                  return InkWell(
                    onTap: () {
                      context.pushNamed(
                        SettingsRoute.walletDetailsSelectedWallet.name,
                        pathParameters: {'walletId': wallet.id},
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Expanded(
                            child: BBText(
                              wallet.displayLabel(context),
                              overflow: .ellipsis,
                              style: context.font.bodyLarge?.copyWith(
                                color: context.appColors.text,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: context.appColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
