import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/coins/ui/coins_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_balance_card.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_txs_list.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletDetailScreen extends StatelessWidget {
  const WalletDetailScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc bloc) {
      try {
        return bloc.state.wallets.firstWhere((w) => w.id == walletId);
      } catch (e) {
        return null;
      }
    });
    final walletName = wallet != null ? wallet.displayLabel(context) : '';

    return Scaffold(
      appBar: AppBar(
        title: walletName.isEmpty
            ? const LoadingLineContent(width: 150)
            : BBText(walletName, style: context.font.headlineMedium),
        actions: [
          IconButton(
            onPressed: () {
              context.pushNamed(
                SettingsRoute.walletOptions.name,
                pathParameters: {'walletId': walletId},
              );
            },
            icon: const Icon(CupertinoIcons.settings),
          ),
        ],
      ),
      body: wallet == null
          ? const LoadingBoxContent(height: 100)
          : BlocProvider<TransactionsCubit>(
              create: (_) =>
                  locator<TransactionsCubit>(param1: walletId)..loadTxs(),
              child: BBPullableBody(
                onRefresh: () async {
                  // User gesture — bypass the coordinator throttle.
                  final bloc = context.read<WalletBloc>();
                  bloc.add(const WalletRefreshed(force: true));
                  await bloc.stream.firstWhere((state) => !state.isRefreshing);
                },
                slivers: [
                  SliverToBoxAdapter(
                    child: WalletDetailBalanceCard(
                      balanceSat: wallet.balanceSat.toInt(),
                      isLiquid: wallet.isLiquid,
                      signer: wallet.signer,
                    ),
                  ),
                  if (wallet.isBitcoin) ...[
                    const SliverToBoxAdapter(child: Gap(8)),
                    SliverToBoxAdapter(
                      child: _CoinsEntryTile(wallet: wallet),
                    ),
                  ],
                  const SliverToBoxAdapter(child: Gap(16)),
                  const WalletDetailTxsList(sliver: true),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
          child: WalletBottomButtons(wallet: wallet),
        ),
      ),
    );
  }
}

/// Tappable "Coins" entry shown on Bitcoin wallet-detail screens. Navigates to
/// the Coins (UTXO) view. Hidden for Liquid (freeze-exclusion plumbing exists
/// for Bitcoin only); shown for watch-only Bitcoin wallets.
class _CoinsEntryTile extends StatelessWidget {
  const _CoinsEntryTile({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            context.pushNamed(CoinsRoute.coins.name, extra: wallet),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.surfaceContainer),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 20,
                color: context.appColors.onSurface,
              ),
              const Gap(12),
              Expanded(
                child: BBText(
                  context.loc.walletButtonCoins,
                  style: context.font.bodyLarge,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.appColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
