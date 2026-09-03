import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:crypto/crypto.dart';

final class BullVaultDescriptorService {
  static final _branchPath = RegExp(r'^/<([0-9]+);([0-9]+)>/\*$');
  static final _activation = RegExp(r'after\(([0-9]+)\)');

  final BitcoinDescriptorPort _descriptorPort;
  const BullVaultDescriptorService(this._descriptorPort);

  BullVaultPolicy? withVerifiedMobileSeed(
    BullVaultPolicy policy,
    Seed seed, {
    String? passphrase,
  }) {
    final canonicalSeedBytes = _canonicalSeedBytes(seed);
    final everydayMatchesCanonical = _matchesSeedIdentity(
      policy.everydayKey,
      canonicalSeedBytes,
    );
    final suppliedPassphrase = passphrase;
    final everydayMatchesPassphrase =
        !everydayMatchesCanonical &&
        suppliedPassphrase != null &&
        suppliedPassphrase.isNotEmpty &&
        seed is MnemonicSeed &&
        _matchesSeedIdentity(
          policy.everydayKey,
          Uint8List.fromList(
            bip39.Mnemonic.fromWords(
              words: seed.mnemonicWords,
              passphrase: suppliedPassphrase,
            ).seed,
          ),
        );
    final recoveryKey = policy.delayedMobileRecoveryKey;
    final recoveryMatches = switch (recoveryKey) {
      final BullVaultSignerKey recovery => _matchesSeedIdentity(
        recovery,
        canonicalSeedBytes,
      ),
      null => false,
    };
    if (recoveryKey != null && !recoveryMatches) {
      return null;
    }
    if (recoveryKey == null &&
        !everydayMatchesCanonical &&
        !everydayMatchesPassphrase) {
      return null;
    }
    return policy.withEverydayOwnership(
      SignerEntity.local,
      requiresPassphrase: recoveryKey != null || !everydayMatchesCanonical,
    );
  }

  bool matchesEverydaySeed(
    BullVaultPolicy policy,
    Seed seed, {
    String? passphrase,
  }) {
    final seedBytes = switch ((seed, passphrase)) {
      (MnemonicSeed(:final mnemonicWords), final String value)
          when value.isNotEmpty =>
        Uint8List.fromList(
          bip39.Mnemonic.fromWords(
            words: mnemonicWords,
            passphrase: value,
          ).seed,
        ),
      _ => _canonicalSeedBytes(seed),
    };
    return _matchesSeedIdentity(policy.everydayKey, seedBytes);
  }

  String canonicalSeedFingerprint(Seed seed) =>
      bip32.Bip32Keys.fromSeed(_canonicalSeedBytes(seed)).fingerprintHex;

