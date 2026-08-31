import 'dart:convert';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:crypto/crypto.dart';

typedef BullVaultBranchPair = ({int receive, int change});

final class BullVaultPolicy {
  static const schemaVersion = 1;
  static const _maxReceiveBranch = 0x7ffffffe;
  static const _locktimeTimestampThreshold = 500_000_000;

  // BIP341's unspendable H point represented as an extended public key. Its
  // chain code is arbitrary; only the public point determines spendability.
  static const _numsTpub =
      'tpubD6NzVbkrYhZ4WLd82sJzTQAcHXancR9nXqyNo8pXVNNEQ7qTDXiwX6dSW97sUvxdVBV2tAgod7gfG8dhJsVqDspXrsaLSifGx8suAPrpyUn';

  final String id;
  final String lineageId;
  final int vaultGeneration;
  final Network network;
  final String descriptor;
  final BullVaultProtection protection;
  final BullVaultSignerKey everydayKey;
  final BullVaultSignerKey coldKey;
  final BullVaultSignerKey? secondColdKey;
  final BullVaultSignerKey? inheritanceKey;
  final BullVaultSchedule? schedule;
  final int? birthHeight;
  final int? referenceTimestamp;
  final int? chainMedianTimePast;
  final int? coldActivationTimestamp;
  final int? recoveryActivationTimestamp;
  final int? inheritanceActivationTimestamp;
  final DateTime? createdAt;

  BullVaultPolicy({
    required this.id,
    required this.lineageId,
    required this.vaultGeneration,
    required this.network,
    required this.descriptor,
    required this.protection,
    required this.everydayKey,
    required this.coldKey,
    required this.secondColdKey,
    required this.inheritanceKey,
    required this.schedule,
    required this.birthHeight,
    required this.referenceTimestamp,
    required this.chainMedianTimePast,
    required this.coldActivationTimestamp,
    required this.recoveryActivationTimestamp,
    required this.inheritanceActivationTimestamp,
    required DateTime? createdAt,
  }) : createdAt = createdAt?.toUtc() {
    if (!network.isBitcoin) {
      throw ArgumentError.value(network, 'network', 'must be Bitcoin');
    }
    if (id.isEmpty ||
        lineageId.isEmpty ||
        !isValidGeneration(
          vaultGeneration,
          protection: protection,
          includesInheritance: inheritanceKey != null,
        )) {
      throw ArgumentError('BullVault requires valid lineage metadata');
    }
    if (!_hasValidScheduleMetadata()) {
      throw ArgumentError('BullVault requires a valid time-based schedule');
    }
    if (protection.usesTwoColdKeys != (secondColdKey != null)) {
      throw ArgumentError('BullVault protection does not match its signers');
    }
    if (reusesSignerKey([
      everydayKey,
      coldKey,
      ?secondColdKey,
      ?inheritanceKey,
    ])) {
      throw ArgumentError('BullVault signer keys must be independent');
    }
  }

  bool get hasKnownOriginalSchedule => schedule != null;

  BullVaultSchedule get renewalSchedule =>
      schedule ??
      BullVaultSchedule.defaultsFor(
        protection: protection,
        includesInheritance: inheritanceKey != null,
      );

  factory BullVaultPolicy.build({
    String? lineageId,
    required int vaultGeneration,
    required Network network,
    required String descriptor,
    required BullVaultProtection protection,
    required BullVaultSignerKey everydayKey,
    required BullVaultSignerKey coldKey,
    required BullVaultSignerKey? secondColdKey,
    required BullVaultSignerKey? inheritanceKey,
    required BullVaultSchedule schedule,
    required BullVaultTimeReference timeReference,
  }) {
    if (vaultGeneration > 0 && lineageId == null) {
      throw ArgumentError('Renewed BullVault policies require a lineage ID');
    }
    final id = sha256
        .convert(utf8.encode('$descriptor|${timeReference.chainHeight}'))
        .toString();
    return BullVaultPolicy(
      id: id,
      lineageId: lineageId ?? id,
      vaultGeneration: vaultGeneration,
      network: network,
      descriptor: descriptor,
      protection: protection,
      everydayKey: everydayKey,
      coldKey: coldKey,
      secondColdKey: secondColdKey,
      inheritanceKey: inheritanceKey,
      schedule: schedule,
      birthHeight: timeReference.chainHeight,
      referenceTimestamp: timeReference.deviceTimestamp,
      chainMedianTimePast: timeReference.medianTimePast,
      coldActivationTimestamp:
          protection == BullVaultProtection.standard || inheritanceKey == null
          ? schedule.coldActivationTimestamp(timeReference.deviceTime)
          : null,
      recoveryActivationTimestamp: schedule.recoveryActivationTimestamp(
        timeReference.deviceTime,
      ),
      inheritanceActivationTimestamp: inheritanceKey == null
          ? null
          : schedule.inheritanceActivationTimestamp(timeReference.deviceTime),
      createdAt: timeReference.deviceTime,
    );
  }

