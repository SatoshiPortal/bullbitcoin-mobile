import 'dart:async';

import 'package:bull_ui/bull_ui.dart' show BullPullableBody, Gap;
import 'package:material_ui/material_ui.dart';

import 'overview_detail.dart';

/// Layout for the historical wallet detail, with owner-provided content.
class OverviewWalletDetail extends StatelessWidget {
  const OverviewWalletDetail({
    super.key,
    required this.walletId,
    required this.walletName,
    required this.settings,
    required this.isLoading,
    required this.unavailableMessage,
    required this.hasBalance,
    required this.isLiquid,
    required this.scopeWalletHistory,
    required this.refreshPrice,
    required this.refreshWalletHistory,
    required this.balanceCard,
    required this.consolidation,
    required this.coinsEntry,
    required this.liquidDisclosure,
    required this.history,
    required this.bottomActions,
  });

  final String walletId;
  final String walletName;
  final Widget settings;
  final bool isLoading;
  final String unavailableMessage;
  final bool hasBalance;
  final bool isLiquid;
  final Widget Function(String walletId, Widget child) scopeWalletHistory;
  final Future<void> Function(BuildContext context) refreshPrice;
  final Future<void> Function(BuildContext context) refreshWalletHistory;
  final WidgetBuilder balanceCard;
  final WidgetBuilder consolidation;
  final WidgetBuilder coinsEntry;
  final WidgetBuilder liquidDisclosure;
  final WidgetBuilder history;
  final Widget bottomActions;

  @override
  Widget build(BuildContext context) => OverviewDetail(
    walletName: walletName,
    settings: settings,
    isLoading: isLoading,
    unavailableMessage: unavailableMessage,
    body: !hasBalance
        ? null
        : scopeWalletHistory(
            walletId,
            Builder(
              builder: (context) => BullPullableBody(
                onRefresh: () async {
                  unawaited(refreshPrice(context));
                  await refreshWalletHistory(context);
                },
                slivers: [
                  SliverToBoxAdapter(child: balanceCard(context)),
                  if (isLiquid)
                    SliverToBoxAdapter(child: consolidation(context)),
                  const SliverToBoxAdapter(child: Gap(8)),
                  SliverToBoxAdapter(child: coinsEntry(context)),
                  if (isLiquid)
                    SliverToBoxAdapter(child: liquidDisclosure(context)),
                  const SliverToBoxAdapter(child: Gap(16)),
                  history(context),
                ],
              ),
            ),
          ),
    bottomActions: bottomActions,
  );
}
