import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_maturity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_node.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_path.dart';

final class BitcoinSpendingPolicy {
  final BitcoinPolicyNode root;
  final bool requiresPath;

  const BitcoinSpendingPolicy({required this.root, required this.requiresPath});
}

final class BitcoinWalletPolicy {
  final BitcoinSpendingPolicy external;
  final BitcoinSpendingPolicy internal;

  const BitcoinWalletPolicy({required this.external, required this.internal});

  bool get requiresPath => external.requiresPath || internal.requiresPath;

  bool get hasTimelock =>
      _containsTimelock(external.root) || _containsTimelock(internal.root);

  bool get hasHashlock =>
      _containsHashlock(external.root) || _containsHashlock(internal.root);

  bool get hasTimeBasedTimelock =>
      _containsTimeBasedTimelock(external.root) ||
      _containsTimeBasedTimelock(internal.root);

  List<BitcoinPolicyPathRequirement> pathRequirements(
    BitcoinPolicySelection selection,
  ) => _rawPathSelectors(selection)
      .where((requirement) {
        final choice = selection.choiceFor(
          keychain: requirement.keychain,
          nodePath: requirement.nodePath,
        );
        return choice == null ||
            choice.length != requirement.threshold ||
            choice.any((index) => index >= requirement.options.length);
      })
      .toList(growable: false);

  List<BitcoinPolicyPathRequirement> pathSelectors(
    BitcoinPolicySelection selection,
  ) {
    final selectors = _rawPathSelectors(selection);
    final externalByPath = {
      for (final selector in selectors.where(
        (selector) => selector.keychain == BitcoinPolicyKeychain.external,
      ))
        selector.nodePath: selector,
    };
    return List.unmodifiable(
      selectors.where((selector) {
        if (selector.keychain == BitcoinPolicyKeychain.external) return true;
        final externalSelector = externalByPath[selector.nodePath];
        return externalSelector == null ||
            !_sameRequirementShape(externalSelector, selector);
      }),
    );
  }

