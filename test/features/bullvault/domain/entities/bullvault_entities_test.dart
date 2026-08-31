import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault_test_fixture.dart';

void main() {
  group('BullVaultSignerKey', () {
    test('requires an account extended public key', () {
      expect(
        () => BullVaultSignerKey(
          role: BullVaultSignerRole.cold,
          accountKey: WalletDescriptorKey(
            id: 'cold',
            signerId: 'cold',
            masterFingerprint: 'deadbeef',
            xpubFingerprint: 'deadbeef',
            xpub: '',
          ),
          signer: SignerEntity.remote,
          signerDevice: null,
        ),
        throwsArgumentError,
      );
    });

    test('normalizes hardened origin notation in descriptor expressions', () {
      final key = BullVaultSignerKey(
        role: BullVaultSignerRole.cold,
        accountKey: WalletDescriptorKey(
          id: 'cold',
          signerId: 'cold',
          masterFingerprint: 'deadbeef',
          xpubFingerprint: 'deadbeef',
          xpub: 'tpub-account',
          derivationPath: 'm/48H/1h/0H/2h',
        ),
        signer: SignerEntity.remote,
        signerDevice: null,
      );

      expect(
        key.expression(receiveBranch: 0, changeBranch: 1),
        "[deadbeef/48'/1'/0'/2']tpub-account/<0;1>/*",
      );
    });
  });

  group('BullVaultTimeReference', () {
    final deviceTime = DateTime.utc(2027, 1, 15, 12);

    test('accepts the maximum chain-time difference', () {
      final reference = BullVaultTimeReference(
        deviceTime: deviceTime,
        chainHeight: 3_000_000,
        medianTimePast:
            deviceTime
                .subtract(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000,
      );

      expect(reference.deviceTime, deviceTime);
    });

    test('bounds the reviewed recovery dates', () {
      final reviewed = BullVaultTimeReference(
        deviceTime: deviceTime,
        chainHeight: 3_000_000,
        medianTimePast: deviceTime.millisecondsSinceEpoch ~/ 1000,
      );

      expect(
        reviewed.isFreshComparedTo(
          BullVaultTimeReference(
            deviceTime: deviceTime.add(BullVaultTimeReference.maxReviewAge),
            chainHeight: 3_000_001,
            medianTimePast: deviceTime.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
        isTrue,
      );
      expect(
        reviewed.isFreshComparedTo(
          BullVaultTimeReference(
            deviceTime: deviceTime.add(
              BullVaultTimeReference.maxReviewAge + const Duration(seconds: 1),
            ),
            chainHeight: 3_000_002,
            medianTimePast: deviceTime.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
        isFalse,
      );
    });

    test('rejects invalid height and excessive chain-time differences', () {
      expect(
        () => BullVaultTimeReference(
          deviceTime: deviceTime,
          chainHeight: 0,
          medianTimePast: deviceTime.millisecondsSinceEpoch ~/ 1000,
        ),
        throwsArgumentError,
      );
      expect(
        () => BullVaultTimeReference(
          deviceTime: deviceTime,
          chainHeight: 3_000_000,
          medianTimePast:
              deviceTime
                  .subtract(const Duration(hours: 24, seconds: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        ),
        throwsArgumentError,
      );
    });
  });

  group('BullVaultRecord', () {
    test('requires metadata to match its recovery package', () {
      expect(
        () => BullVaultRecord(
          walletId: 'wallet-id',
          lineageId: 'different-lineage',
          vaultGeneration: 0,
          mobileAccount: 0,
          birthHeight: 3_000_000,
          recoveryPackage: testBullVaultRecoveryPackage(
            lineageId: 'lineage-id',
          ),
          createdAt: DateTime.utc(2027),
        ),
        throwsArgumentError,
      );
    });

    test('requires the stored mobile account to match the policy key', () {
      expect(
        () => BullVaultRecord(
          walletId: 'wallet-id',
          lineageId: 'lineage-id',
          vaultGeneration: 0,
          mobileAccount: 1,
          birthHeight: 3_000_000,
          recoveryPackage: testBullVaultRecoveryPackage(
            lineageId: 'lineage-id',
          ),
          createdAt: DateTime.utc(2027),
        ),
        throwsArgumentError,
      );
    });

    test('enforces predecessor and pending-successor invariants', () {
      expect(
        () => BullVaultRecord(
          walletId: 'wallet-id',
          lineageId: 'lineage-id',
          vaultGeneration: 0,
          mobileAccount: 0,
          birthHeight: 3_000_000,
          recoveryPackage: testBullVaultRecoveryPackage(
            lineageId: 'lineage-id',
          ),
          previousVaultId: 'previous-wallet',
          createdAt: DateTime.utc(2027),
        ),
        throwsArgumentError,
      );
      expect(
        () => BullVaultRecord(
          walletId: 'wallet-id',
          lineageId: 'lineage-id',
          vaultGeneration: 0,
          mobileAccount: 0,
          birthHeight: 3_000_000,
          recoveryPackage: testBullVaultRecoveryPackage(
            lineageId: 'lineage-id',
          ),
          successorWalletId: 'next-wallet',
          status: BullVaultLifecycleStatus.pending,
          createdAt: DateTime.utc(2027),
        ),
        throwsArgumentError,
      );
    });
  });

  test('previous vaults require a migration address', () {
    final current = testBullVaultCreateResult(
      walletId: 'current-wallet',
      status: BullVaultLifecycleStatus.active,
    );
    final previous = testBullVaultCreateResult(walletId: 'previous-wallet');

    expect(
      () => BullVaultDetails(
        record: current.record,
        policy: current.policy,
        timeUntilFirstRecovery: const Duration(days: 365),
        showEarlyRenewalWarning: false,
        migrationAddress: null,
        previousVaults: [
          BullVaultPreviousVault(
            record: previous.record,
            wallet: previous.wallet,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
