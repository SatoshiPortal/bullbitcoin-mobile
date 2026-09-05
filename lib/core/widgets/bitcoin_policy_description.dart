import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter/material.dart';

String describeBitcoinPolicyNode(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet? wallet, {
  bool summarizeConjunctions = false,
}) => switch (node) {
  BitcoinSignaturePolicyNode(:final key) => context.loc.walletPolicySignWith(
    bitcoinPolicySignerName(context, key, wallet),
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
    context.loc.walletPolicyAfterTimestamp(
      formatBitcoinPolicyTimestamp(context, value),
    ),
  BitcoinHashlockPolicyNode() => context.loc.walletPolicyHashPreimage,
  BitcoinThresholdPolicyNode(
    threshold: final threshold,
    children: final children,
  ) =>
    children.every((child) => child is BitcoinSignaturePolicyNode)
        ? context.loc.walletPolicySignaturesRequired(threshold, children.length)
        : threshold == children.length
        ? summarizeConjunctions
              ? context.loc.walletDetailsAllConditionsRequired
              : children
                    .map(
                      (child) =>
                          describeBitcoinPolicyNode(context, child, wallet),
                    )
                    .join(' + ')
        : context.loc.walletPolicyConditionsRequired(
            threshold,
            children.length,
          ),
};

String formatBitcoinPolicyTimestamp(BuildContext context, int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    timestamp * Duration.millisecondsPerSecond,
    isUtc: true,
  ).toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(date)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

String bitcoinPolicySignerName(
  BuildContext context,
  BitcoinPolicyKey key,
  Wallet? wallet, {
  String? localSignerName,
}) {
  WalletSigner? signer;
  for (final candidate in wallet?.signers ?? const <WalletSigner>[]) {
    if (candidate.descriptorKeys.any(key.matches)) {
      signer = candidate;
      break;
    }
  }
  if (signer?.signer == SignerEntity.local) {
    return localSignerName ?? context.loc.walletPolicyThisDevice;
  }
  if (signer?.signerDevice != null) {
    final device = signer!.signerDevice!.displayName;
    return signer.displayFingerprint.isEmpty
        ? device
        : '$device · ${signer.displayFingerprint}';
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
