import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_maturity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_node.dart';

final class BitcoinPsbtInputReview {
  final String outpoint;
  final BigInt amountSat;
  final BitcoinPolicyKeychain? keychain;
  final Set<String> localDescriptorKeyIds;
  final int sequence;
  final Set<String> signedDescriptorKeyIds;

  BitcoinPsbtInputReview({
    required this.outpoint,
    required this.amountSat,
    required this.keychain,
    Set<String> localDescriptorKeyIds = const {},
    required this.sequence,
    Set<String> signedDescriptorKeyIds = const {},
  }) : localDescriptorKeyIds = Set.unmodifiable(localDescriptorKeyIds),
       signedDescriptorKeyIds = Set.unmodifiable(signedDescriptorKeyIds) {
    if (outpoint.isEmpty) throw ArgumentError.value(outpoint, 'outpoint');
    if (amountSat < BigInt.zero) {
      throw ArgumentError.value(amountSat, 'amountSat');
    }
    if (sequence < 0 || sequence > 0xffffffff) {
      throw ArgumentError.value(sequence, 'sequence');
    }
  }

  bool get hasLocalSignerOrigin => localDescriptorKeyIds.isNotEmpty;
}

final class BitcoinPsbtOutputReview {
  final int index;
  final BigInt amountSat;
  final String? address;
  final String scriptHex;
  final bool isWalletOwned;

  BitcoinPsbtOutputReview({
    required this.index,
    required this.amountSat,
    required this.address,
    required this.scriptHex,
    required this.isWalletOwned,
  }) {
    if (index < 0) throw ArgumentError.value(index, 'index');
    if (amountSat < BigInt.zero) {
      throw ArgumentError.value(amountSat, 'amountSat');
    }
    if (scriptHex.isEmpty) throw ArgumentError.value(scriptHex, 'scriptHex');
  }
}

final class BitcoinPsbtReview {
  final String transactionId;
  final List<BitcoinPsbtInputReview> inputs;
  final List<BitcoinPsbtOutputReview> outputs;
  final BigInt feeSat;
  final int estimatedTransactionVsize;
  final int lockTime;
  final int version;