  BitcoinPolicyOptionStatus optionStatus({
    required BitcoinPolicyPathRequirement requirement,
    required int optionIndex,
    required BitcoinPolicySelection selection,
    required BitcoinPolicyMaturity maturity,
    Set<String> selectedOutpoints = const {},
  }) {
    if (optionIndex < 0 || optionIndex >= requirement.options.length) {
      throw ArgumentError.value(optionIndex, 'optionIndex');
    }
    if (!maturity.isKnown) {
      return BitcoinPolicyOptionStatus(
        available: true,
        availableAmountSat: BigInt.zero,
        activatingAmountSat: BigInt.zero,
      );
    }

    final optionNodes = <BitcoinPolicyKeychain, BitcoinPolicyNode>{
      requirement.keychain: requirement.options[optionIndex],
    };
    final otherKeychain = switch (requirement.keychain) {
      BitcoinPolicyKeychain.external => BitcoinPolicyKeychain.internal,
      BitcoinPolicyKeychain.internal => BitcoinPolicyKeychain.external,
    };
    final otherNode = _nodeAtPath(switch (otherKeychain) {
      BitcoinPolicyKeychain.external => external.root,
      BitcoinPolicyKeychain.internal => internal.root,
    }, requirement.nodePath);
    if (otherNode is BitcoinThresholdPolicyNode &&
        otherNode.requiresSelection &&
        requirement.threshold == otherNode.threshold &&
        _samePolicyOptions(requirement.options, otherNode.children)) {
      optionNodes[otherKeychain] = otherNode.children[optionIndex];
    }

    final statuses =
        <({BitcoinPolicyUtxoMaturity utxo, _NodeMaturity status})>[];
    for (final utxo in maturity.utxos) {
      if (selectedOutpoints.isNotEmpty &&
          !selectedOutpoints.contains(utxo.outpoint)) {
        continue;
      }
      final option = optionNodes[utxo.keychain];
      if (option == null) continue;
      statuses.add((
        utxo: utxo,
        status: _nodeMaturity(
          node: option,
          keychain: utxo.keychain,
          nodePath: '${requirement.nodePath}/$optionIndex',
          selection: selection,
          maturity: maturity,
          utxo: utxo,
        ),
      ));
    }

    if (statuses.isEmpty) {
      return BitcoinPolicyOptionStatus(
        available: false,
        availableAmountSat: BigInt.zero,
        activatingAmountSat: BigInt.zero,
      );
    }

    final requireEveryUtxo = selectedOutpoints.isNotEmpty;
    final hasEverySelectedUtxo =
        !requireEveryUtxo ||
        statuses
            .map((entry) => entry.utxo.outpoint)
            .toSet()
            .containsAll(selectedOutpoints);
    final available = requireEveryUtxo
        ? hasEverySelectedUtxo &&
              statuses.every((entry) => entry.status.available)
        : statuses.any((entry) => entry.status.available);
    final availableAmountSat = statuses
        .where((entry) => entry.status.available)
        .fold(BigInt.zero, (sum, entry) => sum + entry.utxo.amountSat);
    final activations = statuses
        .map((entry) => entry.status.activation)
        .whereType<BitcoinPolicyActivation>()
        .toList();
    final hasUnknownRequiredActivation =
        requireEveryUtxo &&
        (!hasEverySelectedUtxo ||
            statuses.any(
              (entry) =>
                  !entry.status.available && entry.status.activation == null,
            ));
    final activation = hasUnknownRequiredActivation || activations.isEmpty
        ? null
        : requireEveryUtxo
        ? _latestActivation(activations)
        : _earliestActivation(activations);
    final activatingAmountSat = activation == null
        ? BigInt.zero
        : requireEveryUtxo
        ? statuses.fold(BigInt.zero, (sum, entry) => sum + entry.utxo.amountSat)
        : statuses
              .where(
                (entry) => _sameActivation(entry.status.activation, activation),
              )
              .fold(BigInt.zero, (sum, entry) => sum + entry.utxo.amountSat);
    return BitcoinPolicyOptionStatus(
      available: available,
      availableAmountSat: availableAmountSat,
      activatingAmountSat: activatingAmountSat,
      activation: activation,
    );
  }

  bool selectionIsAvailable({
    required BitcoinPolicySelection selection,
    required BitcoinPolicyMaturity maturity,
    Set<String> selectedOutpoints = const {},
  }) {
    if (pathRequirements(selection).isNotEmpty) return false;
    if (!maturity.isKnown) return true;
    final candidates = maturity.utxos
        .where(
          (utxo) =>
              selectedOutpoints.isEmpty ||
              selectedOutpoints.contains(utxo.outpoint),
        )
        .toList();
    if (candidates.isEmpty) return false;
    if (selectedOutpoints.isNotEmpty &&
        !candidates
            .map((utxo) => utxo.outpoint)
            .toSet()
            .containsAll(selectedOutpoints)) {
      return false;
    }

    bool isAvailable(BitcoinPolicyUtxoMaturity utxo) => _nodeMaturity(
      node: switch (utxo.keychain) {
        BitcoinPolicyKeychain.external => external.root,
        BitcoinPolicyKeychain.internal => internal.root,
      },
      keychain: utxo.keychain,
      nodePath: 'root',
      selection: selection,
      maturity: maturity,
      utxo: utxo,
    ).available;

    return selectedOutpoints.isEmpty
        ? candidates.any(isAvailable)
        : candidates.every(isAvailable);
  }

