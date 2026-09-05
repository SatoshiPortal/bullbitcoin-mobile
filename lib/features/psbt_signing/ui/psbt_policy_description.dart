import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter/material.dart';

String describePsbtPolicyNode(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet wallet,
) => switch (node) {
  BitcoinSignaturePolicyNode(:final key) => context.loc.walletPolicySignWith(
    _signerName(context, key, wallet),
  ),
  BitcoinRelativeTimelockPolicyNode(
    type: BitcoinRelativeTimelockType.blocks,
    :final value,
  ) =>
    context.loc.walletPolicyWaitBlocks(value),
  BitcoinRelativeTimelockPolicyNode(:final value) => _describeRelativeTime(
    context,
    value,
  ),
  BitcoinAbsoluteTimelockPolicyNode(
    type: BitcoinAbsoluteTimelockType.blockHeight,
    :final value,
  ) =>
    context.loc.walletPolicyAfterBlock(value),
  BitcoinAbsoluteTimelockPolicyNode(:final value) =>
    context.loc.walletPolicyAfterTimestamp(_formatTimestamp(context, value)),
  BitcoinHashlockPolicyNode() => context.loc.walletPolicyHashPreimage,
  BitcoinThresholdPolicyNode(
    threshold: final threshold,
    children: final children,
  ) =>
    describePsbtThresholdPolicy(
      context,
      threshold: threshold,
      children: children,
    ),
};

String describePsbtThresholdPolicy(
  BuildContext context, {
  required int threshold,
  required List<BitcoinPolicyNode> children,
}) {
  if (children.every((child) => child is BitcoinSignaturePolicyNode)) {
    return context.loc.walletPolicySignaturesRequired(
      threshold,
      children.length,
    );
  }
  if (threshold == children.length) {
    return context.loc.walletDetailsAllConditionsRequired;
  }
  return context.loc.walletPolicyConditionsRequired(threshold, children.length);
}

String _signerName(BuildContext context, BitcoinPolicyKey key, Wallet wallet) {
  WalletSigner? signer;
  for (final candidate in wallet.signers) {
    if (candidate.descriptorKeys.any(key.matches)) {
      signer = candidate;
      break;
    }
  }
  if (signer?.signer == SignerEntity.local) {
    return context.loc.walletPolicyThisDevice;
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
    return context.loc.walletPolicyWaitDays(duration.inDays);
  }
  if (duration.inHours > 0 && seconds % Duration.secondsPerHour == 0) {
    return context.loc.walletPolicyWaitHours(duration.inHours);
  }
  return context.loc.walletPolicyWaitMinutes(
    (seconds / Duration.secondsPerMinute).ceil(),
  );
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
