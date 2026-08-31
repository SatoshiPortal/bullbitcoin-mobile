import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core_test/wallet/bdk_wallet_test_fixture.dart';

void main() {
  test('requires only the selected signer inputs and a valid schedule', () {
    const initial = BullVaultOnboardingState();
    expect(initial.step, BullVaultOnboardingStep.setupChoice);
    expect(initial.canContinue, isFalse);
    expect(
      initial.copyWith(network: Network.bitcoinTestnet).canContinue,
      isTrue,
    );

    final coldStep = initial.copyWith(
      step: BullVaultOnboardingStep.coldSigner,
      network: Network.bitcoinTestnet,
      coldDevice: SignerDeviceEntity.bitbox02,
      coldInput: '[deadbeef/48h/1h/0h/2h]tpub',
    );
    expect(coldStep.canContinue, isTrue);

    final inheritanceStep = coldStep.copyWith(
      step: BullVaultOnboardingStep.inheritance,
      includeInheritance: true,
    );
    expect(inheritanceStep.canContinue, isFalse);
    expect(
      inheritanceStep
          .copyWith(
            genericInheritanceSigner: true,
            inheritanceInput: '[cafebabe/48h/1h/0h/2h]tpub',
          )
          .canContinue,
      isTrue,
    );
    expect(
      inheritanceStep
          .copyWith(
            step: BullVaultOnboardingStep.review,
            schedule: const BullVaultSchedule(coldYears: 3, recoveryYears: 3),
            timeReference: _timeReference(),
          )
          .canContinue,
      isFalse,
    );
  });

  test('opens a locally controlled vault only after backup gates', () {
    final signers = [
      for (final (index, words) in testMnemonics.take(2).indexed)
        _signerKey(index, deriveSignerKeys(words)),
    ];
    final policy = BullVaultPolicy.build(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      descriptor: 'tr(test)',
      protection: BullVaultProtection.standard,
      everydayKey: signers[0],
      coldKey: signers[1],
      secondColdKey: null,
      inheritanceKey: null,
      schedule: BullVaultSchedule.standardWithoutInheritance,
      timeReference: _timeReference(),
    );
    final recoveryPackage = BullVaultRecoveryPackage(policy: policy);
    final result = BullVaultCreateResult(
      wallet: Wallet(
        origin: 'bullvault-wallet',
        network: Network.bitcoinTestnet,
        signers: [],
        scriptType: null,
        publicDescriptor: 'tr(test)',
        balanceSat: BigInt.zero,
      ),
      policy: policy,
      record: BullVaultRecord(
        walletId: 'bullvault-wallet',
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: 0,
        birthHeight: 3_000_000,
        recoveryPackage: recoveryPackage,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      recoveryPackage: recoveryPackage,
    );

    final initial = BullVaultOnboardingState(
      step: BullVaultOnboardingStep.complete,
      result: result,
    );
    final exported = initial.copyWith(
      recoveryPackageExported: true,
      recoveryPackageConfirmed: true,
    );

    expect(initial.canOpenWallet, isFalse);
    expect(exported.canOpenWallet, isFalse);
    expect(exported.copyWith(seedBackupVerified: true).canOpenWallet, isTrue);
    expect(
      exported.copyWith(recoverBullBackupVerified: true).canOpenWallet,
      isTrue,
    );
    expect(exported.copyWith(mobileBackupDeferred: true).canOpenWallet, isTrue);
  });

  test('requires setup or deferral for a generic hardware signer', () {
    final everyday = _signerKey(0, deriveSignerKeys(testMnemonics.first));
    final cold = _signerKey(1, deriveSignerKeys(testMnemonics[1]));
    final coldWalletSigner = WalletSigner(
      id: cold.role.name,
      signer: SignerEntity.remote,
      signerDevice: null,
      descriptorKeys: [cold.accountKey],
    );
    final policy = BullVaultPolicy.build(
      vaultGeneration: 0,
      network: Network.bitcoinTestnet,
      descriptor: 'tr(test)',
      protection: BullVaultProtection.standard,
      everydayKey: everyday,
      coldKey: cold,
      secondColdKey: null,
      inheritanceKey: null,
      schedule: BullVaultSchedule.standardWithoutInheritance,
      timeReference: _timeReference(),
    );
    final result = BullVaultCreateResult(
      wallet: Wallet(
        origin: 'bullvault-wallet',
        network: Network.bitcoinTestnet,
        signers: [
          WalletSigner(
            id: everyday.role.name,
            signer: SignerEntity.local,
            signerDevice: null,
            descriptorKeys: [everyday.accountKey],
          ),
          coldWalletSigner,
        ],
        scriptType: null,
        publicDescriptor: 'tr(test)',
        balanceSat: BigInt.zero,
      ),
      policy: policy,
      record: BullVaultRecord(
        walletId: 'bullvault-wallet',
        lineageId: policy.lineageId,
        vaultGeneration: policy.vaultGeneration,
        mobileAccount: 0,
        birthHeight: 3_000_000,
        recoveryPackage: BullVaultRecoveryPackage(policy: policy),
        createdAt: DateTime.utc(2027, 1, 15),
      ),
      recoveryPackage: BullVaultRecoveryPackage(policy: policy),
    );
    final readyExceptHardware = BullVaultOnboardingState(
      step: BullVaultOnboardingStep.complete,
      result: result,
      recoveryPackageExported: true,
      recoveryPackageConfirmed: true,
      seedBackupVerified: true,
    );

    expect(readyExceptHardware.canOpenWallet, isFalse);
    expect(readyExceptHardware.hardwareSignerCount, 1);
    final deferred = readyExceptHardware.copyWith(hardwareSetupDeferred: true);
    expect(deferred.canOpenWallet, isTrue);
    expect(deferred.hardwareSetupComplete, isFalse);
  });
}

BullVaultTimeReference _timeReference() => BullVaultTimeReference(
  deviceTime: DateTime.utc(2027, 1, 15, 12),
  chainHeight: 3_000_000,
  medianTimePast: DateTime.utc(2027, 1, 15, 11).millisecondsSinceEpoch ~/ 1000,
);

BullVaultSignerKey _signerKey(int index, SignerDescriptorKeys keys) {
  final role = BullVaultSignerRole.values[index];
  return BullVaultSignerKey(
    role: role,
    accountKey: WalletDescriptorKey(
      id: 'key-$index',
      signerId: role.name,
      masterFingerprint: keys.fingerprint,
      xpubFingerprint: keys.fingerprint,
      xpub: keys.xpub.split(']').last,
      derivationPath: "m/48'/1'/0'/2'",
    ),
    signer: role == BullVaultSignerRole.everyday
        ? SignerEntity.local
        : SignerEntity.remote,
    signerDevice: null,
  );
}