  BitcoinPsbtReview({
    required this.transactionId,
    required List<BitcoinPsbtInputReview> inputs,
    required List<BitcoinPsbtOutputReview> outputs,
    required this.feeSat,
    required this.estimatedTransactionVsize,
    required this.lockTime,
    required this.version,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs) {
    if (transactionId.isEmpty) {
      throw ArgumentError.value(transactionId, 'transactionId');
    }
    if (inputs.isEmpty) throw ArgumentError.value(inputs, 'inputs');
    if (outputs.isEmpty) throw ArgumentError.value(outputs, 'outputs');
    if (feeSat < BigInt.zero) throw ArgumentError.value(feeSat, 'feeSat');
    if (estimatedTransactionVsize <= 0) {
      throw ArgumentError.value(
        estimatedTransactionVsize,
        'estimatedTransactionVsize',
      );
    }
    if (lockTime < 0 || lockTime > 0xffffffff) {
      throw ArgumentError.value(lockTime, 'lockTime');
    }
  }

  List<BitcoinPsbtOutputReview> get recipients =>
      outputs.where((output) => !output.isWalletOwned).toList(growable: false);

  List<BitcoinPsbtOutputReview> get walletOwnedOutputs =>
      outputs.where((output) => output.isWalletOwned).toList(growable: false);

  BigInt get recipientAmountSat =>
      recipients.fold(BigInt.zero, (total, output) => total + output.amountSat);

  double get estimatedFeeRateSatPerVbyte =>
      feeSat.toDouble() / estimatedTransactionVsize;

  Set<String> get outpoints =>
      Set.unmodifiable(inputs.map((input) => input.outpoint));

  Set<String> get signedDescriptorKeyIds {
    if (inputs.isEmpty) return const {};
    return Set.unmodifiable(
      inputs
          .map((input) => input.signedDescriptorKeyIds)
          .reduce((signed, next) => signed.intersection(next)),
    );
  }

  Map<BitcoinPolicyKeychain, Set<String>>
  get signedDescriptorKeyIdsByKeychain => Map.unmodifiable({
    for (final keychain in BitcoinPolicyKeychain.values)
      if (inputs.any((input) => input.keychain == keychain))
        keychain: Set.unmodifiable(
          inputs
              .where((input) => input.keychain == keychain)
              .map((input) => input.signedDescriptorKeyIds)
              .reduce((signed, next) => signed.intersection(next)),
        ),
  });

  Map<String, Set<String>> get signedDescriptorKeyIdsByOutpoint =>
      Map.unmodifiable({
        for (final input in inputs)
          input.outpoint: Set.unmodifiable(input.signedDescriptorKeyIds),
      });

  bool get hasTimingConstraint =>
      _hasAbsoluteTimingConstraint ||
      (version >= 2 &&
          inputs.any((input) => _relativeValue(input.sequence) > 0));

  bool get hasTimeBasedTimingConstraint =>
      (_hasAbsoluteTimingConstraint && lockTime >= 500000000) ||
      (version >= 2 &&
          inputs.any(
            (input) =>
                _relativeValue(input.sequence) > 0 &&
                input.sequence & _sequenceTypeFlag != 0,
          ));

  bool timingIsSatisfied(BitcoinPolicyMaturity maturity) {
    if (!hasTimingConstraint) return true;
    if (!maturity.isKnown) return false;

    if (_hasAbsoluteTimingConstraint) {
      final absoluteSatisfied = lockTime < 500000000
          ? maturity.tipHeight >= lockTime
          : maturity.medianTimePast != null &&
                maturity.medianTimePast! > lockTime;
      if (!absoluteSatisfied) return false;
    }

    if (version < 2) return true;
    final maturityByOutpoint = {
      for (final utxo in maturity.utxos) utxo.outpoint: utxo,
    };
    for (final input in inputs) {
      final value = _relativeValue(input.sequence);
      if (value == 0) continue;
      final utxo = maturityByOutpoint[input.outpoint];
      if (utxo == null) return false;
      if (input.sequence & _sequenceTypeFlag == 0) {
        if (utxo.confirmations < value) return false;
      } else {
        final confirmationTime = utxo.confirmationMedianTimePast;
        final currentTime = maturity.medianTimePast;
        if (confirmationTime == null ||
            currentTime == null ||
            currentTime < confirmationTime + value * 512) {
          return false;
        }
      }
    }
    return true;
  }

  BitcoinPolicyActivation? blockingTimingActivation(
    BitcoinPolicyMaturity maturity,
  ) {
    if (!hasTimingConstraint || !maturity.isKnown) return null;

    final activations = <BitcoinPolicyActivation>[];
    if (_hasAbsoluteTimingConstraint) {
      if (lockTime < 500000000 && maturity.tipHeight < lockTime) {
        activations.add(
          BitcoinPolicyActivation(
            type: BitcoinPolicyActivationType.absoluteBlock,
            value: lockTime,
            estimatedSecondsFromNow: (lockTime - maturity.tipHeight) * 600,
          ),
        );
      } else if (lockTime >= 500000000) {
        final medianTimePast = maturity.medianTimePast;
        if (medianTimePast == null) return null;
        if (medianTimePast <= lockTime) {
          activations.add(
            BitcoinPolicyActivation(
              type: BitcoinPolicyActivationType.absoluteTime,
              value: lockTime,
              estimatedSecondsFromNow: lockTime - medianTimePast + 1,
            ),
          );
        }
      }
    }

    if (version >= 2) {
      final maturityByOutpoint = {
        for (final utxo in maturity.utxos) utxo.outpoint: utxo,
      };
      for (final input in inputs) {
        final value = _relativeValue(input.sequence);
        if (value == 0) continue;
        final utxo = maturityByOutpoint[input.outpoint];
        if (utxo == null) return null;
        if (input.sequence & _sequenceTypeFlag == 0) {
          final remainingBlocks = value - utxo.confirmations;
          if (remainingBlocks > 0) {
            activations.add(
              BitcoinPolicyActivation(
                type: BitcoinPolicyActivationType.relativeBlocks,
                value: remainingBlocks,
                estimatedSecondsFromNow: remainingBlocks * 600,
              ),
            );
          }
        } else {
          final confirmationTime = utxo.confirmationMedianTimePast;
          final medianTimePast = maturity.medianTimePast;
          if (confirmationTime == null || medianTimePast == null) return null;
          final target = confirmationTime + value * 512;
          if (medianTimePast < target) {
            activations.add(
              BitcoinPolicyActivation(
                type: BitcoinPolicyActivationType.relativeTime,
                value: target,
                estimatedSecondsFromNow: target - medianTimePast,
              ),
            );
          }
        }
      }
    }

    if (activations.isEmpty) return null;
    return activations.reduce(
      (latest, activation) =>
          activation.estimatedSecondsFromNow > latest.estimatedSecondsFromNow
          ? activation
          : latest,
    );
  }

  bool get _hasAbsoluteTimingConstraint =>
      lockTime > 0 && inputs.any((input) => input.sequence != 0xffffffff);
}

const _sequenceDisableFlag = 1 << 31;
const _sequenceTypeFlag = 1 << 22;
const _sequenceValueMask = 0xffff;

int _relativeValue(int sequence) =>
    sequence & _sequenceDisableFlag != 0 ? 0 : sequence & _sequenceValueMask;
