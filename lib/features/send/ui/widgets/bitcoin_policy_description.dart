import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter/material.dart';

bool bitcoinPolicyCanChoosePathNow(SendState state) =>
    state.bitcoinPolicyPathRequirements.every(
      (selector) =>
          Iterable<int>.generate(selector.options.length)
              .where(
                (index) => state
                    .bitcoinPolicyOptionStatus(
                      requirement: selector,
                      optionIndex: index,
                    )
                    .available,
              )
              .length >=
          selector.threshold,
    );

bool bitcoinPolicySelectorHasChoice(
  SendState state,
  BitcoinPolicyPathRequirement selector, {
  BitcoinPolicySelection? selection,
}) =>
    Iterable<int>.generate(selector.options.length)
        .where(
          (index) => state
              .bitcoinPolicyOptionStatus(
                requirement: selector,
                optionIndex: index,
                selection: selection,
              )
              .available,
        )
        .length >
    selector.threshold;

String bitcoinPolicySelectorInstruction(
  BuildContext context,
  BitcoinPolicyPathRequirement selector,
) {
  final signaturesOnly = selector.options.every(
    (option) => option is BitcoinSignaturePolicyNode,
  );
  if (signaturesOnly) {
    return context.loc.sendPolicyChooseSignatures(selector.threshold);
  }
  if (selector.threshold == 1) return context.loc.sendPolicyChooseOneOption;
  return context.loc.sendPolicyChooseConditions(
    selector.threshold,
    selector.options.length,
  );
}

String describeBitcoinPolicyOptionStatus(
  BuildContext context,
  SendState state,
  BitcoinPolicyNode option,
  BitcoinPolicyOptionStatus status,
) {
  final amountVariesByUtxo = _containsRelativeTimelock(option);
  final activation = status.activation;
  final availableNow =
      amountVariesByUtxo && status.availableAmountSat > BigInt.zero
      ? context.loc.sendPolicyAmountAvailableNow(
          _formatPolicyAmount(state, status.availableAmountSat),
        )
      : context.loc.sendPolicyAvailableNow;
  if (activation == null) {
    return status.available
        ? availableNow
        : context.loc.sendPolicyUnavailableForFunds;
  }

  final laterAmount =
      amountVariesByUtxo && status.activatingAmountSat > BigInt.zero
      ? _formatPolicyAmount(state, status.activatingAmountSat)
      : null;
  final later = switch (activation.type) {
    BitcoinPolicyActivationType.absoluteBlock =>
      context.loc.sendPolicyAvailableAtBlock(activation.value),
    BitcoinPolicyActivationType.absoluteTime =>
      context.loc.sendPolicyAvailableAfter(
        formatBitcoinPolicyTimestamp(context, activation.value),
      ),
    BitcoinPolicyActivationType.relativeBlocks when laterAmount != null =>
      status.available
          ? context.loc.sendPolicyAnotherAmountAvailableInBlocks(
              laterAmount,
              activation.value,
            )
          : context.loc.sendPolicyAmountAvailableInBlocks(
              laterAmount,
              activation.value,
            ),
    BitcoinPolicyActivationType.relativeTime when laterAmount != null =>
      status.available
          ? context.loc.sendPolicyAnotherAmountAvailableAfter(
              laterAmount,
              formatBitcoinPolicyTimestamp(context, activation.value),
            )
          : context.loc.sendPolicyAmountAvailableAfter(
              laterAmount,
              formatBitcoinPolicyTimestamp(context, activation.value),
            ),
    BitcoinPolicyActivationType.relativeBlocks =>
      context.loc.sendPolicyAuthorizationAvailableInBlocks(activation.value),
    BitcoinPolicyActivationType.relativeTime =>
      context.loc.sendPolicyAuthorizationAvailableAtTime(
        formatBitcoinPolicyTimestamp(context, activation.value),
      ),
  };
  return status.available ? '$availableNow. $later' : later;
}

String describeBitcoinPolicyAuthorization(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet? wallet,
) {
  final requirements = _authorizationRequirements(context, node, wallet);
  return requirements.isEmpty
      ? describeBitcoinPolicyNode(context, node, wallet)
      : requirements.join(' + ');
}

