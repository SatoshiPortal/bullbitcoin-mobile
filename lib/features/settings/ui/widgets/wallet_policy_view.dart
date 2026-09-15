import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/widgets/bitcoin_policy_condition.dart';
import 'package:bb_mobile/core/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, BullText, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the shared policy timeline, without owning page or bottom-sheet chrome.
/// No seed or live signing capability is inferred from the policy labels.
class WalletPolicyView extends StatelessWidget {
  final Wallet wallet;
  final String Function(BitcoinPolicyKey key)? signerName;
  final Widget Function(BuildContext context, BitcoinPolicyKey key)?
  signerBuilder;

  const WalletPolicyView({
    super.key,
    required this.wallet,
    this.signerName,
    this.signerBuilder,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(wallet.id),
    create: (_) => locator<WalletDetailsCubit>()..loadPolicy(wallet.id),
    child: BlocBuilder<WalletDetailsCubit, WalletDetailsState>(
      builder: (context, state) {
        if (state.isLoadingPolicy) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.policy case final policy?) {
          return WalletPolicyDetails(
            wallet: wallet,
            policy: policy,
            signerName: signerName,
            signerBuilder: signerBuilder,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.walletDetailsSpendingConditionsLabel,
              style: context.font.headlineMedium,
            ),
            const Gap(8),
            Text(context.loc.walletDetailsUnavailableLabel),
            TextButton(
              onPressed: () =>
                  context.read<WalletDetailsCubit>().loadPolicy(wallet.id),
              child: Text(context.loc.retry),
            ),
          ],
        );
      },
    ),
  );
}

/// One policy presentation for wallet settings, full-page viewing and recovery.
/// The caller owns scrolling and actions, and may provide verified signer status.
class WalletPolicyDetails extends StatelessWidget {
  final Wallet wallet;
  final BitcoinWalletPolicy policy;
  final String Function(BitcoinPolicyKey key)? signerName;
  final Widget Function(BuildContext context, BitcoinPolicyKey key)?
  signerBuilder;

  const WalletPolicyDetails({
    super.key,
    required this.wallet,
    required this.policy,
    this.signerName,
    this.signerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final root = policy.external.root;
    final paths =
        root is BitcoinThresholdPolicyNode &&
            root.requiresSelection &&
            root.threshold == 1
        ? root.children
        : [root];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, path) in paths.indexed)
          _SpendingPath(
            node: path,
            index: index,
            last: index == paths.length - 1,
            wallet: wallet,
            signerName: signerName,
            signerBuilder: signerBuilder,
          ),
        if (paths.length > 1)
          BullText(
            context.loc.walletPolicyEarlierOptions,
            style: context.font.bodySmall,
            color: context.appColors.textMuted,
          ),
      ],
    );
  }
}

class _SpendingPath extends StatelessWidget {
  final BitcoinPolicyNode node;
  final int index;
  final bool last;
  final Wallet wallet;
  final String Function(BitcoinPolicyKey key)? signerName;
  final Widget Function(BuildContext context, BitcoinPolicyKey key)?
  signerBuilder;

  const _SpendingPath({
    required this.node,
    required this.index,
    required this.last,
    required this.wallet,
    this.signerName,
    this.signerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Lift only an exact timelock AND signature rule into the timeline header.
    // Mixed, relative and hashlocked rules keep the complete shared condition tree.
    var rule = node;
    BitcoinAbsoluteTimelockPolicyNode? timelock;
    if (node case BitcoinThresholdPolicyNode(
      threshold: 2,
      children: [final first, final second],
    )) {
      final clock = first is BitcoinAbsoluteTimelockPolicyNode
          ? first
          : second is BitcoinAbsoluteTimelockPolicyNode
          ? second
          : null;
      final other = identical(clock, first) ? second : first;
      if (clock != null && _signatures(other) != null) {
        timelock = clock;
        rule = other;
      }
    }
    final signatures = _signatures(rule);
    final threshold = rule is BitcoinThresholdPolicyNode ? rule.threshold : 1;
    final fromStart = signatures != null && timelock == null;
    final emphasized = fromStart && index == 0;
    final foreground = emphasized
        ? context.appColors.surface
        : context.appColors.onSurface;
    String name(BitcoinSignaturePolicyNode signature) =>
        signerName?.call(signature.key) ??
        bitcoinPolicySignerName(
          context,
          signature.key,
          wallet,
          includeLocalFingerprint: true,
        );
    final title = signatures == null
        ? context.loc.walletDetailsSpendingConditionsLabel
        : signatures.length == 1
        ? context.loc.walletPolicyKeyAlone(name(signatures.single))
        : threshold < signatures.length
        ? context.loc.walletPolicyAnyKeys(threshold)
        : signatures.map(name).join(' + ');
    final timing = timelock == null
        ? fromStart
              ? context.loc.walletPolicyFromStart
              : context.loc.walletDetailsSpendingPathTitle(index + 1)
        : timelock.type == BitcoinAbsoluteTimelockType.blockHeight
        ? context.loc.walletPolicyAfterBlock(timelock.value)
        : context.loc.walletPolicyFromDate(
            formatBitcoinPolicyTimestamp(
              context,
              timelock.value,
              compact: true,
            ),
          );

    return Stack(
      key: ValueKey('policy-timeline-${node.id}'),
      children: [
        Positioned(
          top: index == 0 ? 8 : 0,
          bottom: last ? 24 : 0,
          left: 4,
          width: 1,
          child: ColoredBox(color: context.appColors.border),
        ),
        Positioned(
          top: 4,
          left: 0,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emphasized
                  ? context.appColors.primary
                  : context.appColors.surface,
              border: Border.all(color: context.appColors.primary),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 22, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BullText(
                    (index + 1).toString().padLeft(2, '0'),
                    style: context.font.bodySmall,
                    color: context.appColors.textMuted,
                  ),
                  const Gap(12),
                  Expanded(
                    child: BullText(
                      timing,
                      style: context.font.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      color: context.appColors.primary,
                    ),
                  ),
                ],
              ),
              const Gap(16),
              BullBorderedTile(
                backgroundColor: emphasized
                    ? context.appColors.onSurface
                    : context.appColors.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BullText(
                      title,
                      style: context.font.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      color: foreground,
                    ),
                    if (signatures != null) ...[
                      const Gap(8),
                      BullText(
                        context.loc.walletPolicySignatureCount(threshold),
                        style: context.font.bodySmall,
                        color: foreground,
                      ),
                    ],
                    const Gap(20),
                    BitcoinPolicyCondition(
                      node: rule,
                      describe: (node) => describeBitcoinPolicyNode(
                        context,
                        node,
                        wallet,
                        summarizeConjunctions: true,
                        includeLocalSignerFingerprint: true,
                      ),
                      textColor: foreground,
                      textStyle: context.font.bodyMedium,
                      showSignatureCombinations: true,
                      compactSignatures: signatures != null,
                      signerBuilder: signerBuilder,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<BitcoinSignaturePolicyNode>? _signatures(BitcoinPolicyNode node) =>
      switch (node) {
        BitcoinSignaturePolicyNode() => [node],
        BitcoinThresholdPolicyNode(:final children)
            when children.every(
              (child) => child is BitcoinSignaturePolicyNode,
            ) =>
          children.cast<BitcoinSignaturePolicyNode>(),
        _ => null,
      };
}
