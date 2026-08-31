import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/ledger/data/ledger_wallet_policy_adapter.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

const _fourthMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

void main() {
  test('builds the policy with absolute timestamps', () {
    final keys = [
      for (final (index, words) in testMnemonics.take(3).indexed)
        _signerKey(index, deriveSignerKeys(words)),
    ];
    final referenceTime = DateTime.utc(2027, 1, 15, 12);

    for (final inheritanceKey in [null, keys[2]]) {
      final schedule = inheritanceKey == null
          ? BullVaultSchedule.standardWithoutInheritance
          : BullVaultSchedule.standardWithInheritance;
      final descriptor = BullVaultPolicy.descriptorTemplate(
        vaultGeneration: 0,
        network: Network.bitcoinTestnet,
        protection: BullVaultProtection.standard,
        everydayKey: keys[0],
        coldKey: keys[1],
        secondColdKey: null,
        inheritanceKey: inheritanceKey,
        schedule: schedule,
        referenceTime: referenceTime,
      );
      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      );

      expect(parsed.descriptor, startsWith('tr('));
      expect(parsed.externalDescriptor, contains('/0/*'));
      expect(parsed.internalDescriptor, contains('/1/*'));
      expect(parsed.unspendablePolicyKeyIdentifiers, isNotEmpty);
      expect(descriptor, contains('multi_a(2,'));
      expect(
        descriptor,
        contains('after(${schedule.coldActivationTimestamp(referenceTime)})'),
      );
      expect(
        descriptor,
        contains(
          'after(${schedule.recoveryActivationTimestamp(referenceTime)})',
        ),
      );
      if (inheritanceKey == null) {
        expect(parsed.keys, hasLength(4));
        expect(parsed.keys.map((key) => key.xpub).toSet(), hasLength(2));
        expect(
          descriptor,
          isNot(
            contains(
              'after(${schedule.inheritanceActivationTimestamp(referenceTime)})',
            ),
          ),
        );
      } else {
        expect(parsed.keys, hasLength(7));
        expect(parsed.keys.map((key) => key.xpub).toSet(), hasLength(3));
        expect(
          descriptor,
          contains(
            'after(${schedule.inheritanceActivationTimestamp(referenceTime)})',
          ),
        );
      }
    }
  });

  test('allocates branch pairs per signer occurrence and generation', () {
    final keys = [
      for (final (index, words) in testMnemonics.take(3).indexed)
        _signerKey(index, deriveSignerKeys(words)),
    ];
    final first = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.standard,
      everydayKey: keys[0],
      coldKey: keys[1],
      secondColdKey: null,
      inheritanceKey: keys[2],
      schedule: BullVaultSchedule.standardWithInheritance,
      referenceTime: DateTime.utc(2027, 1, 15, 12),
    );
    final second = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 1,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.standard,
      everydayKey: keys[0],
      coldKey: keys[1],
      secondColdKey: null,
      inheritanceKey: keys[2],
      schedule: BullVaultSchedule.standardWithInheritance,
      referenceTime: DateTime.utc(2030, 1, 15, 12),
    );
    final expandedSecond = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: second,
      isTestnet: true,
    );

    expect(_branchPairs(first, keys[0]), ['<0;1>', '<2;3>']);
    expect(_branchPairs(first, keys[1]), ['<0;1>', '<2;3>', '<4;5>']);
    expect(_branchPairs(first, keys[2]), ['<0;1>', '<2;3>']);
    expect(_branchPairs(second, keys[0]), ['<4;5>', '<6;7>']);
    expect(_branchPairs(second, keys[1]), ['<6;7>', '<8;9>', '<10;11>']);
    expect(_branchPairs(second, keys[2]), ['<4;5>', '<6;7>']);
    expect(first, isNot(contains('<6;7>')));
    expect(second, isNot(contains('<12;13>')));
    expect(
      _signerBranchRoles(first).intersection(_signerBranchRoles(second)),
      isEmpty,
    );
    expect(expandedSecond.externalDescriptor, contains('/4/*'));
    expect(expandedSecond.externalDescriptor, contains('/6/*'));
    expect(expandedSecond.externalDescriptor, contains('/8/*'));
    expect(expandedSecond.externalDescriptor, contains('/10/*'));
    expect(expandedSecond.internalDescriptor, contains('/5/*'));
    expect(expandedSecond.internalDescriptor, contains('/7/*'));
    expect(expandedSecond.internalDescriptor, contains('/9/*'));
    expect(expandedSecond.internalDescriptor, contains('/11/*'));
  });

  test('expands every mixed branch pair in receive-change order', () {
    final keys = [
      for (final (index, words) in testMnemonics.take(3).indexed)
        _signerKey(index, deriveSignerKeys(words)),
    ];
    final descriptor = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.standard,
      everydayKey: keys[0],
      coldKey: keys[1],
      secondColdKey: null,
      inheritanceKey: keys[2],
      schedule: BullVaultSchedule.standardWithInheritance,
      referenceTime: DateTime.utc(2027, 1, 15, 12),
    );
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: true,
    );

    expect(
      descriptor,
      contains(
        'multi_a(2,${keys[0].expression(receiveBranch: 2, changeBranch: 3)},${keys[1].expression(receiveBranch: 2, changeBranch: 3)},${keys[2].expression(receiveBranch: 0, changeBranch: 1)})',
      ),
    );
    expect(
      descriptor,
      contains('pk(${keys[1].expression(receiveBranch: 4, changeBranch: 5)})'),
    );
    for (final key in [keys[0], keys[2]]) {
      expect(parsed.externalDescriptor, contains('${key.accountKey.xpub}/0/*'));
      expect(parsed.externalDescriptor, contains('${key.accountKey.xpub}/2/*'));
      expect(parsed.internalDescriptor, contains('${key.accountKey.xpub}/1/*'));
      expect(parsed.internalDescriptor, contains('${key.accountKey.xpub}/3/*'));
    }
    expect(
      parsed.externalDescriptor,
      contains('${keys[1].accountKey.xpub}/0/*'),
    );
    expect(
      parsed.externalDescriptor,
      contains('${keys[1].accountKey.xpub}/2/*'),
    );
    expect(
      parsed.externalDescriptor,
      contains('${keys[1].accountKey.xpub}/4/*'),
    );
    expect(
      parsed.internalDescriptor,
      contains('${keys[1].accountKey.xpub}/1/*'),
    );
    expect(
      parsed.internalDescriptor,
      contains('${keys[1].accountKey.xpub}/3/*'),
    );
    expect(
      parsed.internalDescriptor,
      contains('${keys[1].accountKey.xpub}/5/*'),
    );
  });

  test('retains mixed branch pairs in Ledger policy serialization', () {
    final keys = [
      for (final (index, words) in testMnemonics.take(3).indexed)
        _signerKey(index, deriveSignerKeys(words)),
    ];
    final descriptor = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.standard,
      everydayKey: keys[0],
      coldKey: keys[1],
      secondColdKey: null,
      inheritanceKey: keys[2],
      schedule: BullVaultSchedule.standardWithInheritance,
      referenceTime: DateTime.utc(2027, 1, 15, 12),
    );
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: true,
    );
    final groupedKeys = <String, List<WalletDescriptorKey>>{};
    for (final (index, key) in parsed.keys.indexed) {
      final descriptorKeys = groupedKeys.putIfAbsent(key.xpub, () => []);
      final signerIndex = groupedKeys.keys.toList().indexOf(key.xpub);
      descriptorKeys.add(
        WalletDescriptorKey(
          id: 'key-$index',
          signerId: 'signer-$signerIndex',
          masterFingerprint: key.masterFingerprint,
          xpubFingerprint: key.xpubFingerprint,
          xpub: key.xpub,
          derivationPath: key.derivationPath,
          descriptorPath: key.descriptorPath,
        ),
      );
    }
    final wallet = Wallet(
      origin: 'bullvault-wallet',
      network: Network.bitcoinTestnet,
      signers: [
        for (final (index, descriptorKeys) in groupedKeys.values.indexed)
          WalletSigner(
            id: 'signer-$index',
            signer: SignerEntity.remote,
            signerDevice: index == 0 ? SignerDeviceEntity.ledgerNanoX : null,
            descriptorKeys: descriptorKeys,
          ),
      ],
      scriptType: null,
      publicDescriptor: descriptor,
      balanceSat: BigInt.zero,
    );
    final policy = LedgerWalletPolicyAdapter.fromWallet(
      wallet,
      descriptorPolicyKeys: [
        for (final (index, key) in parsed.policyKeys.indexed)
          WalletDescriptorKey(
            id: 'policy-key-$index',
            signerId: 'policy-signer-$index',
            masterFingerprint: key.masterFingerprint,
            xpubFingerprint: key.xpubFingerprint,
            xpub: key.xpub,
            derivationPath: key.derivationPath,
            descriptorPath: key.descriptorPath,
          ),
      ],
    );

    expect(
      policy.descriptorTemplate,
      contains('multi_a(2,@1/<2;3>/*,@2/<2;3>/*,@3/**)'),
    );
  });

  test('keeps the canonical generation-zero descriptor vectors stable', () {
    final keys = [
      for (final (index, words) in testMnemonics.take(3).indexed)
        _signerKey(index, deriveSignerKeys(words)),
    ];

    for (final (inheritanceKey, checksum) in [
      (null, 'ztlp735s'),
      (keys[2], 'pj9mqqzq'),
    ]) {
      final descriptor = BullVaultPolicy.descriptorTemplate(
        vaultGeneration: 0,
        network: Network.bitcoinTestnet,
        protection: BullVaultProtection.standard,
        everydayKey: keys[0],
        coldKey: keys[1],
        secondColdKey: null,
        inheritanceKey: inheritanceKey,
        schedule: inheritanceKey == null
            ? BullVaultSchedule.standardWithoutInheritance
            : BullVaultSchedule.standardWithInheritance,
        referenceTime: DateTime.utc(2027, 1, 15, 12),
      );

      expect(
        BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        ).descriptor,
        '$descriptor#$checksum',
      );
    }
  });

  test('adds delayed cold and mobile recovery to extra protection', () {
    final everyday = _signerForRole(
      BullVaultSignerRole.everyday,
      0,
      deriveSignerKeys(testMnemonics[0]),
    );
    final cold = _signerForRole(
      BullVaultSignerRole.cold,
      1,
      deriveSignerKeys(testMnemonics[1]),
    );
    final secondCold = _signerForRole(
      BullVaultSignerRole.secondCold,
      2,
      deriveSignerKeys(testMnemonics[2]),
    );
    const schedule = BullVaultSchedule.extraWithoutInheritance;
    final referenceTime = DateTime.utc(2027, 1, 15, 12);
    final descriptor = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.extra,
      everydayKey: everyday,
      coldKey: cold,
      secondColdKey: secondCold,
      inheritanceKey: null,
      schedule: schedule,
      referenceTime: referenceTime,
    );
    final primary =
        'multi_a(2,${everyday.expression(receiveBranch: 0, changeBranch: 1)},${cold.expression(receiveBranch: 0, changeBranch: 1)},${secondCold.expression(receiveBranch: 0, changeBranch: 1)})';
    final coldRecovery =
        'after(${schedule.coldActivationTimestamp(referenceTime)}),multi_a(1,${cold.expression(receiveBranch: 2, changeBranch: 3)},${secondCold.expression(receiveBranch: 2, changeBranch: 3)})';
    final mobileRecovery =
        'after(${schedule.recoveryActivationTimestamp(referenceTime)}),pk(${everyday.expression(receiveBranch: 2, changeBranch: 3)})';
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: true,
    );

    expect(descriptor, contains(primary));
    expect(descriptor, contains(coldRecovery));
    expect(descriptor, contains(mobileRecovery));
    expect(_branchPairs(descriptor, everyday), ['<0;1>', '<2;3>']);
    expect(_branchPairs(descriptor, cold), ['<0;1>', '<2;3>']);
    expect(_branchPairs(descriptor, secondCold), ['<0;1>', '<2;3>']);
    expect(parsed.keys, hasLength(6));
    expect(parsed.descriptor, '$descriptor#stz7t0gw');
  });

  test('adds inheritance recovery to extra protection without owner solos', () {
    final everyday = _signerForRole(
      BullVaultSignerRole.everyday,
      0,
      deriveSignerKeys(testMnemonics[0]),
    );
    final cold = _signerForRole(
      BullVaultSignerRole.cold,
      1,
      deriveSignerKeys(testMnemonics[1]),
    );
    final secondCold = _signerForRole(
      BullVaultSignerRole.secondCold,
      2,
      deriveSignerKeys(testMnemonics[2]),
    );
    final inheritance = _signerForRole(
      BullVaultSignerRole.inheritance,
      3,
      deriveSignerKeys(_fourthMnemonic),
    );
    const schedule = BullVaultSchedule.extraWithInheritance;
    final referenceTime = DateTime.utc(2027, 1, 15, 12);
    final descriptor = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      protection: BullVaultProtection.extra,
      everydayKey: everyday,
      coldKey: cold,
      secondColdKey: secondCold,
      inheritanceKey: inheritance,
      schedule: schedule,
      referenceTime: referenceTime,
    );
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: true,
    );
    final delayedThreshold =
        'after(${schedule.recoveryActivationTimestamp(referenceTime)}),multi_a(2,${everyday.expression(receiveBranch: 2, changeBranch: 3)},${cold.expression(receiveBranch: 2, changeBranch: 3)},${secondCold.expression(receiveBranch: 2, changeBranch: 3)},${inheritance.expression(receiveBranch: 0, changeBranch: 1)})';
    final inheritanceSolo =
        'after(${schedule.inheritanceActivationTimestamp(referenceTime)}),pk(${inheritance.expression(receiveBranch: 2, changeBranch: 3)})';

    expect(descriptor, contains(delayedThreshold));
    expect(descriptor, contains(inheritanceSolo));
    for (final signer in [everyday, cold, secondCold, inheritance]) {
      expect(_branchPairs(descriptor, signer), ['<0;1>', '<2;3>']);
    }
    expect(
      descriptor,
      isNot(
        contains(
          'pk(${everyday.expression(receiveBranch: 2, changeBranch: 3)})',
        ),
      ),
    );
    expect(
      descriptor,
      isNot(
        contains('pk(${cold.expression(receiveBranch: 2, changeBranch: 3)})'),
      ),
    );
    expect(
      descriptor,
      isNot(
        contains(
          'pk(${secondCold.expression(receiveBranch: 2, changeBranch: 3)})',
        ),
      ),
    );
    expect(parsed.externalDescriptor, contains('/0/*'));
    expect(parsed.externalDescriptor, contains('/2/*'));
    expect(parsed.internalDescriptor, contains('/1/*'));
    expect(parsed.internalDescriptor, contains('/3/*'));
    expect(parsed.keys, hasLength(8));
    expect(parsed.descriptor, '$descriptor#0dmvnp4r');
  });

  test(
    'keeps extra-protection signer branches disjoint across generations',
    () {
      final signers = [
        _signerForRole(
          BullVaultSignerRole.everyday,
          0,
          deriveSignerKeys(testMnemonics[0]),
        ),
        _signerForRole(
          BullVaultSignerRole.cold,
          1,
          deriveSignerKeys(testMnemonics[1]),
        ),
        _signerForRole(
          BullVaultSignerRole.secondCold,
          2,
          deriveSignerKeys(testMnemonics[2]),
        ),
        _signerForRole(
          BullVaultSignerRole.inheritance,
          3,
          deriveSignerKeys(_fourthMnemonic),
        ),
      ];
      final descriptor = BullVaultPolicy.descriptorTemplate(
        vaultGeneration: 1,
        network: Network.bitcoinTestnet,
        protection: BullVaultProtection.extra,
        everydayKey: signers[0],
        coldKey: signers[1],
        secondColdKey: signers[2],
        inheritanceKey: signers[3],
        schedule: BullVaultSchedule.extraWithInheritance,
        referenceTime: DateTime.utc(2030, 1, 15, 12),
      );

      for (final signer in signers) {
        expect(_branchPairs(descriptor, signer), ['<4;5>', '<6;7>']);
      }
      expect(descriptor, isNot(contains('<8;9>')));
    },
  );

  test('uses the active network extended key encoding', () {
    final keys = [
      for (final (index, words) in testMnemonics.take(2).indexed)
        _signerKey(
          index,
          deriveSignerKeys(words, isTestnet: false),
          network: Network.bitcoinMainnet,
        ),
    ];
    final descriptor = BullVaultPolicy.descriptorTemplate(
      vaultGeneration: 0,
      network: Network.bitcoinMainnet,
      protection: BullVaultProtection.standard,
      everydayKey: keys[0],
      coldKey: keys[1],
      secondColdKey: null,
      inheritanceKey: null,
      schedule: BullVaultSchedule.standardWithoutInheritance,
      referenceTime: DateTime.utc(2027, 1, 15),
    );

    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: false,
    );

    expect(parsed.descriptor, startsWith('tr('));
    expect(parsed.keys, hasLength(4));
    expect(parsed.keys.every((key) => key.xpub.startsWith('xpub')), isTrue);
    expect(parsed.unspendablePolicyKeyIdentifiers, isNotEmpty);
  });

  test('validates adjustable schedule bounds and ordering', () {
    expect(
      BullVaultSchedule.standardWithInheritance.isValid(
        protection: BullVaultProtection.standard,
        includesInheritance: true,
      ),
      isTrue,
    );
    expect(
      const BullVaultSchedule(coldYears: 3, recoveryYears: 3).isValid(
        protection: BullVaultProtection.standard,
        includesInheritance: false,
      ),
      isFalse,
    );
    expect(
      const BullVaultSchedule(recoveryYears: 10, inheritanceYears: 5).isValid(
        protection: BullVaultProtection.extra,
        includesInheritance: false,
      ),
      isTrue,
    );
    expect(
      const BullVaultSchedule(coldYears: 5, recoveryYears: 5).isValid(
        protection: BullVaultProtection.extra,
        includesInheritance: false,
      ),
      isFalse,
    );
    expect(
      const BullVaultSchedule(recoveryYears: 10, inheritanceYears: 5).isValid(
        protection: BullVaultProtection.extra,
        includesInheritance: true,
      ),
      isFalse,
    );
    expect(
      const BullVaultSchedule(coldYears: 0).isValid(
        protection: BullVaultProtection.standard,
        includesInheritance: false,
      ),
      isFalse,
    );
    expect(
      const BullVaultSchedule(inheritanceYears: 11).isValid(
        protection: BullVaultProtection.extra,
        includesInheritance: true,
      ),
      isFalse,
    );
  });

  test('uses calendar years and clamps leap-day anniversaries', () {
    const schedule = BullVaultSchedule(coldYears: 1);

    expect(
      schedule.coldActivationDate(DateTime.utc(2028, 2, 29, 15, 30)),
      DateTime.utc(2029, 2, 28, 15, 30),
    );
  });

  test('keeps inherited two-key recovery before solo recovery', () {
    const schedule = BullVaultSchedule.standardWithInheritance;

    expect(schedule.recoveryYears, 2);
    expect(schedule.coldYears, 3);
    expect(schedule.inheritanceYears, 5);
    expect(
      schedule.isValid(
        protection: BullVaultProtection.standard,
        includesInheritance: true,
      ),
      isTrue,
    );
  });

  test('keeps extra recovery later than the standard defaults', () {
    const schedule = BullVaultSchedule.extraWithoutInheritance;

    expect(schedule.coldYears, 3);
    expect(schedule.recoveryYears, 5);
    expect(
      schedule.isValid(
        protection: BullVaultProtection.extra,
        includesInheritance: false,
      ),
      isTrue,
    );
  });

  test('rejects reused physical signer keys', () {
    final first = _signerKey(0, deriveSignerKeys(testMnemonics.first));
    final reused = BullVaultSignerKey(
      role: BullVaultSignerRole.cold,
      accountKey: first.accountKey,
      signer: first.signer,
      signerDevice: first.signerDevice,
    );

    expect(BullVaultPolicy.reusesSignerKey([first, reused]), isTrue);
  });
}