  BullVaultPolicy? recognizeStructure(String source, Network network) {
    final parsed = _descriptorPort.parseBitcoinDescriptor(
      descriptor: source.trim(),
      network: network,
    );
    final grouped = <String, List<WalletDescriptorKey>>{};
    for (final key in parsed.descriptorKeys) {
      grouped.putIfAbsent(_canonicalXpub(key.xpub), () => []).add(key);
    }
    if (grouped.length < 2 || grouped.length > 5) return null;
    final activations =
        _activation
            .allMatches(parsed.descriptor)
            .map((match) => int.parse(match.group(1)!))
            .toSet()
            .toList()
          ..sort();
    final matches = <BullVaultPolicy>[];
    for (final shape in _shapesFor(grouped.length, activations)) {
      for (final ordered in _permutations(grouped.values.toList())) {
        try {
          var index = 0;
          final everydayGroup = ordered[index++];
          final delayedMobileRecoveryGroup = shape.usesRecoveryKey
              ? ordered[index++]
              : null;
          final coldGroup = ordered[index++];
          final secondColdGroup = shape.protection.usesTwoColdKeys
              ? ordered[index++]
              : null;
          final inheritanceGroup = shape.includesInheritance
              ? ordered[index]
              : null;
          final generation = _generationFor(
            protection: shape.protection,
            includesInheritance: shape.includesInheritance,
            everyday: everydayGroup,
            delayedMobileRecovery: delayedMobileRecoveryGroup,
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
              signer: SignerEntity.none,
            ),
            delayedMobileRecoveryKey: delayedMobileRecoveryGroup == null
                ? null
                : _signer(
                    delayedMobileRecoveryGroup,
                    BullVaultSignerRole.delayedMobileRecovery,
                    signer: SignerEntity.none,
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
        delayedMobileRecoveryKey: policy.delayedMobileRecoveryKey,
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

  bool _matchesSeedBytes(BullVaultSignerKey signer, Uint8List seedBytes) {
    final path = signer.accountKey.derivationPath;
    if (path == null) return false;
    return Bip32Derivation.seedMatchesXpub(
      seedBytes: seedBytes,
      derivationPath: path,
      xpub: signer.accountKey.xpub,
    );
  }

  bool _matchesSeedIdentity(BullVaultSignerKey signer, Uint8List seedBytes) =>
      signer.accountKey.masterFingerprint.toLowerCase() ==
          bip32.Bip32Keys.fromSeed(seedBytes).fingerprintHex.toLowerCase() &&
      _matchesSeedBytes(signer, seedBytes);

  Uint8List _canonicalSeedBytes(Seed seed) => switch (seed) {
    MnemonicSeed(:final mnemonicWords) => Uint8List.fromList(
      bip39.Mnemonic.fromWords(words: mnemonicWords).seed,
    ),
    BytesSeed(:final bytes) => bytes,
  };

  bool matchesExistingWallet(Wallet wallet, BullVaultPolicy policy) =>
      _matchesExistingWallet(wallet, policy, requireOwnership: true);

  bool matchesExistingWalletConfiguration(
    Wallet wallet,
    BullVaultPolicy policy,
  ) => _matchesExistingWallet(wallet, policy, requireOwnership: false);

  bool matchesEverydaySignerOwnership(Wallet wallet, BullVaultPolicy policy) {
    final expectedXpub = _canonicalXpub(policy.everydayKey.accountKey.xpub);
    final matching = wallet.signers.where(
      (signer) => signer.descriptorKeys.any(
        (key) => _canonicalXpub(key.xpub) == expectedXpub,
      ),
    );
    return matching.length == 1 &&
        matching.single.signer == policy.everydayKey.signer;
  }

  bool _matchesExistingWallet(
    Wallet wallet,
    BullVaultPolicy policy, {
    required bool requireOwnership,
  }) {
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
        ?policy.delayedMobileRecoveryKey,
        policy.coldKey,
        ?policy.secondColdKey,
        ?policy.inheritanceKey,
      ];
      final expectedSignerCount =
          policySigners.length -
          (policy.delayedMobileRecoveryKey == null ? 0 : 1);
      if (wallet.signers.length != expectedSignerCount) return false;
      for (final policySigner in policySigners) {
        final expectedXpub = _canonicalXpub(policySigner.accountKey.xpub);
        final matching = wallet.signers.where(
          (signer) => signer.descriptorKeys.any(
            (key) => _canonicalXpub(key.xpub) == expectedXpub,
          ),
        );
        if (matching.length != 1) return false;
        if (requireOwnership && matching.single.signer != policySigner.signer) {
          return false;
        }
      }
      return true;
    } on Exception {
      return false;
    }
  }

  Iterable<
    ({
      BullVaultProtection protection,
      bool includesInheritance,
      bool usesRecoveryKey,
      int? cold,
      int recovery,
      int? inheritance,
    })
  >
  _shapesFor(int signerCount, List<int> activations) sync* {
    final candidates =
        <
          ({
            BullVaultProtection protection,
            bool includesInheritance,
            bool usesRecoveryKey,
            int? cold,
            int recovery,
            int? inheritance,
          })
        >[
          if (activations.length == 2) ...[
            (
              protection: BullVaultProtection.standard,
              includesInheritance: false,
              usesRecoveryKey: signerCount == 3,
              cold: activations[0],
              recovery: activations[1],
              inheritance: null,
            ),
            (
              protection: BullVaultProtection.extra,
              includesInheritance: false,
              usesRecoveryKey: signerCount == 4,
              cold: activations[0],
              recovery: activations[1],
              inheritance: null,
            ),
            (
              protection: BullVaultProtection.extra,
              includesInheritance: true,
              usesRecoveryKey: signerCount == 5,
              cold: null,
              recovery: activations[0],
              inheritance: activations[1],
            ),
          ],
          if (activations.length == 3)
            (
              protection: BullVaultProtection.standard,
              includesInheritance: true,
              usesRecoveryKey: signerCount == 4,
              cold: activations[1],
              recovery: activations[0],
              inheritance: activations[2],
            ),
        ];
    for (final candidate in candidates) {
      final baseCount = switch ((
        candidate.protection,
        candidate.includesInheritance,
      )) {
        (BullVaultProtection.standard, false) => 2,
        (BullVaultProtection.standard, true) => 3,
        (BullVaultProtection.extra, false) => 3,
        (BullVaultProtection.extra, true) => 4,
      };
      if (signerCount == baseCount + (candidate.usesRecoveryKey ? 1 : 0)) {
        yield candidate;
      }
    }
  }

  int? _generationFor({
    required BullVaultProtection protection,
    required bool includesInheritance,
    required List<WalletDescriptorKey> everyday,
    required List<WalletDescriptorKey>? delayedMobileRecovery,
    required List<WalletDescriptorKey> cold,
    required List<WalletDescriptorKey>? secondCold,
    required List<WalletDescriptorKey>? inheritance,
  }) {
    final coldOccurrences =
        protection == BullVaultProtection.standard && includesInheritance
        ? 3
        : 2;
    final generations = <int?>[
      _generationForSigner(
        everyday,
        occurrencesPerGeneration: delayedMobileRecovery == null ? 2 : 1,
      ),
      if (delayedMobileRecovery != null)
        _generationForSigner(
          delayedMobileRecovery,
          occurrencesPerGeneration: 1,
        ),
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
    SignerEntity signer = SignerEntity.remote,
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
      signer: signer,
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