  factory BullVaultPolicy.restoreDescriptor({
    required int vaultGeneration,
    required Network network,
    required String descriptor,
    required BullVaultProtection protection,
    required BullVaultSignerKey everydayKey,
    required BullVaultSignerKey coldKey,
    required BullVaultSignerKey? secondColdKey,
    required BullVaultSignerKey? inheritanceKey,
    required int? coldActivationTimestamp,
    required int recoveryActivationTimestamp,
    required int? inheritanceActivationTimestamp,
  }) {
    final id = sha256.convert(utf8.encode(descriptor)).toString();
    return BullVaultPolicy(
      id: id,
      lineageId: id,
      vaultGeneration: vaultGeneration,
      network: network,
      descriptor: descriptor,
      protection: protection,
      everydayKey: everydayKey,
      coldKey: coldKey,
      secondColdKey: secondColdKey,
      inheritanceKey: inheritanceKey,
      schedule: null,
      birthHeight: null,
      referenceTimestamp: null,
      chainMedianTimePast: null,
      coldActivationTimestamp: coldActivationTimestamp,
      recoveryActivationTimestamp: recoveryActivationTimestamp,
      inheritanceActivationTimestamp: inheritanceActivationTimestamp,
      createdAt: null,
    );
  }

  factory BullVaultPolicy.restoreRecoveryPackage({
    required BullVaultPolicy recognizedPolicy,
    required String lineageId,
    required BullVaultSchedule? schedule,
    required int? birthHeight,
    required DateTime? createdAt,
  }) {
    final descriptor = recognizedPolicy.descriptor;
    final id = sha256
        .convert(
          utf8.encode(
            birthHeight == null ? descriptor : '$descriptor|$birthHeight',
          ),
        )
        .toString();
    return BullVaultPolicy(
      id: id,
      lineageId: lineageId,
      vaultGeneration: recognizedPolicy.vaultGeneration,
      network: recognizedPolicy.network,
      descriptor: descriptor,
      protection: recognizedPolicy.protection,
      everydayKey: recognizedPolicy.everydayKey,
      coldKey: recognizedPolicy.coldKey,
      secondColdKey: recognizedPolicy.secondColdKey,
      inheritanceKey: recognizedPolicy.inheritanceKey,
      schedule: schedule,
      birthHeight: birthHeight,
      referenceTimestamp: null,
      chainMedianTimePast: null,
      coldActivationTimestamp: recognizedPolicy.coldActivationTimestamp,
      recoveryActivationTimestamp: recognizedPolicy.recoveryActivationTimestamp,
      inheritanceActivationTimestamp:
          recognizedPolicy.inheritanceActivationTimestamp,
      createdAt: createdAt,
    );
  }

  static String descriptorTemplate({
    required int vaultGeneration,
    required Network network,
    required BullVaultProtection protection,
    required BullVaultSignerKey everydayKey,
    required BullVaultSignerKey coldKey,
    required BullVaultSignerKey? secondColdKey,
    required BullVaultSignerKey? inheritanceKey,
    required BullVaultSchedule schedule,
    required DateTime referenceTime,
  }) {
    final referenceTimestamp =
        referenceTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (referenceTimestamp < _locktimeTimestampThreshold ||
        !schedule.isValid(
          protection: protection,
          includesInheritance: inheritanceKey != null,
        ) ||
        protection.usesTwoColdKeys != (secondColdKey != null)) {
      throw ArgumentError('BullVault requires a valid time-based schedule');
    }
    return descriptorTemplateAtTimestamps(
      vaultGeneration: vaultGeneration,
      network: network,
      protection: protection,
      everydayKey: everydayKey,
      coldKey: coldKey,
      secondColdKey: secondColdKey,
      inheritanceKey: inheritanceKey,
      coldActivationTimestamp:
          protection == BullVaultProtection.standard || inheritanceKey == null
          ? schedule.coldActivationTimestamp(referenceTime)
          : null,
      recoveryActivationTimestamp: schedule.recoveryActivationTimestamp(
        referenceTime,
      ),
      inheritanceActivationTimestamp: inheritanceKey == null
          ? null
          : schedule.inheritanceActivationTimestamp(referenceTime),
    );
  }