  BitcoinPolicyActivation? nextActivation({
    required BitcoinPolicySelection selection,
    required BitcoinPolicyMaturity maturity,
    Set<String> selectedOutpoints = const {},
  }) {
    final candidates = maturity.utxos
        .where(
          (utxo) =>
              selectedOutpoints.isEmpty ||
              selectedOutpoints.contains(utxo.outpoint),
        )
        .toList();
    if (selectedOutpoints.isNotEmpty &&
        candidates.length != selectedOutpoints.length) {
      return null;
    }
    final statuses = [
      for (final utxo in candidates)
        _nodeMaturity(
          node: switch (utxo.keychain) {
            BitcoinPolicyKeychain.external => external.root,
            BitcoinPolicyKeychain.internal => internal.root,
          },
          keychain: utxo.keychain,
          nodePath: 'root',
          selection: selection,
          maturity: maturity,
          utxo: utxo,
        ),
    ];
    if (selectedOutpoints.isNotEmpty &&
        statuses.any(
          (status) => !status.available && status.activation == null,
        )) {
      return null;
    }
    final activations = [
      for (final status in statuses)
        if (!status.available && status.activation != null) status.activation!,
    ];
    if (activations.isEmpty) return null;
    return selectedOutpoints.isNotEmpty
        ? _latestActivation(activations)
        : _earliestActivation(activations);
  }

  List<BitcoinPolicyPathRequirement> _rawPathSelectors(
    BitcoinPolicySelection selection,
  ) {
    _validateSelection(selection);
    final selectors = <BitcoinPolicyPathRequirement>[];
    if (external.requiresPath) {
      _collectPathSelectors(
        node: external.root,
        keychain: BitcoinPolicyKeychain.external,
        nodePath: 'root',
        selection: selection,
        selectors: selectors,
      );
    }
    if (internal.requiresPath) {
      _collectPathSelectors(
        node: internal.root,
        keychain: BitcoinPolicyKeychain.internal,
        nodePath: 'root',
        selection: selection,
        selectors: selectors,
      );
    }
    return List.unmodifiable(selectors);
  }

  void _validateSelection(BitcoinPolicySelection selection) {
    for (final entry in selection.choices.entries) {
      final separator = entry.key.indexOf(':');
      final keychain = BitcoinPolicyKeychain.values.byName(
        entry.key.substring(0, separator),
      );
      final nodePath = entry.key.substring(separator + 1);
      final node = _nodeAtPath(switch (keychain) {
        BitcoinPolicyKeychain.external => external.root,
        BitcoinPolicyKeychain.internal => internal.root,
      }, nodePath);
      if (node is! BitcoinThresholdPolicyNode ||
          !node.requiresSelection ||
          entry.value.length > node.threshold ||
          entry.value.any((index) => index >= node.children.length)) {
        throw ArgumentError.value(entry.value, entry.key);
      }
    }
  }

  BitcoinPolicySelection select({
    required BitcoinPolicySelection current,
    required BitcoinPolicyPathRequirement requirement,
    required Iterable<int> selectedIndices,
  }) {
    final selected = selectedIndices.toSet().toList()..sort();
    if (selected.length > requirement.threshold ||
        selected.any((index) => index >= requirement.options.length)) {
      throw ArgumentError.value(selectedIndices, 'selectedIndices');
    }

    var updated = current.withChoice(
      keychain: requirement.keychain,
      nodePath: requirement.nodePath,
      selectedIndices: selected,
    );
    final otherKeychain = switch (requirement.keychain) {
      BitcoinPolicyKeychain.external => BitcoinPolicyKeychain.internal,
      BitcoinPolicyKeychain.internal => BitcoinPolicyKeychain.external,
    };
    final otherNode = _nodeAtPath(switch (otherKeychain) {
      BitcoinPolicyKeychain.external => external.root,
      BitcoinPolicyKeychain.internal => internal.root,
    }, requirement.nodePath);
    if (otherNode is BitcoinThresholdPolicyNode &&
        otherNode.requiresSelection &&
        requirement.threshold == otherNode.threshold &&
        _samePolicyOptions(requirement.options, otherNode.children)) {
      updated = updated.withChoice(
        keychain: otherKeychain,
        nodePath: requirement.nodePath,
        selectedIndices: selected,
      );
    }
    return updated;
  }