List<String> _branchPairs(String descriptor, BullVaultSignerKey signer) =>
    RegExp(
      '${RegExp.escape(signer.accountKey.xpub)}/(<[0-9]+;[0-9]+>)/\\*',
    ).allMatches(descriptor).map((match) => match.group(1)!).toList();

Set<String> _signerBranchRoles(String descriptor) => {
  for (final match in RegExp(
    r'((?:xpub|tpub)[1-9A-HJ-NP-Za-km-z]+)/(<[0-9]+;[0-9]+>)/\*',
  ).allMatches(descriptor))
    '${match.group(1)}:${match.group(2)}',
};

BullVaultSignerKey _signerKey(
  int index,
  SignerDescriptorKeys keys, {
  Network network = Network.bitcoinTestnet,
}) {
  final role = const [
    BullVaultSignerRole.everyday,
    BullVaultSignerRole.cold,
    BullVaultSignerRole.inheritance,
  ][index];
  return _signerForRole(role, index, keys, network: network);
}

BullVaultSignerKey _signerForRole(
  BullVaultSignerRole role,
  int index,
  SignerDescriptorKeys keys, {
  Network network = Network.bitcoinTestnet,
}) {
  return BullVaultSignerKey(
    role: role,
    accountKey: WalletDescriptorKey(
      id: 'key-$index',
      signerId: role.name,
      masterFingerprint: keys.fingerprint,
      xpubFingerprint: keys.fingerprint,
      xpub: keys.xpub.split(']').last,
      derivationPath: "m/48'/${network.coinType}'/0'/2'",
    ),
    signer: SignerEntity.remote,
    signerDevice: null,
  );
}
