import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletsListScreen extends StatelessWidget {
  const WalletsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((WalletBloc bloc) => bloc.state.wallets);
    final isLoading = context.select(
      (WalletBloc bloc) => bloc.state.status == WalletStatus.loading,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet details')),
      body: SafeArea(
        child:
            isLoading
                ? ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 2,
                  itemBuilder: (context, index) => const LoadingLineContent(),
                )
                : wallets.isEmpty
                ? Center(
                  child: BBText(
                    'No wallets found',
                    style: context.font.bodyLarge?.copyWith(
                      color: context.colour.outlineVariant,
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
                          SettingsRoute.walletOptions.name,
                          pathParameters: {'walletId': wallet.id},
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: BBText(
                                wallet.displayLabel,
                                overflow: TextOverflow.ellipsis,
                                style: context.font.bodyLarge?.copyWith(
                                  color: context.colour.outlineVariant,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.black,
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