  BitcoinPolicySelection selectOnlyAvailablePaths({
    required BitcoinPolicySelection current,
    required BitcoinPolicyMaturity maturity,
    Set<String> selectedOutpoints = const {},
  }) {
    var updated = current;
    while (true) {
      var changed = false;
      for (final requirement in pathSelectors(updated)) {
        final availableIndices = [
          for (final optionIndex in Iterable<int>.generate(
            requirement.options.length,
          ))
            if (optionStatus(
              requirement: requirement,
              optionIndex: optionIndex,
              selection: updated,
              maturity: maturity,
              selectedOutpoints: selectedOutpoints,
            ).available)
              optionIndex,
        ];
        if (availableIndices.length != requirement.threshold) continue;

        final selected = updated.choiceFor(
          keychain: requirement.keychain,
          nodePath: requirement.nodePath,
        );
        if (_sameIndices(selected, availableIndices)) continue;

        updated = select(
          current: updated,
          requirement: requirement,
          selectedIndices: availableIndices,
        );
        changed = true;
      }
      if (!changed) return updated;
    }
  }

  BitcoinPolicyPath buildPath(
    BitcoinPolicySelection selection, {
    BitcoinPolicyMaturity? maturity,
  }) {
    final remaining = pathRequirements(selection);
    if (remaining.isNotEmpty) {
      throw StateError('Bitcoin policy selection is incomplete');
    }
    _validatePairedSelections(selection);

    final externalPath = <String, List<int>>{};
    final internalPath = <String, List<int>>{};
    _collectPath(
      node: external.root,
      keychain: BitcoinPolicyKeychain.external,
      nodePath: 'root',
      selection: selection,
      path: externalPath,
    );
    _collectPath(
      node: internal.root,
      keychain: BitcoinPolicyKeychain.internal,
      nodePath: 'root',
      selection: selection,
      path: internalPath,
    );
    final eligibleExternalOutpoints = maturity == null || !maturity.isKnown
        ? null
        : _eligibleOutpoints(
            policy: external,
            keychain: BitcoinPolicyKeychain.external,
            selection: selection,
            maturity: maturity,
          );
    final eligibleInternalOutpoints = maturity == null || !maturity.isKnown
        ? null
        : _eligibleOutpoints(
            policy: internal,
            keychain: BitcoinPolicyKeychain.internal,
            selection: selection,
            maturity: maturity,
          );
    return BitcoinPolicyPath(
      external: externalPath,
      internal: internalPath,
      requiresRelativeTimelock:
          _containsRelativeTimelock(
            node: external.root,
            keychain: BitcoinPolicyKeychain.external,
            nodePath: 'root',
            selection: selection,
          ) ||
          _containsRelativeTimelock(
            node: internal.root,
            keychain: BitcoinPolicyKeychain.internal,
            nodePath: 'root',
            selection: selection,
          ),
      requiredExternalKeys: _signatureKeys(
        node: external.root,
        keychain: BitcoinPolicyKeychain.external,
        nodePath: 'root',
        selection: selection,
      ),
      requiredInternalKeys: _signatureKeys(
        node: internal.root,
        keychain: BitcoinPolicyKeychain.internal,
        nodePath: 'root',
        selection: selection,
      ),
      eligibleExternalOutpoints: eligibleExternalOutpoints,
      eligibleInternalOutpoints: eligibleInternalOutpoints,
    );
  }

  void _validatePairedSelections(BitcoinPolicySelection selection) {
    final selectors = _rawPathSelectors(selection);
    final internalByPath = {
      for (final selector in selectors.where(
        (selector) => selector.keychain == BitcoinPolicyKeychain.internal,
      ))
        selector.nodePath: selector,
    };
    for (final external in selectors.where(
      (selector) => selector.keychain == BitcoinPolicyKeychain.external,
    )) {
      final internal = internalByPath[external.nodePath];
      if (internal == null || !_sameRequirementShape(external, internal)) {
        continue;
      }
      final externalChoice = selection.choiceFor(
        keychain: BitcoinPolicyKeychain.external,
        nodePath: external.nodePath,
      );
      final internalChoice = selection.choiceFor(
        keychain: BitcoinPolicyKeychain.internal,
        nodePath: internal.nodePath,
      );
      if (externalChoice == null ||
          internalChoice == null ||
          !_sameIndices(externalChoice, internalChoice)) {
        throw ArgumentError.value(
          selection.choices,
          'selection',
          'Matching receive and change policies require the same selection',
        );
      }
    }
  }

