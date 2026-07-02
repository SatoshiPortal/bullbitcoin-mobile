import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

enum OctojoinIssue {
  amountBelowDust,
  notEnoughAddresses,
  numInputsTooLow,
  numOutputsTooLow,
  outputsMismatch,
  notEnoughSwappedCoins,
  noSenderCoin,
  insufficientFunds,
  sendMaxUnsupported,
  bitcoinOnly,
}

class OctojoinException extends BullException {
  final OctojoinIssue issue;
  final int? needed;
  final int? found;

  OctojoinException(this.issue, {this.needed, this.found})
    : super('Octojoin: ${issue.name}');
}

class OctojoinSelection {
  final List<WalletUtxo> swapped;
  final WalletUtxo sender;
  final int totalSat;

  OctojoinSelection({
    required this.swapped,
    required this.sender,
    required this.totalSat,
  });

  List<WalletUtxo> get all => [...swapped, sender];
}

class OctojoinPlan {
  final List<WalletUtxo> inputs;
  final List<({String address, int amountSat})> targets;
  final int totalInputSat;

  OctojoinPlan({
    required this.inputs,
    required this.targets,
    required this.totalInputSat,
  });
}

abstract final class Octojoin {
  static const List<int> standardDenominations = [
    100000000,
    50000000,
    20000000,
    10000000,
    5000000,
    2000000,
    1000000,
    500000,
    200000,
    100000,
  ];

  static const int dustThresholdSat = 546;
  static const int minInputs = 3;
  static const int minOutputs = 2;
  static const String labelTag = 'octojoin';

  static bool isOctojoinLabel(String? label) =>
      label != null && label.toLowerCase().contains(labelTag);

  static bool isSwappedUtxo(WalletUtxo utxo) =>
      utxo.labels.any((l) => isOctojoinLabel(l.label));

  static int inputVbytesForScriptType(ScriptType scriptType) {
    return switch (scriptType) {
      ScriptType.bip84 => 68,
      ScriptType.bip49 => 91,
      ScriptType.bip44 => 148,
    };
  }

  static List<int> decomposeAmount(int amountSat) {
    final denominations = <int>[];
    var remaining = amountSat;

    for (final denom in standardDenominations) {
      while (remaining >= denom) {
        denominations.add(denom);
        remaining -= denom;
      }
    }

    if (remaining > dustThresholdSat) {
      denominations.add(remaining);
    } else if (remaining > 0 && denominations.isNotEmpty) {
      denominations[denominations.length - 1] += remaining;
    }

    return denominations;
  }

  static Map<String, int> distributeOutputs(
    List<int> denominations,
    List<String> addresses,
  ) {
    final outputs = <String, int>{for (final addr in addresses) addr: 0};

    for (var i = 0; i < denominations.length; i++) {
      final addr = addresses[i % addresses.length];
      outputs[addr] = outputs[addr]! + denominations[i];
    }

    return outputs;
  }

  static int estimateFee({
    required int numInputs,
    required int numOutputs,
    required double satPerVbyte,
    int inputVbytes = 68,
  }) {
    const txOverheadVbytes = 11;
    const outputVbytes = 34;
    return ((txOverheadVbytes +
                numInputs * inputVbytes +
                numOutputs * outputVbytes) *
            satPerVbyte)
        .ceil();
  }

  static List<List<T>> _chooseCombinations<T>(List<T> items, int k) {
    if (k == 0) return [[]];
    if (k > items.length) return [];
    final result = <List<T>>[];
    for (var i = 0; i <= items.length - k; i++) {
      for (final rest in _chooseCombinations(items.sublist(i + 1), k - 1)) {
        result.add([items[i], ...rest]);
      }
    }
    return result;
  }

  static OctojoinSelection selectUtxos({
    required List<WalletUtxo> utxos,
    required int numInputs,
    required int targetSat,
  }) {
    final swappedUtxos = utxos.where(isSwappedUtxo).toList();
    final otherUtxos = utxos.where((u) => !isSwappedUtxo(u)).toList();

    final requiredSwapped = numInputs - 1;

    if (swappedUtxos.length < requiredSwapped) {
      throw OctojoinException(
        OctojoinIssue.notEnoughSwappedCoins,
        needed: requiredSwapped,
        found: swappedUtxos.length,
      );
    }
    if (otherUtxos.isEmpty) {
      throw OctojoinException(OctojoinIssue.noSenderCoin);
    }

    final swappedPool = (swappedUtxos.toList()
          ..sort((a, b) => a.amountSat.compareTo(b.amountSat)))
        .take(requiredSwapped + 6)
        .toList();
    final senders = (otherUtxos.toList()
          ..sort((a, b) => a.amountSat.compareTo(b.amountSat)))
        .take(10)
        .toList();

    ({List<WalletUtxo> swapped, WalletUtxo sender, int total, int change, bool clean})?
    best;
    for (final combo in _chooseCombinations(swappedPool, requiredSwapped)) {
      final swappedValue = combo.fold(0, (sum, u) => sum + u.amountSat.toInt());
      for (final sender in senders) {
        final total = swappedValue + sender.amountSat.toInt();
        if (total < targetSat) continue;
        final change = total - targetSat;
        final minInput = [
          sender.amountSat.toInt(),
          ...combo.map((u) => u.amountSat.toInt()),
        ].reduce((a, b) => a < b ? a : b);
        final clean = change < minInput;
        if (best == null ||
            (clean && !best.clean) ||
            (clean == best.clean && change < best.change)) {
          best = (
            swapped: combo,
            sender: sender,
            total: total,
            change: change,
            clean: clean,
          );
        }
      }
    }

    if (best == null) {
      throw OctojoinException(OctojoinIssue.insufficientFunds);
    }

    return OctojoinSelection(
      swapped: best.swapped,
      sender: best.sender,
      totalSat: best.total,
    );
  }

  static OctojoinPlan plan({
    required List<WalletUtxo> utxos,
    required int paymentSat,
    required List<String> addresses,
    required int numInputs,
    required int Function(int numInputs, int numOutputs) feeForShape,
  }) {
    if (addresses.length < minOutputs) {
      throw OctojoinException(
        OctojoinIssue.notEnoughAddresses,
        needed: minOutputs,
        found: addresses.length,
      );
    }

    final denominations = decomposeAmount(paymentSat);
    if (denominations.isEmpty) {
      throw OctojoinException(OctojoinIssue.amountBelowDust);
    }

    final targets = distributeOutputs(denominations, addresses)
        .entries
        .where((e) => e.value > 0)
        .map((e) => (address: e.key, amountSat: e.value))
        .toList();

    final roughFee = feeForShape(numInputs, targets.length + 1);
    final selection = selectUtxos(
      utxos: utxos,
      numInputs: numInputs,
      targetSat: paymentSat + roughFee,
    );

    final minFee = feeForShape(selection.all.length, targets.length + 1);
    if (selection.totalSat < paymentSat + minFee) {
      throw OctojoinException(OctojoinIssue.insufficientFunds);
    }

    return OctojoinPlan(
      inputs: selection.all,
      targets: targets,
      totalInputSat: selection.totalSat,
    );
  }
}
