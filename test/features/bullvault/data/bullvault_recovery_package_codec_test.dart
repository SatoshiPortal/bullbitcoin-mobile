import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bullvault_test_fixture.dart';
import '../../../core_test/wallet/bdk_wallet_test_fixture.dart';

const _fourthMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

void main() {
  final descriptorPort = _ParsingDescriptorPort();
  final descriptorService = BullVaultDescriptorService(descriptorPort);
  final codec = BullVaultRecoveryPackageCodec(descriptorService);

  test('serializes the compact public recovery format', () {
    final policy = _policy(
      descriptorPort,
      protection: BullVaultProtection.standard,
      includesInheritance: true,
    );
    final encoded = codec.encode(BullVaultRecoveryPackage(policy: policy));
    final golden = File(
      'test/features/bullvault/data/fixtures/bullvault_recovery_v1.json',
    ).readAsStringSync().trim();
    final json = jsonDecode(encoded) as Map<String, dynamic>;

    expect(encoded, golden);
    expect(json.keys, {
      'birthHeight',
      'createdAt',
      'descriptor',
      'lineageId',
      'network',
      'policyVersion',
      'schedule',
      'schemaVersion',
    });
    expect(encoded, isNot(contains('mnemonic')));
    expect(encoded, isNot(contains('privateKey')));

    final restored = codec.decode(encoded);
    expect(restored.policy.descriptor, policy.descriptor);
    expect(restored.policy.schedule?.coldDelay, 3);
    expect(restored.policy.schedule?.recoveryDelay, 2);
    expect(restored.policy.schedule?.inheritanceDelay, 5);
  });

  for (final profile in [
    (protection: BullVaultProtection.standard, includesInheritance: false),
    (protection: BullVaultProtection.standard, includesInheritance: true),
    (protection: BullVaultProtection.extra, includesInheritance: false),
    (protection: BullVaultProtection.extra, includesInheritance: true),
  ]) {
    test('reconstructs ${profile.protection.name} protection '
        '${profile.includesInheritance ? 'with' : 'without'} inheritance', () {
      final policy = _policy(
        descriptorPort,
        protection: profile.protection,
        includesInheritance: profile.includesInheritance,
      );

      final restored = codec.decode(
        codec.encode(BullVaultRecoveryPackage(policy: policy)),
      );

      expect(restored.policy.descriptor, policy.descriptor);
      expect(restored.policy.protection, profile.protection);
      expect(
        restored.policy.inheritanceKey != null,
        profile.includesInheritance,
      );
      expect(
        restored.policy.secondColdKey != null,
        profile.protection.usesTwoColdKeys,
      );
      expect(restored.policy.vaultGeneration, 0);
    });
  }

  test('preserves renewed vault lineage and predecessor', () {
    final policy = _policy(
      descriptorPort,
      protection: BullVaultProtection.standard,
      includesInheritance: true,
      generation: 1,
      lineageId: 'original-lineage',
    );
    final restored = codec.decode(
      codec.encode(
        BullVaultRecoveryPackage(
          previousVaultId: 'previous-wallet',
          policy: policy,
        ),
      ),
    );

    expect(restored.policy.lineageId, 'original-lineage');
    expect(restored.policy.vaultGeneration, 1);
    expect(restored.policy.inheritanceKey, isNotNull);
    expect(restored.previousVaultId, 'previous-wallet');
  });

  for (final protection in BullVaultProtection.values) {
    for (final recoveryKey in [false, true]) {
      test(
        'restores ${protection.name} last-resort recovery with recovery key: $recoveryKey',
        () {
          final schedule = BullVaultSchedule.defaultsFor(
            protection: protection,
            includesInheritance: true,
            unit: BullVaultScheduleUnit.hours,
          ).copyWith(lastResortDelay: 7);
          final policy = _policy(
            descriptorPort,
            protection: protection,
            includesInheritance: true,
            generation: 1,
            lineageId: 'lineage',
            schedule: schedule,
            delayedMobileRecovery: recoveryKey,
          );
          final json =
              jsonDecode(
                    codec.encode(
                      BullVaultRecoveryPackage(
                        policy: policy,
                        previousVaultId: 'previous-vault',
                      ),
                    ),
                  )
                  as Map<String, dynamic>;
          final restored = codec.decode(jsonEncode(json)).policy;
          expect(restored.descriptor, policy.descriptor);
          expect(restored.schedule?.lastResortDelay, 7);
          expect(
            restored.lastResortActivationTimestamp,
            policy.lastResortActivationTimestamp,
          );
          expect(restored.vaultGeneration, 1);
          expect(restored.delayedMobileRecoveryKey != null, recoveryKey);

          final scheduleJson = json['schedule'] as Map<String, dynamic>;
          scheduleJson['lastResort'] = 8;
          expect(() => codec.decode(jsonEncode(json)), throwsFormatException);
          json.remove('schedule');
          final unknownSchedule = codec.decode(jsonEncode(json)).policy;
          expect(unknownSchedule.schedule, isNull);
          expect(
            unknownSchedule.lastResortActivationTimestamp,
            policy.lastResortActivationTimestamp,
          );
          expect(unknownSchedule.renewalSchedule.lastResortDelay, 7);
        },
      );
    }
  }

  test('preserves known metadata when enriching a recovery package', () {
    final original = BullVaultRecoveryPackage(
      policy: _policy(
        descriptorPort,
        protection: BullVaultProtection.standard,
        includesInheritance: false,
        generation: 1,
        lineageId: 'original-lineage',
      ),
      previousVaultId: 'previous-wallet',
    );
    final json = jsonDecode(codec.encode(original)) as Map<String, dynamic>;
    expect(original.canBeEnrichedBy(codec.decode(jsonEncode(json))), isTrue);

    for (final changes in <Map<String, dynamic>>[
      {'birthHeight': original.policy.birthHeight! + 1},
      {'schedule': null},
      {'lineageId': 'different-lineage'},
      {'previousVaultId': 'different-wallet'},
    ]) {
      final incoming = {...json, ...changes}
        ..removeWhere((_, value) => value == null);
      expect(
        original.canBeEnrichedBy(codec.decode(jsonEncode(incoming))),
        isFalse,
        reason: 'Known metadata cannot be replaced or forgotten: $changes',
      );
    }

    final withoutSchedule = {...json}..remove('schedule');
    final knownDate = codec.decode(jsonEncode(withoutSchedule));
    withoutSchedule['createdAt'] = '2028-01-15T12:00:00Z';
    expect(
      knownDate.canBeEnrichedBy(codec.decode(jsonEncode(withoutSchedule))),
      isFalse,
    );
  });

  test('preserves practice schedule timing', () {
    const schedule = BullVaultSchedule(
      coldDelay: 2,
      recoveryDelay: 3,
      unit: BullVaultScheduleUnit.hours,
    );
    final policy = _policy(
      descriptorPort,
      protection: BullVaultProtection.standard,
      includesInheritance: false,
      schedule: schedule,
    );

    final restored = codec.decode(
      codec.encode(BullVaultRecoveryPackage(policy: policy)),
    );

    expect(restored.policy.schedule?.unit, BullVaultScheduleUnit.hours);
    expect(
      restored.policy.coldActivationTimestamp,
      schedule.coldActivationTimestamp(policy.createdAt!),
    );
    expect(
      restored.policy.recoveryActivationTimestamp,
      schedule.recoveryActivationTimestamp(policy.createdAt!),
    );
  });

  test('validates optional schedule metadata against the descriptor', () {
    final policy = _policy(
      descriptorPort,
      protection: BullVaultProtection.standard,
      includesInheritance: false,
    );
    final json =
        jsonDecode(codec.encode(BullVaultRecoveryPackage(policy: policy)))
            as Map<String, dynamic>;
    final schedule = json['schedule'] as Map<String, dynamic>;
    schedule['recovery'] = (schedule['recovery'] as int) + 1;

    expect(() => codec.decode(jsonEncode(json)), throwsFormatException);

    json['schedule'] = null;
    final restored = codec.decode(jsonEncode(json));
    expect(restored.policy.schedule, isNull);
    expect(restored.policy.recoveryActivationTimestamp, isNotNull);
  });

  test('restores descriptor-only data without fabricated metadata', () {
    final created = _policy(
      descriptorPort,
      protection: BullVaultProtection.extra,
      includesInheritance: true,
    );
    final recognized = descriptorService.recognizeStructure(
      created.descriptor,
      created.network,
    )!;
    final encoded = codec.encode(BullVaultRecoveryPackage(policy: recognized));
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final restored = codec.decode(encoded);

    expect(json, isNot(contains('birthHeight')));
    expect(json, isNot(contains('createdAt')));
    expect(json, isNot(contains('schedule')));
    expect(restored.policy.birthHeight, isNull);
    expect(restored.policy.createdAt, isNull);
    expect(restored.policy.schedule, isNull);
    expect(restored.policy.descriptor, created.descriptor);
  });

  test('rejects invalid recovery metadata without masking internal errors', () {
    final policy = _policy(
      descriptorPort,
      protection: BullVaultProtection.standard,
      includesInheritance: false,
    );
    final json =
        jsonDecode(codec.encode(BullVaultRecoveryPackage(policy: policy)))
            as Map<String, dynamic>;
    json['unexpected'] = true;

    expect(() => codec.decode(jsonEncode(json)), throwsFormatException);
    json.remove('unexpected');
    final valid = Map<String, dynamic>.from(json);
    for (final invalid in <Map<String, Object>>[
      {'network': 'unknown'},
      {'network': Network.liquidMainnet.name},
      {'network': Network.liquidTestnet.name},
      {'descriptor': 42},
      {'lineageId': false},
      {'birthHeight': 'invalid'},
      {'previousVaultId': []},
    ]) {
      expect(
        () => codec.decode(jsonEncode({...valid, ...invalid})),
        throwsFormatException,
        reason: '$invalid',
      );
    }
    descriptorPort.failParsing = true;
    addTearDown(() => descriptorPort.failParsing = false);
    expect(() => codec.decode(jsonEncode(valid)), throwsStateError);
  });
}