  bool canBeSatisfiedBy({
    required BitcoinPolicySelection selection,
    required bool Function(BitcoinPolicyKey key) hasSignature,
    bool Function(BitcoinHashlockPolicyNode hashlock) hasPreimage =
        _hasNoPreimage,
    Set<BitcoinPolicyKeychain> keychains = const {
      BitcoinPolicyKeychain.external,
      BitcoinPolicyKeychain.internal,
    },
  }) =>
      pathRequirements(selection).isEmpty &&
      (!keychains.contains(BitcoinPolicyKeychain.external) ||
          _canBeSatisfiedBy(
            node: external.root,
            keychain: BitcoinPolicyKeychain.external,
            nodePath: 'root',
            selection: selection,
            hasSignature: hasSignature,
            hasPreimage: hasPreimage,
          )) &&
      (!keychains.contains(BitcoinPolicyKeychain.internal) ||
          _canBeSatisfiedBy(
            node: internal.root,
            keychain: BitcoinPolicyKeychain.internal,
            nodePath: 'root',
            selection: selection,
            hasSignature: hasSignature,
            hasPreimage: hasPreimage,
          ));

  List<BitcoinPolicyKey> signatureKeys(
    BitcoinPolicySelection selection, {
    Set<BitcoinPolicyKeychain> keychains = const {
      BitcoinPolicyKeychain.external,
      BitcoinPolicyKeychain.internal,
    },
  }) => List.unmodifiable({
    if (keychains.contains(BitcoinPolicyKeychain.external))
      ..._signatureKeys(
        node: external.root,
        keychain: BitcoinPolicyKeychain.external,
        nodePath: 'root',
        selection: selection,
      ),
    if (keychains.contains(BitcoinPolicyKeychain.internal))
      ..._signatureKeys(
        node: internal.root,
        keychain: BitcoinPolicyKeychain.internal,
        nodePath: 'root',
        selection: selection,
      ),
  });

  List<BitcoinHashlockPolicyNode> requiredHashlocks(
    BitcoinPolicySelection selection,
  ) => List.unmodifiable(
    {
      for (final hashlock in [
        ..._hashlocks(
          node: external.root,
          keychain: BitcoinPolicyKeychain.external,
          nodePath: 'root',
          selection: selection,
        ),
        ..._hashlocks(
          node: internal.root,
          keychain: BitcoinPolicyKeychain.internal,
          nodePath: 'root',
          selection: selection,
        ),
      ])
        '${hashlock.type.name}:${hashlock.hash}': hashlock,
    }.values,
  );
}

final class _NodeMaturity {
  final bool available;
  final BitcoinPolicyActivation? activation;

  const _NodeMaturity({required this.available, this.activation});
}

_NodeMaturity _nodeMaturity({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
  required BitcoinPolicyMaturity maturity,
  required BitcoinPolicyUtxoMaturity utxo,
}) => switch (node) {
  BitcoinSignaturePolicyNode() => const _NodeMaturity(available: true),
  BitcoinHashlockPolicyNode() => const _NodeMaturity(available: true),
  BitcoinAbsoluteTimelockPolicyNode(
    type: BitcoinAbsoluteTimelockType.blockHeight,
    :final value,
  ) =>
    maturity.tipHeight >= value
        ? const _NodeMaturity(available: true)
        : _NodeMaturity(
            available: false,
            activation: BitcoinPolicyActivation(
              type: BitcoinPolicyActivationType.absoluteBlock,
              value: value,
              estimatedSecondsFromNow: (value - maturity.tipHeight) * 600,
            ),
          ),
  BitcoinAbsoluteTimelockPolicyNode(:final value) =>
    maturity.medianTimePast != null && maturity.medianTimePast! > value
        ? const _NodeMaturity(available: true)
        : maturity.medianTimePast == null
        ? const _NodeMaturity(available: false)
        : _NodeMaturity(
            available: false,
            activation: BitcoinPolicyActivation(
              type: BitcoinPolicyActivationType.absoluteTime,
              value: value,
              estimatedSecondsFromNow: (value - maturity.medianTimePast! + 1)
                  .clamp(0, value + 1),
            ),
          ),
  BitcoinRelativeTimelockPolicyNode(
    type: BitcoinRelativeTimelockType.blocks,
    :final value,
  ) =>
    utxo.confirmations >= value
        ? const _NodeMaturity(available: true)
        : _NodeMaturity(
            available: false,
            activation: BitcoinPolicyActivation(
              type: BitcoinPolicyActivationType.relativeBlocks,
              value: value - utxo.confirmations,
              estimatedSecondsFromNow: (value - utxo.confirmations) * 600,
            ),
          ),
  BitcoinRelativeTimelockPolicyNode(:final value) => _relativeTimeMaturity(
    value: value,
    maturity: maturity,
    utxo: utxo,
  ),
  BitcoinThresholdPolicyNode() => _thresholdMaturity(
    node: node,
    keychain: keychain,
    nodePath: nodePath,
    selection: selection,
    maturity: maturity,
    utxo: utxo,
  ),
};

