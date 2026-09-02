import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/buttons/eye_toggle.dart';
import 'package:bb_mobile/core/widgets/buttons/receive_send_buttons.dart';
import 'package:bb_mobile/core/widgets/cards/home_fiat_balance.dart';
import 'package:bb_mobile/core/widgets/cards/wallet_detail_balance_card.dart';
import 'package:bb_mobile/core/widgets/lists/transactions_by_day_list.dart';
import 'package:bb_mobile/core/widgets/lists/tx_list_item.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_tx_list_item.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/features/sp/domain/sp_scan_policy.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class SpWalletDetailScreen extends StatelessWidget {
  const SpWalletDetailScreen({
    super.key,
    required this.exitRedirectPath,
    this.onSend,
  });

  /// Where the back button leaves SP for; supplied by the composition root so
  /// this screen never imports another feature's router.
  final String exitRedirectPath;

  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpCubit>();
    final state = context.watch<SpCubit>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(exitRedirectPath)),
        title: Text(
          context.loc.spWalletDetailTitle,
          style: context.font.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              Assets.icons.settingsLine.path,
              width: 24,
              height: 24,
              color: context.appColors.onSurface,
            ),
            onPressed: () => context.pushNamed(SpRoute.spSettings.name),
          ),
        ],
      ),
      body: SafeArea(
        child: BBPullableBody(
          onRefresh: cubit.load,
          slivers: [
            SliverToBoxAdapter(
              child: WalletDetailBalanceCard(
                isLiquid: false,
                signer: SignerEntity.local,
                balanceText: CurrencyText(
                  state.totalBalance.value.toInt(),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: context.appColors.onPrimary,
                  ),
                  showFiat: false,
                ),
                eyeToggle: const EyeToggle(),
                fiatBalance: HomeFiatBalance(
                  balanceSat: state.totalBalance.value.toInt(),
                ),
              ),
            ),
            if (state.isLoading)
              SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  backgroundColor: context.appColors.surface,
                  color: context.appColors.primary,
                ),
              ),
            if (state.isScanning)
              SliverToBoxAdapter(child: _SpScanStatusStrip(state: state))
            // Only when the user has to act. With auto scanning keeping up
            // there is nothing to say, so no row at all.
            else if (state.needsScanNudge)
              SliverToBoxAdapter(
                child: _SpScanNudgeCard(
                  height: state.lastScannedHeight!,
                  chainTip: state.chainTip!,
                ),
              ),
            if (state.headerValidationStatus ==
                    SpHeaderValidationStatus.validating ||
                state.headerValidationStatus ==
                    SpHeaderValidationStatus.reconnecting ||
                state.headerValidationStatus ==
                    SpHeaderValidationStatus.failed) ...[
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
          child: ReceiveSendButtons(
            receiveLabel: context.loc.spReceive,
            sendLabel: context.loc.spSend,
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
    final failed =
        state.headerValidationStatus == SpHeaderValidationStatus.failed;
    final progress = state.headerValidationProgress;
    final percent = (progress * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: failed
                ? context.appColors.errorContainer
                : context.appColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                failed ? Icons.warning_amber_rounded : Icons.verified_outlined,
                color: failed
                    ? context.appColors.error
                    : context.appColors.primary,
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
                            style: context.font.bodyMedium?.copyWith(
                              color: failed ? context.appColors.error : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!failed)
                          Text(
                            context.loc.spScanPercent('$percent'),
                            style: context.font.bodySmall?.copyWith(
                              color: context.appColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    if (!failed) ...[
                      const Gap(6),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor:
                            context.appColors.surfaceContainerHighest,
                        color: context.appColors.success,
                      ),
                      const Gap(4),
                      Text(
                        _progressLabel(context),
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
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
    if (state.headerValidationStatus == SpHeaderValidationStatus.failed) {
      return context.loc.spHeaderValidationFailed;
    }
    if (state.headerValidationStatus == SpHeaderValidationStatus.reconnecting) {
      return context.loc.spHeaderValidationReconnecting;
    }
    return switch (state.headerValidationPhase) {
      SpHeaderValidationPhase.replay => context.loc.spHeaderValidationReplay,
      SpHeaderValidationPhase.initialSync =>
        context.loc.spHeaderValidationInitialSync,
      null => context.loc.spHeaderValidationTitle,
    };
  }

  String _progressLabel(BuildContext context) {
    final current = state.headerValidationCurrent;
    final total = state.headerValidationTo;
    if (current == null || total == null) return '';
    return context.loc.spScanBlockProgress('$current', '$total');
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
              backgroundColor: context.appColors.surface,
              color: context.appColors.primary,
            ),
            const Gap(4),
            Text(
              context.loc.spScanBlockProgress(
                '${state.scanCurrent ?? state.scanFrom}',
                '${state.scanTo}',
              ),
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
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
    final ago = timeago.format(estimate ?? DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: context.appColors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.loc.spLastScannedAgo(ago),
                  // onSurface, not outline: the card sits on a grey surface and
                  // the muted colour disappeared into it. This reads near-white
                  // in dark and dark in light, unlike a hardcoded white.
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
              ),
              const Gap(8),
              // A filled pill, deliberately unlike the outlined Receive and
              // Send actions: this is a prompt, not a peer of them. It starts
              // the scan here rather than routing away: the user stays on the
              // activity list and the card gives way to the progress strip.
              BBButton.small(
                compact: true,
                label: context.loc.spScan,
                onPressed: () => context.read<SpCubit>().scan(),
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                textStyle: context.font.labelLarge,
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
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: context.appColors.textMuted,
                ),
                const Gap(8),
                Text(
                  context.loc.spActivityEmpty,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TransactionsByDayList<SpPayment>(
      sliver: true,
      itemsByDay: state.history.isEmpty ? null : state.historyByDay,
      itemBuilder: (context, payment) =>
          TxListItem(spPaymentListItemData(context, payment)),
      loadingMessage: context.loc.transactionListLoadingTransactions,
      emptyMessage: context.loc.spActivityEmpty,
    );
  }
}