BullVaultPolicy _policy(
  BitcoinDescriptorPort descriptorPort, {
  required BullVaultProtection protection,
  required bool includesInheritance,
  int generation = 0,
  String? lineageId,
  BullVaultSchedule? schedule,
  bool delayedMobileRecovery = false,
}) {
  final signers = [
    _signer(
      BullVaultSignerRole.everyday,
      0,
      deriveSignerKeys(
        testMnemonics[0],
        password: delayedMobileRecovery ? 'vault passphrase' : '',
      ),
    ),
    _signer(BullVaultSignerRole.cold, 1, deriveSignerKeys(testMnemonics[1])),
    if (protection.usesTwoColdKeys)
      _signer(
        BullVaultSignerRole.secondCold,
        2,
        deriveSignerKeys(testMnemonics[2]),
      ),
    if (includesInheritance)
      _signer(
        BullVaultSignerRole.inheritance,
        3,
        deriveSignerKeys(_fourthMnemonic),
      ),
  ];
  final everyday = signers[0];
  final recovery = delayedMobileRecovery
      ? _signer(
          BullVaultSignerRole.delayedMobileRecovery,
          0,
          deriveSignerKeys(testMnemonics[0]),
        )
      : null;
  final cold = signers[1];
  final secondCold = protection.usesTwoColdKeys ? signers[2] : null;
  final inheritance = includesInheritance ? signers.last : null;
  schedule ??= BullVaultSchedule.defaultsFor(
    protection: protection,
    includesInheritance: includesInheritance,
  );
  final createdAt = DateTime.utc(2027, 1, 15, 12);
  final descriptor = descriptorPort
      .parseBitcoinDescriptor(
        descriptor: BullVaultPolicy.descriptorTemplate(
          vaultGeneration: generation,
          network: Network.bitcoinTestnet,
          protection: protection,
          everydayKey: everyday,
          delayedMobileRecoveryKey: recovery,
          coldKey: cold,
          secondColdKey: secondCold,
          inheritanceKey: inheritance,
          schedule: schedule,
          referenceTime: createdAt,
        ),
        network: Network.bitcoinTestnet,
      )
      .descriptor;
  return BullVaultPolicy.build(
    lineageId: lineageId,
    vaultGeneration: generation,
    network: Network.bitcoinTestnet,
    descriptor: descriptor,
    protection: protection,
    everydayKey: everyday,
    delayedMobileRecoveryKey: recovery,
    coldKey: cold,
    secondColdKey: secondCold,
    inheritanceKey: inheritance,
    schedule: schedule,
    timeReference: BullVaultTimeReference(
      deviceTime: createdAt,
      chainHeight: 3_000_000,
      medianTimePast:
          createdAt.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    ),
  );
}

BullVaultSignerKey _signer(
  BullVaultSignerRole role,
  int index,
  SignerDescriptorKeys keys,
) => BullVaultSignerKey(
  role: role,
  accountKey: WalletDescriptorKey(
    id: 'key-$index',
    signerId: role.name,
    masterFingerprint: keys.fingerprint,
    xpubFingerprint: keys.fingerprint,
    xpub: keys.xpub.split(']').last,
    derivationPath: "m/48'/1'/0'/2'",
  ),
  signer:
      role == BullVaultSignerRole.everyday ||
          role == BullVaultSignerRole.delayedMobileRecovery
      ? SignerEntity.local
      : SignerEntity.remote,
  signerDevice: null,
);

final class _ParsingDescriptorPort implements BitcoinDescriptorPort {
  bool failParsing = false;
  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) {
    if (failParsing) throw StateError('Descriptor parsing failed');
    return parseTestBullVaultDescriptor(
      descriptor: descriptor,
      network: network,
    );
  }

  @override
  ({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
  analyzeBitcoinPolicyDescriptor({
    required String descriptor,
    required Network network,
  }) => throw UnimplementedError();

  @override
  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool isHidden = false,
    bool sync = false,
  }) => throw UnimplementedError();
}