_NodeMaturity _relativeTimeMaturity({
  required int value,
  required BitcoinPolicyMaturity maturity,
  required BitcoinPolicyUtxoMaturity utxo,
}) {
  final confirmationMedianTimePast = utxo.confirmationMedianTimePast;
  final medianTimePast = maturity.medianTimePast;
  if (confirmationMedianTimePast == null || medianTimePast == null) {
    return const _NodeMaturity(available: false);
  }
  final target = confirmationMedianTimePast + value;
  if (medianTimePast >= target) {
    return const _NodeMaturity(available: true);
  }
  return _NodeMaturity(
    available: false,
    activation: BitcoinPolicyActivation(
      type: BitcoinPolicyActivationType.relativeTime,
      value: target,
      estimatedSecondsFromNow: target - medianTimePast,
    ),
  );
}

_NodeMaturity _thresholdMaturity({
  required BitcoinThresholdPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
  required BitcoinPolicyMaturity maturity,
  required BitcoinPolicyUtxoMaturity utxo,
}) {
  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected != null && selected.length == node.threshold
      ? selected
      : Iterable<int>.generate(node.children.length);
  final childStatuses = [
    for (final index in childIndices)
      _nodeMaturity(
        node: node.children[index],
        keychain: keychain,
        nodePath: '$nodePath/$index',
        selection: selection,
        maturity: maturity,
        utxo: utxo,
      ),
  ];
  final availableCount = childStatuses
      .where((status) => status.available)
      .length;
  if (availableCount >= node.threshold) {
    return const _NodeMaturity(available: true);
  }
  final activations =
      childStatuses
          .map((status) => status.activation)
          .whereType<BitcoinPolicyActivation>()
          .toList()
        ..sort(_compareActivations);
  final needed = node.threshold - availableCount;
  if (activations.length < needed) {
    return const _NodeMaturity(available: false);
  }
  return _NodeMaturity(available: false, activation: activations[needed - 1]);
}

Set<String> _eligibleOutpoints({
  required BitcoinSpendingPolicy policy,
  required BitcoinPolicyKeychain keychain,
  required BitcoinPolicySelection selection,
  required BitcoinPolicyMaturity maturity,
}) => {
  for (final utxo in maturity.utxos.where((utxo) => utxo.keychain == keychain))
    if (_nodeMaturity(
      node: policy.root,
      keychain: keychain,
      nodePath: 'root',
      selection: selection,
      maturity: maturity,
      utxo: utxo,
    ).available)
      utxo.outpoint,
};

int _compareActivations(
  BitcoinPolicyActivation first,
  BitcoinPolicyActivation second,
) => first.estimatedSecondsFromNow.compareTo(second.estimatedSecondsFromNow);

BitcoinPolicyActivation _earliestActivation(
  List<BitcoinPolicyActivation> activations,
) => activations.reduce(
  (first, second) => _compareActivations(first, second) <= 0 ? first : second,
);

BitcoinPolicyActivation _latestActivation(
  List<BitcoinPolicyActivation> activations,
) => activations.reduce(
  (first, second) => _compareActivations(first, second) >= 0 ? first : second,
);

