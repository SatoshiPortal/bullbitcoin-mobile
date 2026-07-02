import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
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
                onRefresh: () => context.read<WalletBloc>().refresh(),
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
                    SliverToBoxAdapter(child: _CoinsEntryTile(wallet: wallet)),
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

/// Tappable "Manage coins" entry shown on Bitcoin wallet-detail screens.
/// Navigates to the Coins (UTXO) view and surfaces the wallet's UTXO count and
/// frozen total as a subtitle. Hidden for Liquid (freeze-exclusion plumbing
/// exists for Bitcoin only); shown for watch-only Bitcoin wallets.
class _CoinsEntryTile extends StatefulWidget {
  const _CoinsEntryTile({required this.wallet});

  final Wallet wallet;

  @override
  State<_CoinsEntryTile> createState() => _CoinsEntryTileState();
}

class _CoinsEntryTileState extends State<_CoinsEntryTile> {
  /// Last loaded utxos; null until the first load resolves. Retained across
  /// reloads so the subtitle never blanks mid-refresh (no flicker).
  List<WalletUtxo>? _utxos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// (Re)reads the wallet's utxos (no network sync — reads the synced wallet).
  /// Called on entry, after returning from the Coins screen (so a freeze /
  /// unfreeze is reflected), and when a wallet sync finishes (so a received /
  /// sent tx updates the count). Keeps the previous value visible until the
  /// new read resolves.
  Future<void> _reload() async {
    try {
      final utxos = await locator<GetWalletUtxosUsecase>().execute(
        walletId: widget.wallet.id,
      );
      if (mounted) setState(() => _utxos = utxos);
    } catch (_) {
      // Best-effort: this is a non-critical subtitle. On failure keep the last
      // known value (or show no subtitle on the first load) rather than
      // surfacing an unhandled async error.
    }
  }

  /// `{n} UTXOs · {frozen} frozen`, with the frozen clause omitted when none
  /// are frozen. (Shown only once [_utxos] has loaded — see [_buildCard].)
  String _subtitle(BuildContext context, List<WalletUtxo> utxos) {
    final utxosLabel = context.loc.walletCoinsEntryUtxoCount(utxos.length);
    final frozenSat = utxos
        .where((u) => u.isFrozen)
        .fold<BigInt>(BigInt.zero, (sum, u) => sum + u.amountSat);
    if (frozenSat <= BigInt.zero) return utxosLabel;
    final frozen = FormatAmount.btc(ConvertAmount.satsToBtc(frozenSat.toInt()));
    return '$utxosLabel · ${context.loc.walletCoinsEntryFrozen(frozen)}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      // Refresh the count/frozen subtitle when a sync finishes (received/sent).
      listenWhen: (prev, curr) => prev.isRefreshing && !curr.isRefreshing,
      listener: (context, _) => _reload(),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final radius = BorderRadius.circular(2);
    final utxos = _utxos;
    final subtitle = utxos == null ? null : _subtitle(context, utxos);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: radius,
        onTap: () async {
          await context.pushNamed(CoinsRoute.coins.name, extra: widget.wallet);
          // Reflect any freeze/unfreeze done on the Coins screen.
          _reload();
        },
        child: Container(
          decoration: BoxDecoration(
            color: context.appColors.cardBackground,
            borderRadius: radius,
            border: Border.all(color: context.appColors.border),
            boxShadow: [
              BoxShadow(
                color: context.appColors.scrim,
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
          // ClipRRect + a stretched leading bar gives the 4px bitcoin-orange
          // left accent without a non-uniform Border (which can't be combined
          // with a borderRadius).
          child: ClipRRect(
            borderRadius: radius,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: context.appColors.bitcoinOrange),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_tree,
                            size: 24,
                            color: context.appColors.bitcoinOrange,
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BBText(
                                  context.loc.walletButtonCoins,
                                  style: context.font.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const Gap(2),
                                  BBText(
                                    subtitle,
                                    style: context.font.labelMedium?.copyWith(
                                      color: context.appColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 22,
                            color: context.appColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