String describeSelectedBitcoinPolicyPath(
  BuildContext context,
  Wallet? wallet,
  SendState state,
) {
  final policy = state.bitcoinSigningPlan?.policy;
  final selection =
      state.bitcoinPolicySelection ?? const BitcoinPolicySelection.empty();
  final summaries = <String>[];
  if (policy != null) {
    final keychains = state.bitcoinSigningPlan!.inputKeychains.isEmpty
        ? const {BitcoinPolicyKeychain.external}
        : state.bitcoinSigningPlan!.inputKeychains;
    for (final keychain in keychains) {
      final root = switch (keychain) {
        BitcoinPolicyKeychain.external => policy.external.root,
        BitcoinPolicyKeychain.internal => policy.internal.root,
      };
      summaries.addAll(
        _resolvedPolicyRequirements(
          context,
          root,
          wallet,
          keychain: keychain,
          nodePath: 'root',
          selection: selection,
        ),
      );
    }
  }
  final uniqueSummaries = summaries.toSet().toList(growable: false);
  if (uniqueSummaries.isNotEmpty) return uniqueSummaries.join(' + ');
  return context.loc.sendAuthorization;
}

List<String> _resolvedPolicyRequirements(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet? wallet, {
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
}) {
  if (node case BitcoinThresholdPolicyNode(
    :final threshold,
    :final children,
    :final requiresSelection,
  )) {
    Iterable<int> selectedIndices;
    if (requiresSelection) {
      final selected = selection.choiceFor(
        keychain: keychain,
        nodePath: nodePath,
      );
      if (selected == null || selected.length != threshold) {
        return [describeBitcoinPolicyNode(context, node, wallet)];
      }
      final validSelected = selected
          .where((index) => index >= 0 && index < children.length)
          .toList(growable: false);
      if (validSelected.length != threshold) {
        return [describeBitcoinPolicyNode(context, node, wallet)];
      }
      selectedIndices = validSelected;
    } else if (threshold == children.length) {
      selectedIndices = Iterable<int>.generate(children.length);
    } else {
      return [describeBitcoinPolicyNode(context, node, wallet)];
    }

    return [
      for (final index in selectedIndices)
        ..._resolvedPolicyRequirements(
          context,
          children[index],
          wallet,
          keychain: keychain,
          nodePath: '$nodePath/$index',
          selection: selection,
        ),
    ];
  }
  return [describeBitcoinPolicyNode(context, node, wallet)];
}

String describeBitcoinPolicyNode(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet? wallet,
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
        ? children
              .map((child) => describeBitcoinPolicyNode(context, child, wallet))
              .join(' + ')
        : context.loc.walletPolicyConditionsRequired(
            threshold,
            children.length,
          ),
};

String describeBitcoinPolicyActivation(
  BuildContext context,
  BitcoinPolicyActivation activation,
) => switch (activation.type) {
  BitcoinPolicyActivationType.absoluteBlock =>
    context.loc.sendPolicyAuthorizationAvailableAtBlock(activation.value),
  BitcoinPolicyActivationType.relativeBlocks =>
    context.loc.sendPolicyAuthorizationAvailableInBlocks(activation.value),
  BitcoinPolicyActivationType.absoluteTime ||
  BitcoinPolicyActivationType.relativeTime =>
    context.loc.sendPolicyAuthorizationAvailableAtTime(
      formatBitcoinPolicyTimestamp(context, activation.value),
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

bool _containsRelativeTimelock(BitcoinPolicyNode node) => switch (node) {
  BitcoinRelativeTimelockPolicyNode() => true,
  BitcoinThresholdPolicyNode(:final children) => children.any(
    _containsRelativeTimelock,
  ),
  _ => false,
};

String _formatPolicyAmount(SendState state, BigInt amountSat) =>
    state.bitcoinUnit == BitcoinUnit.btc
    ? FormatAmount.btc(ConvertAmount.satsToBtc(amountSat.toInt()))
    : FormatAmount.sats(amountSat.toInt());

List<String> _authorizationRequirements(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet? wallet,
) => switch (node) {
  BitcoinSignaturePolicyNode(:final key) => [
    context.loc.walletPolicySignWith(_signerName(context, key, wallet)),
  ],
  BitcoinHashlockPolicyNode() => [context.loc.walletPolicyHashPreimage],
  BitcoinAbsoluteTimelockPolicyNode() ||
  BitcoinRelativeTimelockPolicyNode() => const [],
  BitcoinThresholdPolicyNode(
    threshold: final threshold,
    children: final children,
  ) =>
    threshold == children.length
        ? [
            for (final child in children)
              ..._authorizationRequirements(context, child, wallet),
          ]
        : [describeBitcoinPolicyNode(context, node, wallet)],
};

String _signerName(BuildContext context, BitcoinPolicyKey key, Wallet? wallet) {
  WalletSigner? signer;
  for (final candidate in wallet?.signers ?? const <WalletSigner>[]) {
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
  final minutes = (seconds / Duration.secondsPerMinute).ceil();
  return context.loc.walletPolicyWaitMinutes(minutes);
}