bool _sameActivation(
  BitcoinPolicyActivation? first,
  BitcoinPolicyActivation second,
) => first != null && first.type == second.type && first.value == second.value;

bool _containsTimelock(BitcoinPolicyNode node) => switch (node) {
  BitcoinAbsoluteTimelockPolicyNode() ||
  BitcoinRelativeTimelockPolicyNode() => true,
  BitcoinThresholdPolicyNode(:final children) => children.any(
    _containsTimelock,
  ),
  _ => false,
};

bool _containsHashlock(BitcoinPolicyNode node) => switch (node) {
  BitcoinHashlockPolicyNode() => true,
  BitcoinThresholdPolicyNode(:final children) => children.any(
    _containsHashlock,
  ),
  _ => false,
};

bool _containsTimeBasedTimelock(BitcoinPolicyNode node) => switch (node) {
  BitcoinAbsoluteTimelockPolicyNode(
    type: BitcoinAbsoluteTimelockType.timestamp,
  ) =>
    true,
  BitcoinRelativeTimelockPolicyNode(
    type: BitcoinRelativeTimelockType.seconds,
  ) =>
    true,
  BitcoinThresholdPolicyNode(:final children) => children.any(
    _containsTimeBasedTimelock,
  ),
  _ => false,
};

void _collectPathSelectors({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
  required List<BitcoinPolicyPathRequirement> selectors,
}) {
  if (node is! BitcoinThresholdPolicyNode || !node.requiresPath) return;

  Iterable<int> childIndices;
  if (node.requiresSelection) {
    selectors.add(
      BitcoinPolicyPathRequirement(
        keychain: keychain,
        nodePath: nodePath,
        threshold: node.threshold,
        options: node.children,
      ),
    );
    final selected = selection.choiceFor(
      keychain: keychain,
      nodePath: nodePath,
    );
    if (selected == null ||
        selected.length != node.threshold ||
        selected.any((index) => index >= node.children.length)) {
      return;
    }
    childIndices = selected;
  } else {
    childIndices = Iterable.generate(node.children.length);
  }

  for (final index in childIndices) {
    _collectPathSelectors(
      node: node.children[index],
      keychain: keychain,
      nodePath: '$nodePath/$index',
      selection: selection,
      selectors: selectors,
    );
  }
}

void _collectPath({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
  required Map<String, List<int>> path,
}) {
  if (node is! BitcoinThresholdPolicyNode || !node.requiresPath) return;

  final List<int> childIndices = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)!
      : List<int>.generate(node.children.length, (index) => index);
  if (node.requiresSelection) path[node.id] = childIndices;
  for (final index in childIndices) {
    _collectPath(
      node: node.children[index],
      keychain: keychain,
      nodePath: '$nodePath/$index',
      selection: selection,
      path: path,
    );
  }
}

bool _canBeSatisfiedBy({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
  required bool Function(BitcoinPolicyKey key) hasSignature,
  required bool Function(BitcoinHashlockPolicyNode hashlock) hasPreimage,
}) {
  if (node case final BitcoinSignaturePolicyNode signature) {
    return hasSignature(signature.key);
  }
  if (node case final BitcoinHashlockPolicyNode hashlock) {
    return hasPreimage(hashlock);
  }
  if (node is! BitcoinThresholdPolicyNode) return true;

  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected ?? Iterable.generate(node.children.length);
  var satisfied = 0;
  for (final index in childIndices) {
    if (_canBeSatisfiedBy(
      node: node.children[index],
      keychain: keychain,
      nodePath: '$nodePath/$index',
      selection: selection,
      hasSignature: hasSignature,
      hasPreimage: hasPreimage,
    )) {
      satisfied++;
    }
  }
  return satisfied >= node.threshold;
}

bool _hasNoPreimage(BitcoinHashlockPolicyNode _) => false;