  static String descriptorTemplateAtTimestamps({
    required int vaultGeneration,
    required Network network,
    required BullVaultProtection protection,
    required BullVaultSignerKey everydayKey,
    required BullVaultSignerKey coldKey,
    required BullVaultSignerKey? secondColdKey,
    required BullVaultSignerKey? inheritanceKey,
    required int? coldActivationTimestamp,
    required int recoveryActivationTimestamp,
    required int? inheritanceActivationTimestamp,
  }) {
    _validateActivationTimestamps(
      protection: protection,
      includesInheritance: inheritanceKey != null,
      cold: coldActivationTimestamp,
      recovery: recoveryActivationTimestamp,
      inheritance: inheritanceActivationTimestamp,
    );
    if (protection.usesTwoColdKeys != (secondColdKey != null)) {
      throw ArgumentError('BullVault protection does not match its signers');
    }
    final nums = branchPairForOccurrence(
      vaultGeneration: vaultGeneration,
      occurrencesPerGeneration: 1,
      occurrence: 0,
    );
    final everydayPairs = _branchPairsForGeneration(
      vaultGeneration,
      occurrencesPerGeneration: 2,
    );
    final coldPairs = _branchPairsForGeneration(
      vaultGeneration,
      occurrencesPerGeneration:
          protection == BullVaultProtection.standard && inheritanceKey != null
          ? 3
          : 2,
    );
    final everydayPrimary = everydayKey.expression(
      receiveBranch: everydayPairs[0].receive,
      changeBranch: everydayPairs[0].change,
    );
    final everydayRecovery = everydayKey.expression(
      receiveBranch: everydayPairs[1].receive,
      changeBranch: everydayPairs[1].change,
    );
    final coldPrimary = coldKey.expression(
      receiveBranch: coldPairs[0].receive,
      changeBranch: coldPairs[0].change,
    );
    final coldRecovery = coldKey.expression(
      receiveBranch: coldPairs[1].receive,
      changeBranch: coldPairs[1].change,
    );
    final primaryKeys = <String>[everydayPrimary, coldPrimary];

    if (protection == BullVaultProtection.extra) {
      final secondColdPairs = _branchPairsForGeneration(
        vaultGeneration,
        occurrencesPerGeneration: 2,
      );
      final secondColdPrimary = secondColdKey!.expression(
        receiveBranch: secondColdPairs[0].receive,
        changeBranch: secondColdPairs[0].change,
      );
      final secondColdRecovery = secondColdKey.expression(
        receiveBranch: secondColdPairs[1].receive,
        changeBranch: secondColdPairs[1].change,
      );
      final primary =
          'multi_a(2,${[...primaryKeys, secondColdPrimary].join(',')})';
      if (inheritanceKey == null) {
        final cold =
            'and_v(v:after($coldActivationTimestamp),multi_a(1,$coldRecovery,$secondColdRecovery))';
        final mobile =
            'and_v(v:after($recoveryActivationTimestamp),pk($everydayRecovery))';
        return 'tr(${_numsKey(network, nums.receive, nums.change)},{$primary,{$cold,$mobile}})';
      }
      final inheritancePairs = _branchPairsForGeneration(
        vaultGeneration,
        occurrencesPerGeneration: 2,
      );
      final inheritanceRecovery = inheritanceKey.expression(
        receiveBranch: inheritancePairs[0].receive,
        changeBranch: inheritancePairs[0].change,
      );
      final inheritanceSolo = inheritanceKey.expression(
        receiveBranch: inheritancePairs[1].receive,
        changeBranch: inheritancePairs[1].change,
      );
      final recovery =
          'and_v(v:after($recoveryActivationTimestamp),multi_a(2,$everydayRecovery,$coldRecovery,$secondColdRecovery,$inheritanceRecovery))';
      final inheritance =
          'and_v(v:after($inheritanceActivationTimestamp),pk($inheritanceSolo))';
      return 'tr(${_numsKey(network, nums.receive, nums.change)},{$primary,{$recovery,$inheritance}})';
    }

    final primary = 'multi_a(2,${primaryKeys.join(',')})';

    if (inheritanceKey == null) {
      final cold = 'and_v(v:after($coldActivationTimestamp),pk($coldRecovery))';
      final mobile =
          'and_v(v:after($recoveryActivationTimestamp),pk($everydayRecovery))';
      return 'tr(${_numsKey(network, nums.receive, nums.change)},{$primary,{$cold,$mobile}})';
    }

    final inheritancePairs = _branchPairsForGeneration(
      vaultGeneration,
      occurrencesPerGeneration: 2,
    );
    final inheritanceRecovery = inheritanceKey.expression(
      receiveBranch: inheritancePairs[0].receive,
      changeBranch: inheritancePairs[0].change,
    );
    final inheritanceSolo = inheritanceKey.expression(
      receiveBranch: inheritancePairs[1].receive,
      changeBranch: inheritancePairs[1].change,
    );
    final coldSolo = coldKey.expression(
      receiveBranch: coldPairs[2].receive,
      changeBranch: coldPairs[2].change,
    );
    final recovery =
        'and_v(v:after($recoveryActivationTimestamp),multi_a(2,$everydayRecovery,$coldRecovery,$inheritanceRecovery))';
    final cold = 'and_v(v:after($coldActivationTimestamp),pk($coldSolo))';
    final inheritance =
        'and_v(v:after($inheritanceActivationTimestamp),pk($inheritanceSolo))';
    return 'tr(${_numsKey(network, nums.receive, nums.change)},{$primary,{$recovery,{$cold,$inheritance}}})';
  }

