import 'dart:async';

import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullPullableBody,
        BullReceiveSendButtons,
        BullShapesX,
        BullThemeX,
        BullTransactionListItem,
        BullTransactionsByDayList,
        BullTypographyX,
        Gap,
        bullTimeAgo;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/ui/widgets/sp_blindbit_behind_card.dart';
import 'package:silent/src/ui/widgets/sp_tx_list_item.dart';
import 'package:silent/src/domain/sp_scan_policy.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/presentation/sp_state.dart';
import 'package:silent/src/ui/sp_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SpWalletDetailScreen extends StatelessWidget {
  const SpWalletDetailScreen({
    super.key,
    required this.exitRedirectPath,
    required this.balanceBuilder,
    required this.settingsIconBuilder,
    this.onSend,
  });

  /// Where the back button leaves SP for; supplied by the composition root so
  /// this screen never imports another feature's router.
  final String exitRedirectPath;

  final Widget Function(BuildContext, int) balanceBuilder;
  final Widget Function(BuildContext) settingsIconBuilder;

  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpCubit>();
    final state = context.watch<SpCubit>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(exitRedirectPath)),
        title: Text(
          context.silentLoc.silentWalletDetailTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: settingsIconBuilder(context),
            tooltip: context.silentLoc.silentSettingsTitle,
            onPressed: () => context.pushNamed(SpRoute.spSettings.name),
          ),
        ],
      ),
      body: SafeArea(
        child: BullPullableBody(
          onRefresh: cubit.pullToRefresh,
          slivers: [
            SliverToBoxAdapter(
              child: balanceBuilder(context, state.totalBalance.value.toInt()),
            ),
            if (state.isLoading)
              SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  backgroundColor: context.bull.surface,
                  color: context.bull.primary,
                ),
              ),
            if (state.isScanning)
              SliverToBoxAdapter(child: _SpScanStatusStrip(state: state))
            else if (!state.isLoading && state.minBirthdayHeight != null)
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(
                    state.hasPendingScan
                        ? context.silentLoc.silentScanResumeInterrupted
                        : !state.hasScannedBefore
                        ? context.silentLoc.silentWalletScanRequired
                        : state.isCaughtUp
                        ? context.silentLoc.silentWalletScanUpToDate
                        : state.isChainTipReliable
                        ? context.silentLoc.silentWalletScanBehind
                        : context.silentLoc.silentWalletScanUnknown,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(SpRoute.spScan.name),
                ),
              ),
            if (state.lastScannedHeight case final height?
                when state.needsScanNudge && !state.isScanning)
              SliverToBoxAdapter(
                child: switch (state.chainTip) {
                  final tip? => _SpScanNudgeCard(height: height, chainTip: tip),
                  null => const SizedBox.shrink(),
                },
              ),
            if (state.blindbitLag case final lag? when lag.isBehind)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SpBlindbitBehindCard(blocksBehind: lag.blocksBehind),
                ),
              ),
            if (state.headerValidationStatus ==
                    SpHeaderValidationStatus.validating ||
                state.headerValidationStatus ==
                    SpHeaderValidationStatus.reconnecting ||
                state.headerValidationStatus ==
                    SpHeaderValidationStatus.failed ||
                state.headerValidationStatus ==
                    SpHeaderValidationStatus.invalidChain) ...[
              const SliverToBoxAdapter(child: Gap(16)),
              SliverToBoxAdapter(child: _HeaderValidationCard(state: state)),
              const SliverToBoxAdapter(child: Gap(16)),
            ] else
              const SliverToBoxAdapter(child: Gap(16)),
            _SpActivitySection(state: state),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
          child: BullReceiveSendButtons(
            receiveLabel: context.silentLoc.silentReceive,
            sendLabel: context.silentLoc.silentSend,
            onReceive: () => context.pushNamed(SpRoute.spReceive.name),
            onSend: onSend ?? () {},
          ),
        ),
      ),
    );
  }
}

class _HeaderValidationCard extends StatelessWidget {
  const _HeaderValidationCard({required this.state});

  final SpState state;