Set<BitcoinPolicyKey> _signatureKeys({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
}) {
  if (node is BitcoinSignaturePolicyNode) return {node.key};
  if (node is! BitcoinThresholdPolicyNode) return const {};

  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected ?? Iterable.generate(node.children.length);
  return {
    for (final index in childIndices)
      ..._signatureKeys(
        node: node.children[index],
        keychain: keychain,
        nodePath: '$nodePath/$index',
        selection: selection,
      ),
  };
}

Set<BitcoinHashlockPolicyNode> _hashlocks({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
}) {
  if (node is BitcoinHashlockPolicyNode) return {node};
  if (node is! BitcoinThresholdPolicyNode) return const {};

  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected ?? Iterable.generate(node.children.length);
  return {
    for (final index in childIndices)
      ..._hashlocks(
        node: node.children[index],
        keychain: keychain,
        nodePath: '$nodePath/$index',
        selection: selection,
      ),
  };
}

bool _containsRelativeTimelock({
  required BitcoinPolicyNode node,
  required BitcoinPolicyKeychain keychain,
  required String nodePath,
  required BitcoinPolicySelection selection,
}) {
  if (node is BitcoinRelativeTimelockPolicyNode) return true;
  if (node is! BitcoinThresholdPolicyNode) return false;

  final selected = node.requiresSelection
      ? selection.choiceFor(keychain: keychain, nodePath: nodePath)
      : null;
  final childIndices = selected ?? Iterable.generate(node.children.length);
  return childIndices.any(
    (index) => _containsRelativeTimelock(
      node: node.children[index],
      keychain: keychain,
      nodePath: '$nodePath/$index',
      selection: selection,
    ),
  );
}

BitcoinPolicyNode? _nodeAtPath(BitcoinPolicyNode root, String nodePath) {
  if (nodePath == 'root') return root;
  var node = root;
  for (final segment in nodePath.split('/').skip(1)) {
    if (node is! BitcoinThresholdPolicyNode) return null;
    final index = int.tryParse(segment);
    if (index == null || index < 0 || index >= node.children.length) {
      return null;
    }
    node = node.children[index];
  }
  return node;
}

bool _sameSelectionShape(
  BitcoinThresholdPolicyNode first,
  BitcoinThresholdPolicyNode second,
) {
  if (first.threshold != second.threshold ||
      first.children.length != second.children.length) {
    return false;
  }
  for (var index = 0; index < first.children.length; index++) {
    if (!_samePolicyShape(first.children[index], second.children[index])) {
      return false;
    }
  }
  return true;
}

bool _sameRequirementShape(
  BitcoinPolicyPathRequirement first,
  BitcoinPolicyPathRequirement second,
) =>
    first.threshold == second.threshold &&
    _samePolicyOptions(first.options, second.options);

bool _samePolicyOptions(
  List<BitcoinPolicyNode> first,
  List<BitcoinPolicyNode> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (!_samePolicyShape(first[index], second[index])) return false;
  }
  return true;
}

bool _sameIndices(List<int>? first, List<int> second) {
  if (first == null || first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _samePolicyShape(BitcoinPolicyNode first, BitcoinPolicyNode second) {
  if (first.runtimeType != second.runtimeType) return false;
  return switch ((first, second)) {
    (
      BitcoinThresholdPolicyNode firstThreshold,
      BitcoinThresholdPolicyNode secondThreshold,
    ) =>
      _sameSelectionShape(firstThreshold, secondThreshold),
    (
      BitcoinHashlockPolicyNode(type: final firstType),
      BitcoinHashlockPolicyNode(type: final secondType),
    ) =>
      firstType == secondType,
    (
      BitcoinAbsoluteTimelockPolicyNode(
        type: final firstType,
        value: final firstValue,
      ),
      BitcoinAbsoluteTimelockPolicyNode(
        type: final secondType,
        value: final secondValue,
      ),
    ) =>
      firstType == secondType && firstValue == secondValue,
    (
      BitcoinRelativeTimelockPolicyNode(
        type: final firstType,
        value: final firstValue,
      ),
      BitcoinRelativeTimelockPolicyNode(
        type: final secondType,
        value: final secondValue,
      ),
    ) =>
      firstType == secondType && firstValue == secondValue,
    _ => true,
  };
}
