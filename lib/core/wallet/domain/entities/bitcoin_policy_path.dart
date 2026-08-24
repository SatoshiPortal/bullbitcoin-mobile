import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_node.dart';

final class BitcoinPolicyPathRequirement {
  final BitcoinPolicyKeychain keychain;
  final String nodePath;
  final int threshold;
  final List<BitcoinPolicyNode> options;

  BitcoinPolicyPathRequirement({
    required this.keychain,
    required this.nodePath,
    required this.threshold,
    required List<BitcoinPolicyNode> options,
  }) : options = List.unmodifiable(options);
}

final class BitcoinPolicySelection {
  final Map<String, List<int>> choices;

  const BitcoinPolicySelection.empty() : choices = const {};

  BitcoinPolicySelection({required Map<String, List<int>> choices})
    : choices = Map<String, List<int>>.unmodifiable(
        choices.map((key, value) {
          if (!_selectionKeyPattern.hasMatch(key)) {
            throw ArgumentError.value(key, 'choices');
          }
          if (value.any((index) => index < 0) ||
              value.toSet().length != value.length) {
            throw ArgumentError.value(value, key);
          }
          final sorted = [...value]..sort();
          return MapEntry(key, List<int>.unmodifiable(sorted));
        }),
      );

  List<int>? choiceFor({
    required BitcoinPolicyKeychain keychain,
    required String nodePath,
  }) => choices['${keychain.name}:$nodePath'];

  bool hasSameChoices(BitcoinPolicySelection other) {
    if (choices.length != other.choices.length) return false;
    for (final entry in choices.entries) {
      final otherChoice = other.choices[entry.key];
      if (otherChoice == null || otherChoice.length != entry.value.length) {
        return false;
      }
      for (var index = 0; index < entry.value.length; index++) {
        if (entry.value[index] != otherChoice[index]) return false;
      }
    }
    return true;
  }

  BitcoinPolicySelection withChoice({
    required BitcoinPolicyKeychain keychain,
    required String nodePath,
    required Iterable<int> selectedIndices,
  }) {
    final selected = selectedIndices.toSet().toList()..sort();
    if (selected.any((index) => index < 0)) {
      throw ArgumentError.value(selectedIndices, 'selectedIndices');
    }
    return BitcoinPolicySelection(
      choices: {...choices, '${keychain.name}:$nodePath': selected},
    );
  }
}

final _selectionKeyPattern = RegExp(r'^(external|internal):root(?:/[0-9]+)*$');

final class BitcoinPolicyPath {
  final Map<String, List<int>> external;
  final Map<String, List<int>> internal;
  final bool requiresRelativeTimelock;
  final Set<String>? eligibleExternalOutpoints;
  final Set<String>? eligibleInternalOutpoints;

  BitcoinPolicyPath({
    required Map<String, List<int>> external,
    required Map<String, List<int>> internal,
    required this.requiresRelativeTimelock,
    Set<String>? eligibleExternalOutpoints,
    Set<String>? eligibleInternalOutpoints,
  }) : external = Map<String, List<int>>.unmodifiable({
         for (final entry in external.entries)
           entry.key: List<int>.unmodifiable(entry.value),
       }),
       internal = Map<String, List<int>>.unmodifiable({
         for (final entry in internal.entries)
           entry.key: List<int>.unmodifiable(entry.value),
       }),
       eligibleExternalOutpoints = eligibleExternalOutpoints == null
           ? null
           : Set.unmodifiable(eligibleExternalOutpoints),
       eligibleInternalOutpoints = eligibleInternalOutpoints == null
           ? null
           : Set.unmodifiable(eligibleInternalOutpoints);
}
