import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_balance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class SpWalletDetailPage extends StatelessWidget {
  const SpWalletDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpCubit>();
    final state = context.watch<SpCubit>().state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.goNamed(WalletRoute.walletHome.name),
        ),
        title: Text(
          context.loc.spWalletDetailTitle,
          style: context.font.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
                balanceSat: state.totalBalance.toInt(),
                isLiquid: false,
                signer: SignerEntity.local,
                hasSyncingIndicator: false,
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
            else if (state.lastScannedHeight != null)
              SliverToBoxAdapter(
                child: _SpLastScannedStrip(
                  height: state.lastScannedHeight!,
                  chainTip: state.chainTip,
                ),
              ),
            const SliverToBoxAdapter(child: Gap(16)),
            _SpActivitySection(state: state),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
          child: const _SpBottomButtons(),
        ),
      ),
    );
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

class _SpLastScannedStrip extends StatelessWidget {
  const _SpLastScannedStrip({required this.height, this.chainTip});
  final int height;
  final int? chainTip;

  @override
  Widget build(BuildContext context) {
    final tip = chainTip;
    final String label;
    if (tip != null) {
      // Estimate the scanned-tip age from how far behind the chain tip it is
      // (no per-block timestamp is stored).
      final blocksBehind = (tip - height) > 0 ? tip - height : 0;
      final est = DateTime.now().subtract(
        Duration(minutes: blocksBehind * SpConfig.minutesPerBlock),
      );
      label = context.loc.spLastScannedAtBlockAgo(
        '$height',
        timeago.format(est),
      );
    } else {
      label = context.loc.spLastScannedAtBlockTapToRescan('$height');
    }
    return GestureDetector(
      onTap: () => context.pushNamed(SpRoute.spScan.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          label,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.outline,
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
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(context.loc.spActivityTitle, style: context.font.titleSmall),
          ),
          const Gap(8),
          if (state.history.isEmpty && !state.isLoading)
            Center(
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
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.history.length,
              itemBuilder: (context, index) {
                final payment = state.history[index];
                return _SpPaymentTile(payment: payment);
              },
            ),
        ],
      ),
    );
  }
}

class _SpPaymentTile extends StatelessWidget {
  const _SpPaymentTile({required this.payment});
  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final isIncoming = payment.direction == SpPaymentDirection.receive;
    return ListTile(
      leading: Icon(
        isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIncoming ? context.appColors.success : context.appColors.error,
      ),
      title: Text(
        context.loc.spSendSatsAmount(
          FormatAmount.satsGrouped(payment.amountSat.toInt()),
        ),
      ),
      subtitle: Text(
        payment.height != null
            ? context.loc.spBlockLabel('${payment.height}')
            : context.loc.spUnconfirmed,
      ),
      trailing: payment.timestamp != null
          ? Text(
              _formatDate(payment.timestamp!.toInt()),
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            )
          : null,
      onTap: () =>
          context.pushNamed(SpRoute.spTransactionDetails.name, extra: payment),
    );
  }

  String _formatDate(int timestampSeconds) => timeago.format(
    DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
  );
}

class _SpBottomButtons extends StatelessWidget {
  const _SpBottomButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            iconFirst: true,
            label: context.loc.spReceive,
            onPressed: () => context.pushNamed(SpRoute.spReceive.name),
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_upward,
            iconFirst: true,
            label: context.loc.spSend,
            onPressed: () => context.pushNamed(SpRoute.spSendRecipient.name),
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.search,
            iconFirst: true,
            label: context.loc.spScan,
            // Navigate only: the scan view itself starts the scan on an
            // explicit tap (preserves the no-auto-scan invariant).
            onPressed: () => context.pushNamed(SpRoute.spScan.name),
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
      ],
    );
  }
}
