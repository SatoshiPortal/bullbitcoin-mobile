import 'package:transactions/transactions.dart';

import 'dart:async';

import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';

import 'package:settings/settings.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_consolidation.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:overview/overview.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullDisclosureLink,
        BullPullableBody,
        BullShapesX,
        BullText,
        Gap,
        BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDetailScreen extends StatelessWidget {
  const WalletDetailScreen({
    super.key,
    required this.walletId,
    required this.onOpenCoins,
    required this.loadCoinSummary,
    required this.scopeWalletHistory,
  });

  final String walletId;
  final Widget Function(String walletId, Widget child) scopeWalletHistory;
  final Future<void> Function(BuildContext context, Wallet wallet) onOpenCoins;
  final Future<Result<CoinSummary, CoinsFailure>> Function(String)
  loadCoinSummary;

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

    final balanceSat = wallet?.balanceSat;
    return OverviewDetail(
      walletName: walletName,
      settings: IconButton(
        tooltip: context.loc.settingsWalletSettingsTitle,
        onPressed: () =>
            SettingsNavigation.openWalletDetails(context, walletId: walletId),
        icon: Image.asset(
          Assets.icons.settingsLine.path,
          width: 24,
          height: 24,
          color: context.appColors.onSurface,
        ),
      ),
      isLoading: wallet == null,
      unavailableMessage: context.loc.walletLoadFailed,
      body: wallet == null || balanceSat == null
          ? null
          : scopeWalletHistory(
              walletId,
              Builder(
                builder: (context) => BullPullableBody(
                  onRefresh: () async {
                    unawaited(BitcoinPriceFeature.refresh(context));
                    await WalletHistoryScope.refresh(
                      context,
                      context.read<WalletBloc>().refresh,
                    );
                  },
                  slivers: [
                    SliverToBoxAdapter(
                      child: WalletDetailBalanceCard(
                        background: AssetImage(
                          wallet.isLiquid
                              ? Assets.backgrounds.bgInstantWallet.path
                              : Assets.backgrounds.bgSecureWallet.path,
                        ),
                        isLiquid: wallet.isLiquid,
                        signer: wallet.signer,
                        balanceText: WalletDetailBalanceAmount(
                          balanceSat: balanceSat.toInt(),
                        ),
                        eyeToggle: Builder(
                          builder: (context) => EyeToggle(
                            hideAmounts: context.select(
                              (WalletBloc bloc) =>
                                  bloc.state.amountDisplay?.hideAmounts,
                            ),
                            showLabel: context.loc.walletShowAmountsTooltip,
                            hideLabel: context.loc.walletHideAmountsTooltip,
                            onChanged: (hide) =>
                                Settings.setAmountsHidden(context, hide),
                          ),
                        ),
                        fiatBalance: HomeFiatBalance(
                          onCurrencyChanged: Settings.changeDisplayCurrency,
                          balanceSat: balanceSat.toInt(),
                        ),
                        syncingIndicator: const TxsSyncingIndicator(),
                      ),
                    ),
                    if (wallet.isLiquid)
                      SliverToBoxAdapter(
                        child: WalletConsolidation.banner(context, wallet),
                      ),
                    const SliverToBoxAdapter(child: Gap(8)),
                    SliverToBoxAdapter(
                      child: _CoinsEntryTile(
                        wallet: wallet,
                        onOpenCoins: onOpenCoins,
                        loadCoinSummary: loadCoinSummary,
                      ),
                    ),
                    if (wallet.isLiquid)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: BullDisclosureLink(
                            label: context.loc.walletLiquidRiskDisclosureLabel,
                            semanticLabel:
                                context.loc.liquidRiskDisclosureSemanticLabel,
                            title: context.loc.liquidRiskDisclosureTitle,
                            body: context.loc.liquidRiskDisclosureBody,
                            closeLabel: context.loc.closeDialogButton,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: Gap(16)),
                    const WalletDetailTxsList(sliver: true),
                  ],
                ),
              ),
            ),
      bottomActions: WalletBottomButtons(wallet: wallet),
    );
  }
}

/// Tappable "Manage coins" entry shown on Bitcoin wallet-detail screens.
/// Navigates to the Coins (UTXO) view and surfaces the wallet's UTXO count and
/// frozen total as a subtitle. Hidden for Liquid (freeze-exclusion plumbing
/// exists for Bitcoin only); shown for watch-only Bitcoin wallets.
class _CoinsEntryTile extends StatefulWidget {
  const _CoinsEntryTile({
    required this.wallet,
    required this.onOpenCoins,
    required this.loadCoinSummary,
  });

  final Wallet wallet;
  final Future<void> Function(BuildContext context, Wallet wallet) onOpenCoins;
  final Future<Result<CoinSummary, CoinsFailure>> Function(String)
  loadCoinSummary;

  @override
  State<_CoinsEntryTile> createState() => _CoinsEntryTileState();
}

class _CoinsEntryTileState extends State<_CoinsEntryTile> {
  /// Last loaded coin summary; null until the first load resolves. Retained across
  /// reloads so the subtitle never blanks mid-refresh (no flicker).
  CoinSummary? _summary;

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
    final result = await widget.loadCoinSummary(widget.wallet.id);
    if (result case Ok(:final value) when mounted) {
      setState(() => _summary = value);
    }
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
    final radius = BorderRadius.circular(context.bullShapes.card);
    final summary = _summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: radius,
        onTap: () async {
          await widget.onOpenCoins(context, widget.wallet);
          if (mounted) _reload();
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
                                BullText(
                                  context.loc.walletButtonCoins,
                                  style: context.bullType.body
                                      .copyWith(fontWeight: FontWeight.w500)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (summary != null) ...[
                                  const Gap(2),
                                  CoinsEntrySubtitle(
                                    utxoCount: summary.count,
                                    frozenSat: summary.frozenSat,
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