  @override
  Widget build(BuildContext context) {
    final invalidChain =
        state.headerValidationStatus == SpHeaderValidationStatus.invalidChain;
    final failed =
        invalidChain ||
        state.headerValidationStatus == SpHeaderValidationStatus.failed;
    final progress = state.headerValidationProgress;
    final percent = (progress * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        // The fix is another server, so go where it is changed.
        onTap: () => context.pushNamed(
          invalidChain
              ? SpRoute.spSettings.name
              : SpRoute.spHeaderValidation.name,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: failed ? context.bull.errorContainer : context.bull.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
          child: Row(
            children: [
              Icon(
                failed ? Icons.warning_amber_rounded : Icons.verified_outlined,
                color: failed ? context.bull.error : context.bull.primary,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _title(context),
                            style: context.bullType.body.copyWith(
                              color: failed ? context.bull.error : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!failed)
                          Text(
                            context.silentLoc.silentScanPercent('$percent'),
                            style: context.bullType.label
                                .copyWith(fontWeight: FontWeight.w400)
                                .copyWith(color: context.bull.textMuted),
                          ),
                      ],
                    ),
                    if (invalidChain) ...[
                      const Gap(4),
                      Text(
                        context
                            .silentLoc
                            .silentHeaderValidationInvalidChainDetail,
                        style: context.bullType.label
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(color: context.bull.error),
                      ),
                    ],
                    if (!failed) ...[
                      const Gap(6),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: context.bull.surfaceContainerHighest,
                        color: context.bull.success,
                      ),
                      const Gap(4),
                      Text(
                        _progressLabel(context),
                        style: context.bullType.label
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(color: context.bull.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    if (state.headerValidationStatus == SpHeaderValidationStatus.invalidChain) {
      return context.silentLoc.silentHeaderValidationInvalidChain;
    }
    if (state.headerValidationStatus == SpHeaderValidationStatus.failed) {
      return context.silentLoc.silentHeaderValidationFailed;
    }
    if (state.headerValidationStatus == SpHeaderValidationStatus.reconnecting) {
      return context.silentLoc.silentHeaderValidationReconnecting;
    }
    return switch (state.headerValidationPhase) {
      SpHeaderValidationPhase.replay =>
        context.silentLoc.silentHeaderValidationReplay,
      SpHeaderValidationPhase.initialSync =>
        context.silentLoc.silentHeaderValidationInitialSync,
      null => context.silentLoc.silentHeaderValidationTitle,
    };
  }

  String _progressLabel(BuildContext context) {
    final current = state.headerValidationCurrent;
    final total = state.headerValidationTo;
    if (current == null || total == null) return '';
    return context.silentLoc.silentScanBlockProgress('$current', '$total');
  }
}

class _SpScanStatusStrip extends StatelessWidget {
  const _SpScanStatusStrip({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(SpRoute.spScan.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: state.scanProgress,
              backgroundColor: context.bull.surface,
              color: context.bull.primary,
            ),
            const Gap(4),
            Text(
              context.silentLoc.silentScanBlockProgress(
                '${state.scanCurrent ?? state.scanFrom}',
                '${state.scanTo}',
              ),
              style: context.bullType.label
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(color: context.bull.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks the user to scan, with how long ago the wallet was last scanned. Shown
/// only when nothing else will catch it up, so it is always actionable.
class _SpScanNudgeCard extends StatefulWidget {
  const _SpScanNudgeCard({required this.height, required this.chainTip});

  final int height;
  final int chainTip;

  @override
  State<_SpScanNudgeCard> createState() => _SpScanNudgeCardState();
}

class _SpScanNudgeCardState extends State<_SpScanNudgeCard> {
  // The age is derived from the heights, so nothing rebuilds it while the user
  // sits on this screen and the chain is quiet. Tick it so "5 minutes ago" does
  // not stay put.
  static const Duration _tick = Duration(seconds: 30);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = SpScanPolicy(
      lastScannedHeight: widget.height,
      chainTip: widget.chainTip,
    ).lastScannedEstimate();
    final ago = bullTimeAgo(context, estimate ?? DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: context.bull.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.bullShapes.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.silentLoc.silentLastScannedAgo(ago),
                  // onSurface, not outline: the card sits on a grey surface and
                  // the muted colour disappeared into it. This reads near-white
                  // in dark and dark in light, unlike a hardcoded white.
                  style: context.bullType.body.copyWith(
                    color: context.bull.onSurface,
                  ),
                ),
              ),
              const Gap(8),
              // A filled pill, deliberately unlike the outlined Receive and
              // Send actions: this is a prompt, not a peer of them. It starts
              // the scan here rather than routing away: the user stays on the
              // activity list and the card gives way to the progress strip.
              BullButton.primary(
                size: BullButtonSize.small,
                compact: true,
                label: context.silentLoc.silentScan,
                onPressed: () => context.read<SpCubit>().scan(),
                textStyle: context.bullType.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpActivitySection extends StatelessWidget {
  const _SpActivitySection({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    if (state.history.isEmpty && !state.isLoading) {
      // Not the shared placeholder: that one is text only and this empty state
      // keeps its icon.
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: context.bull.textMuted),
                const Gap(8),
                Text(
                  context.silentLoc.silentActivityEmpty,
                  style: context.bullType.body.copyWith(
                    color: context.bull.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BullTransactionsByDayList<SpPayment>(
      sliver: true,
      itemsByDay: state.history.isEmpty ? null : state.historyByDay,
      dayLabel: (context, dayKey) => dayKey == spVerifyingGroupKey
          ? context.silentLoc.silentVerifying
          : null,
      itemBuilder: (context, payment) => BullTransactionListItem(
        spPaymentListItemData(context, payment),
        key: ValueKey(payment.txid),
      ),
      loadingMessage: context.silentLoc.transactionListLoadingTransactions,
      pendingLabel: context.silentLoc.transactionListPending,
      todayLabel: context.silentLoc.transactionListToday,
      yesterdayLabel: context.silentLoc.transactionListYesterday,
      emptyMessage: context.silentLoc.silentActivityEmpty,
    );
  }
}
