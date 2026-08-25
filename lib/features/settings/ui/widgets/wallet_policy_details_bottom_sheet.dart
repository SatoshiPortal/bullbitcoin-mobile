import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class WalletPolicyDetailsBottomSheet extends StatelessWidget {
  final Wallet wallet;
  final BitcoinWalletPolicy policy;

  const WalletPolicyDetailsBottomSheet({
    super.key,
    required this.wallet,
    required this.policy,
  });

  static Future<void> show(
    BuildContext context, {
    required Wallet wallet,
    required BitcoinWalletPolicy policy,
  }) => BlurredBottomSheet.show(
    context: context,
    child: WalletPolicyDetailsBottomSheet(wallet: wallet, policy: policy),
  );

  @override
  Widget build(BuildContext context) {
    final root = policy.external.root;
    final pathSelector =
        root is BitcoinThresholdPolicyNode &&
            root.requiresSelection &&
            root.threshold == 1
        ? root
        : null;
    final paths = pathSelector?.children;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: BBText(
                  context.loc.walletDetailsSpendingConditionsLabel,
                  style: context.font.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: context.loc.closeDialogButton,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Gap(16),
          if (paths != null) ...[
            BBText(
              context.loc.walletDetailsAvailableSpendingPaths,
              style: context.font.bodyMedium,
              color: context.appColors.textMuted,
            ),
            const Gap(16),
            for (final (index, path) in paths.indexed) ...[
              _SpendingPath(
                title: context.loc.walletDetailsSpendingPathTitle(index + 1),
                node: path,
                wallet: wallet,
              ),
              if (index != paths.length - 1) const Gap(12),
            ],
          ] else
            _SpendingPath(node: root, wallet: wallet),
        ],
      ),
    );
  }
}

class _SpendingPath extends StatelessWidget {
  final String? title;
  final BitcoinPolicyNode node;
  final Wallet wallet;

  const _SpendingPath({this.title, required this.node, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return BorderedTappableTile(
      backgroundColor: context.appColors.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (title != null) ...[
            BBText(
              title!,
              style: context.font.bodyLarge?.copyWith(fontWeight: .w600),
            ),
            const Gap(12),
          ],
          _PolicyNodeDetails(node: node, wallet: wallet),
        ],
      ),
    );
  }
}

class _PolicyNodeDetails extends StatelessWidget {
  final BitcoinPolicyNode node;
  final Wallet wallet;

  const _PolicyNodeDetails({required this.node, required this.wallet});

  @override
  Widget build(BuildContext context) {
    if (node case BitcoinThresholdPolicyNode(
      :final threshold,
      :final children,
    )) {
      final signaturesOnly = children.every(
        (child) => child is BitcoinSignaturePolicyNode,
      );
      return Column(
        crossAxisAlignment: .stretch,
        children: [
          BBText(
            signaturesOnly
                ? context.loc.walletPolicySignaturesRequired(
                    threshold,
                    children.length,
                  )
                : threshold == children.length
                ? context.loc.walletDetailsAllConditionsRequired
                : context.loc.walletDetailsCompleteConditions(
                    threshold,
                    children.length,
                  ),
            style: context.font.bodyMedium?.copyWith(fontWeight: .w500),
          ),
          const Gap(8),
          for (final (index, child) in children.indexed) ...[
            _PolicyCondition(node: child, wallet: wallet),
            if (index != children.length - 1) const Gap(8),
          ],
        ],
      );
    }

    return _PolicyCondition(node: node, wallet: wallet);
  }
}

class _PolicyCondition extends StatelessWidget {
  final BitcoinPolicyNode node;
  final Wallet wallet;

  const _PolicyCondition({required this.node, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: context.appColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: node is BitcoinThresholdPolicyNode
              ? _PolicyNodeDetails(node: node, wallet: wallet)
              : BBText(
                  _describeLeaf(context, node, wallet),
                  style: context.font.bodyMedium,
                  color: context.appColors.onSurface,
                ),
        ),
      ],
    );
  }
}

String _describeLeaf(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet wallet,
) => switch (node) {
  BitcoinSignaturePolicyNode(:final key) => context.loc.sendPolicySignWith(
    _signerName(context, key, wallet),
  ),
  BitcoinRelativeTimelockPolicyNode(
    type: BitcoinRelativeTimelockType.blocks,
    :final value,
  ) =>
    context.loc.walletDetailsRelativeBlocksCondition(value),
  BitcoinRelativeTimelockPolicyNode(:final value) => _describeRelativeTime(
    context,
    value,
  ),
  BitcoinAbsoluteTimelockPolicyNode(
    type: BitcoinAbsoluteTimelockType.blockHeight,
    :final value,
  ) =>
    context.loc.walletDetailsAbsoluteBlockCondition(value),
  BitcoinAbsoluteTimelockPolicyNode(:final value) =>
    context.loc.walletDetailsAbsoluteTimeCondition(
      _formatTimestamp(context, value),
    ),
  BitcoinHashlockPolicyNode() => context.loc.sendPolicyHashPreimage,
  BitcoinThresholdPolicyNode() => throw StateError(
    'Threshold policies must be rendered as groups',
  ),
};

String _signerName(BuildContext context, BitcoinPolicyKey key, Wallet wallet) {
  WalletSigner? signer;
  for (final candidate in wallet.signers) {
    if (candidate.descriptorKeys.any(key.matches)) {
      signer = candidate;
      break;
    }
  }
  if (signer?.signer == SignerEntity.local) {
    return context.loc.importWatchOnlyBullMobileDevice;
  }
  if (signer?.signerDevice != null) {
    return signer!.signerDevice!.displayName;
  }
  if (signer != null && signer.displayFingerprint.isNotEmpty) {
    return signer.displayFingerprint;
  }
  final value = key.value.toUpperCase();
  return value.length <= 8 ? value : value.substring(0, 8);
}

String _describeRelativeTime(BuildContext context, int seconds) {
  final duration = Duration(seconds: seconds);
  if (duration.inDays > 0 && seconds % Duration.secondsPerDay == 0) {
    return context.loc.walletDetailsRelativeDaysCondition(duration.inDays);
  }
  if (duration.inHours > 0 && seconds % Duration.secondsPerHour == 0) {
    return context.loc.walletDetailsRelativeHoursCondition(duration.inHours);
  }
  final minutes = (seconds / Duration.secondsPerMinute).ceil();
  return context.loc.walletDetailsRelativeMinutesCondition(minutes);
}

String _formatTimestamp(BuildContext context, int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    timestamp * Duration.millisecondsPerSecond,
    isUtc: true,
  ).toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(date)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}