  static List<BullVaultBranchPair> _branchPairsForGeneration(
    int vaultGeneration, {
    required int occurrencesPerGeneration,
  }) => [
    for (
      var occurrence = 0;
      occurrence < occurrencesPerGeneration;
      occurrence++
    )
      branchPairForOccurrence(
        vaultGeneration: vaultGeneration,
        occurrencesPerGeneration: occurrencesPerGeneration,
        occurrence: occurrence,
      ),
  ];

  static BullVaultBranchPair branchPairForOccurrence({
    required int vaultGeneration,
    required int occurrencesPerGeneration,
    required int occurrence,
  }) {
    if (vaultGeneration < 0 ||
        occurrencesPerGeneration <= 0 ||
        occurrence < 0 ||
        occurrence >= occurrencesPerGeneration) {
      throw ArgumentError('Invalid BullVault signer occurrence');
    }
    final pairIndex = (vaultGeneration * occurrencesPerGeneration) + occurrence;
    final receive = pairIndex * 2;
    if (receive > _maxReceiveBranch) {
      throw ArgumentError.value(
        vaultGeneration,
        'vaultGeneration',
        'is outside the BullVault derivation range',
      );
    }
    return (receive: receive, change: receive + 1);
  }

  static bool isValidGeneration(
    int vaultGeneration, {
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) {
    if (vaultGeneration < 0) return false;
    final occurrences =
        protection == BullVaultProtection.standard && includesInheritance
        ? 3
        : 2;
    final lastPairIndex = ((vaultGeneration + 1) * occurrences) - 1;
    return lastPairIndex <= _maxReceiveBranch ~/ 2;
  }

  static String _numsKey(Network network, int receiveBranch, int changeBranch) {
    if (!network.isBitcoin) {
      throw ArgumentError.value(network, 'network', 'must be Bitcoin');
    }
    final xpub = network.isTestnet
        ? _numsTpub
        : Bip32Derivation.getBip32Xpub(_numsTpub).toBase58();
    return '[00000000]$xpub/<$receiveBranch;$changeBranch>/*';
  }

  static bool reusesSignerKey(Iterable<BullVaultSignerKey> signers) {
    final xpubs = <String>{};
    final fingerprints = <String>{};
    for (final signer in signers) {
      final canonicalXpub = Bip32Derivation.getBip32Xpub(
        signer.accountKey.xpub,
      ).toBase58();
      if (!xpubs.add(canonicalXpub)) return true;
      final fingerprint = signer.accountKey.masterFingerprint.toLowerCase();
      if (fingerprint.isNotEmpty && !fingerprints.add(fingerprint)) return true;
    }
    return false;
  }

  bool hasSameSignerConfigurationAs(BullVaultPolicy other) =>
      network == other.network &&
      protection == other.protection &&
      _sameAccountKey(everydayKey, other.everydayKey) &&
      _sameAccountKey(coldKey, other.coldKey) &&
      _sameOptionalAccountKey(secondColdKey, other.secondColdKey) &&
      _sameOptionalAccountKey(inheritanceKey, other.inheritanceKey);

  static bool _sameOptionalAccountKey(
    BullVaultSignerKey? first,
    BullVaultSignerKey? second,
  ) => switch ((first, second)) {
    (null, null) => true,
    (final BullVaultSignerKey first, final BullVaultSignerKey second) =>
      _sameAccountKey(first, second),
    _ => false,
  };

  static bool _sameAccountKey(
    BullVaultSignerKey first,
    BullVaultSignerKey second,
  ) =>
      Bip32Derivation.getBip32Xpub(first.accountKey.xpub).toBase58() ==
      Bip32Derivation.getBip32Xpub(second.accountKey.xpub).toBase58();

  bool _hasValidScheduleMetadata() {
    final schedule = this.schedule;
    final createdAt = this.createdAt;
    final birthHeight = this.birthHeight;
    final referenceTimestamp = this.referenceTimestamp;
    final chainMedianTimePast = this.chainMedianTimePast;
    if ((birthHeight != null && birthHeight <= 0) ||
        !_hasValidActivationTimestamps()) {
      return false;
    }
    if (schedule == null) {
      return referenceTimestamp == null &&
          chainMedianTimePast == null &&
          (createdAt == null || createdAt.isUtc);
    }
    if (createdAt == null ||
        !schedule.isValid(
          protection: protection,
          includesInheritance: inheritanceKey != null,
        )) {
      return false;
    }
    final hasTimeReference =
        referenceTimestamp != null || chainMedianTimePast != null;
    if (hasTimeReference &&
        (birthHeight == null ||
            referenceTimestamp == null ||
            chainMedianTimePast == null ||
            referenceTimestamp < _locktimeTimestampThreshold ||
            chainMedianTimePast < _locktimeTimestampThreshold ||
            referenceTimestamp != createdAt.millisecondsSinceEpoch ~/ 1000 ||
            (referenceTimestamp - chainMedianTimePast).abs() >
                BullVaultTimeReference.maxChainTimeDifference.inSeconds)) {
      return false;
    }
    final expectedCold =
        protection == BullVaultProtection.standard || inheritanceKey == null
        ? schedule.coldActivationTimestamp(createdAt)
        : null;
    return coldActivationTimestamp == expectedCold &&
        recoveryActivationTimestamp ==
            schedule.recoveryActivationTimestamp(createdAt) &&
        inheritanceActivationTimestamp ==
            (inheritanceKey == null
                ? null
                : schedule.inheritanceActivationTimestamp(createdAt));
  }

  bool _hasValidActivationTimestamps() {
    try {
      _validateActivationTimestamps(
        protection: protection,
        includesInheritance: inheritanceKey != null,
        cold: coldActivationTimestamp,
        recovery: recoveryActivationTimestamp,
        inheritance: inheritanceActivationTimestamp,
      );
      return true;
    } on ArgumentError {
      return false;
    }
  }

  static void _validateActivationTimestamps({
    required BullVaultProtection protection,
    required bool includesInheritance,
    required int? cold,
    required int? recovery,
    required int? inheritance,
  }) {
    if (recovery == null ||
        recovery < _locktimeTimestampThreshold ||
        (cold != null && cold < _locktimeTimestampThreshold) ||
        (inheritance != null && inheritance < _locktimeTimestampThreshold)) {
      throw ArgumentError('BullVault requires valid activation timestamps');
    }
    final valid = switch ((protection, includesInheritance)) {
      (BullVaultProtection.standard, false) =>
        cold != null && inheritance == null && cold < recovery,
      (BullVaultProtection.standard, true) =>
        cold != null &&
            inheritance != null &&
            recovery < cold &&
            cold < inheritance,
      (BullVaultProtection.extra, false) =>
        cold != null && inheritance == null && cold < recovery,
      (BullVaultProtection.extra, true) =>
        cold == null && inheritance != null && recovery < inheritance,
    };
    if (!valid) {
      throw ArgumentError('BullVault requires ordered activation timestamps');
    }
  }
}
