import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:crypto/crypto.dart';

final class BullVaultDescriptorService {
  static final _branchPath = RegExp(r'^/<([0-9]+);([0-9]+)>/\*$');
  static final _activation = RegExp(r'after\(([0-9]+)\)');

  final BitcoinDescriptorPort _descriptorPort;
  final SeedVerificationPort _seedVerificationPort;

  const BullVaultDescriptorService(
    this._descriptorPort,
    this._seedVerificationPort,
  );

  Future<BullVaultPolicy?> recognize(String source, Network network) async {
    final policy = recognizeStructure(source, network);
    if (policy == null || await verifiedMobileAccount(policy) == null) {
      return null;
    }
    return policy;
  }

  BullVaultPolicy? recognizeStructure(String source, Network network) {
    final parsed = _descriptorPort.parseBitcoinDescriptor(
      descriptor: source.trim(),
      network: network,
    );
    final grouped = <String, List<WalletDescriptorKey>>{};
    for (final key in parsed.descriptorKeys) {
      grouped.putIfAbsent(_canonicalXpub(key.xpub), () => []).add(key);
    }
    if (grouped.length < 2 || grouped.length > 4) return null;
    final activations =
        _activation
            .allMatches(parsed.descriptor)
            .map((match) => int.parse(match.group(1)!))
            .toSet()
            .toList()
          ..sort();
    final shape = _shapeFor(grouped.length, activations);
    if (shape == null) return null;
    final matches = <BullVaultPolicy>[];
    for (final everydayGroup in grouped.values) {
      final others = grouped.values
          .where((keys) => !identical(keys, everydayGroup))
          .toList();
      for (final ordered in _permutations(others)) {
        try {
          final coldGroup = ordered[0];
          final secondColdGroup = shape.protection.usesTwoColdKeys
              ? ordered[1]
              : null;
          final inheritanceGroup = shape.includesInheritance
              ? ordered[shape.protection.usesTwoColdKeys ? 2 : 1]
              : null;
          final generation = _generationFor(
            protection: shape.protection,
            includesInheritance: shape.includesInheritance,
            everyday: everydayGroup,
            cold: coldGroup,
            secondCold: secondColdGroup,
            inheritance: inheritanceGroup,
          );
          if (generation == null) continue;
          final policy = BullVaultPolicy.restoreDescriptor(
            vaultGeneration: generation,
            network: network,
            descriptor: parsed.descriptor,
            protection: shape.protection,
            everydayKey: _signer(
              everydayGroup,
              BullVaultSignerRole.everyday,
              local: true,
            ),
            coldKey: _signer(coldGroup, BullVaultSignerRole.cold),
            secondColdKey: shape.protection.usesTwoColdKeys
                ? _signer(secondColdGroup!, BullVaultSignerRole.secondCold)
                : null,
            inheritanceKey: shape.includesInheritance
                ? _signer(inheritanceGroup!, BullVaultSignerRole.inheritance)
                : null,
            coldActivationTimestamp: shape.cold,
            recoveryActivationTimestamp: shape.recovery,
            inheritanceActivationTimestamp: shape.inheritance,
          );
          if (matchesPolicyDescriptor(policy)) matches.add(policy);
        } on ArgumentError {
          continue;
        }
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  bool matchesPolicyDescriptor(BullVaultPolicy policy) {
    try {
      final rebuilt = BullVaultPolicy.descriptorTemplateAtTimestamps(
        vaultGeneration: policy.vaultGeneration,
        network: policy.network,
        protection: policy.protection,
        everydayKey: policy.everydayKey,
        coldKey: policy.coldKey,
        secondColdKey: policy.secondColdKey,
        inheritanceKey: policy.inheritanceKey,
        coldActivationTimestamp: policy.coldActivationTimestamp,
        recoveryActivationTimestamp: policy.recoveryActivationTimestamp!,
        inheritanceActivationTimestamp: policy.inheritanceActivationTimestamp,
      );
      final expected = _descriptorPort
          .parseBitcoinDescriptor(descriptor: rebuilt, network: policy.network)
          .descriptor;
      final actual = _descriptorPort
          .parseBitcoinDescriptor(
            descriptor: policy.descriptor,
            network: policy.network,
          )
          .descriptor;
      if (expected != actual) return false;
      final expectedId = sha256
          .convert(
            utf8.encode(
              policy.birthHeight == null
                  ? actual
                  : '$actual|${policy.birthHeight}',
            ),
          )
          .toString();
      return expectedId == policy.id &&
          (policy.vaultGeneration != 0 || policy.lineageId == policy.id);
    } on Exception {
      return false;
    }
  }

  Future<int?> verifiedMobileAccount(BullVaultPolicy policy) async {
    final key = policy.everydayKey.accountKey;
    final path = key.derivationPath;
    if (path == null || key.masterFingerprint.isEmpty) return null;
    final account = Bip48Derivation.account(
      path,
      coinType: policy.network.coinType,
    );
    if (account == null) return null;
    return await _seedVerificationPort.matchesXpubs(
          fingerprint: key.masterFingerprint,
          keys: [(derivationPath: path, xpub: key.xpub)],
        )
        ? account
        : null;
  }

  List<WalletSigner>? signerAnnotations(
    List<WalletDescriptorKey> descriptorKeys,
    BullVaultPolicy policy,
  ) {
    final annotations = <WalletSigner>[];
    for (final signer in [
      policy.everydayKey,
      policy.coldKey,
      ?policy.secondColdKey,
      ?policy.inheritanceKey,
    ]) {
      final keys = [
        for (final key in descriptorKeys)
          if (_canonicalXpub(key.xpub) ==
              _canonicalXpub(signer.accountKey.xpub))
            key.copyWith(signerId: signer.role.name),
      ];
      if (keys.isEmpty) return null;
      annotations.add(
        WalletSigner(
          id: signer.role.name,
          signer: signer.role == BullVaultSignerRole.everyday
              ? SignerEntity.local
              : SignerEntity.remote,
          signerDevice: null,
          descriptorKeys: keys,
        ),
      );
    }
    return annotations;
  }

  bool matchesExistingWallet(Wallet wallet, BullVaultPolicy policy) {
    try {
      final existingDescriptor = _descriptorPort
          .parseBitcoinDescriptor(
            descriptor: wallet.publicDescriptor,
            network: wallet.network,
          )
          .descriptor;
      final expectedDescriptor = _descriptorPort
          .parseBitcoinDescriptor(
            descriptor: policy.descriptor,
            network: policy.network,
          )
          .descriptor;
      if (existingDescriptor != expectedDescriptor) return false;
      final policySigners = [
        policy.everydayKey,
        policy.coldKey,
        ?policy.secondColdKey,
        ?policy.inheritanceKey,
      ];
      if (wallet.signers.length != policySigners.length) return false;
      for (final policySigner in policySigners) {
        final expectedXpub = _canonicalXpub(policySigner.accountKey.xpub);
        final matching = wallet.signers.where(
          (signer) => signer.descriptorKeys.any(
            (key) => _canonicalXpub(key.xpub) == expectedXpub,
          ),
        );
        if (matching.length != 1) return false;
        final expectedOwnership =
            policySigner.role == BullVaultSignerRole.everyday
            ? SignerEntity.local
            : SignerEntity.remote;
        if (matching.single.signer != expectedOwnership) return false;
      }
      return true;
    } on Exception {
      return false;
    }
  }

  ({
    BullVaultProtection protection,
    bool includesInheritance,
    int? cold,
    int recovery,
    int? inheritance,
  })?
  _shapeFor(int signerCount, List<int> activations) =>
      switch ((signerCount, activations.length)) {
        (2, 2) => (
          protection: BullVaultProtection.standard,
          includesInheritance: false,
          cold: activations[0],
          recovery: activations[1],
          inheritance: null,
        ),
        (3, 3) => (
          protection: BullVaultProtection.standard,
          includesInheritance: true,
          cold: activations[1],
          recovery: activations[0],
          inheritance: activations[2],
        ),
        (3, 2) => (
          protection: BullVaultProtection.extra,
          includesInheritance: false,
          cold: activations[0],
          recovery: activations[1],
          inheritance: null,
        ),
        (4, 2) => (
          protection: BullVaultProtection.extra,
          includesInheritance: true,
          cold: null,
          recovery: activations[0],
          inheritance: activations[1],
        ),
        _ => null,
      };

  int? _generationFor({
    required BullVaultProtection protection,
    required bool includesInheritance,
    required List<WalletDescriptorKey> everyday,
    required List<WalletDescriptorKey> cold,
    required List<WalletDescriptorKey>? secondCold,
    required List<WalletDescriptorKey>? inheritance,
  }) {
    final coldOccurrences =
        protection == BullVaultProtection.standard && includesInheritance
        ? 3
        : 2;
    final generations = <int?>[
      _generationForSigner(everyday, occurrencesPerGeneration: 2),
      _generationForSigner(cold, occurrencesPerGeneration: coldOccurrences),
      if (secondCold != null)
        _generationForSigner(secondCold, occurrencesPerGeneration: 2),
      if (inheritance != null)
        _generationForSigner(inheritance, occurrencesPerGeneration: 2),
    ];
    if (generations.any((generation) => generation == null)) return null;
    final generation = generations.first!;
    return generations.every((candidate) => candidate == generation)
        ? generation
        : null;
  }

  int? _generationForSigner(
    List<WalletDescriptorKey> keys, {
    required int occurrencesPerGeneration,
  }) {
    if (keys.length != occurrencesPerGeneration) return null;
    final receiveBranches = <int>[];
    for (final key in keys) {
      final match = _branchPath.firstMatch(key.descriptorPath);
      if (match == null) return null;
      final receive = int.parse(match.group(1)!);
      final change = int.parse(match.group(2)!);
      if (change != receive + 1 || receive.isOdd) return null;
      receiveBranches.add(receive);
    }
    receiveBranches.sort();
    if (receiveBranches.toSet().length != occurrencesPerGeneration) {
      return null;
    }
    final firstPairIndex = receiveBranches.first ~/ 2;
    if (firstPairIndex % occurrencesPerGeneration != 0) return null;
    final generation = firstPairIndex ~/ occurrencesPerGeneration;
    for (
      var occurrence = 0;
      occurrence < occurrencesPerGeneration;
      occurrence++
    ) {
      final expected = BullVaultPolicy.branchPairForOccurrence(
        vaultGeneration: generation,
        occurrencesPerGeneration: occurrencesPerGeneration,
        occurrence: occurrence,
      );
      if (receiveBranches[occurrence] != expected.receive) return null;
    }
    return generation;
  }

  BullVaultSignerKey _signer(
    List<WalletDescriptorKey> keys,
    BullVaultSignerRole role, {
    bool local = false,
  }) {
    final key = keys.first;
    return BullVaultSignerKey(
      role: role,
      accountKey: WalletDescriptorKey(
        id: '${role.name}-account',
        signerId: role.name,
        masterFingerprint: key.masterFingerprint,
        xpubFingerprint: key.xpubFingerprint,
        xpub: key.xpub,
        derivationPath: key.derivationPath,
      ),
      signer: local ? SignerEntity.local : SignerEntity.remote,
      signerDevice: null,
    );
  }

  String _canonicalXpub(String value) =>
      Bip32Derivation.getBip32Xpub(value).toBase58();

  Iterable<List<T>> _permutations<T>(List<T> values) sync* {
    if (values.length < 2) {
      yield values;
      return;
    }
    for (var index = 0; index < values.length; index++) {
      final remaining = [...values]..removeAt(index);
      for (final suffix in _permutations(remaining)) {
        yield [values[index], ...suffix];
      }
    }
  }
}
