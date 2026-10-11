import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../bullvault_test_fixture.dart';

void main() {
  final fixture = testBullVaultCreateResult();
  final policy = fixture.record.recoveryPackage.policy;
  WalletSigner signer(String id, BullVaultSignerKey source) => WalletSigner(
    id: id,
    signer: SignerEntity.local,
    signerDevice: null,
    localSeedFingerprint: 'seed',
    descriptorKeys: [source.accountKey.copyWith(id: '$id-key', signerId: id)],
  );
  test('a role follows the account key, not signer id or local metadata', () {
    final cold = signer('renamed', policy.coldKey);
    final inspection = BullVaultInspection(
      fixture.record,
      fixture.wallet.copyWith(signers: [cold]),
      {'renamed-key': .unavailable},
    );
    expect(inspection.rolesForSigner(cold), {BullVaultSignerRole.cold});
    expect(inspection.accessForSigner(cold), BullVaultKeyAccess.unavailable);
    final key = BitcoinPolicyKey(kind: .descriptorKey, value: 'renamed-key');
    expect(inspection.signerForKey(key), same(cold));
  });
  test('an ambiguous fingerprint cannot identify a signer or claim access', () {
    final first = signer('first', policy.everydayKey);
    final second = WalletSigner(
      id: 'second',
      signer: .remote,
      signerDevice: null,
      descriptorKeys: [
        policy.coldKey.accountKey.copyWith(
          id: 'second-key',
          signerId: 'second',
          masterFingerprint: first.displayFingerprint,
        ),
      ],
    );
    final inspection = BullVaultInspection(
      fixture.record,
      fixture.wallet.copyWith(signers: [first, second]),
      {'first-key': .available, 'second-key': .external},
    );
    expect(
      inspection.signerForKey(
        BitcoinPolicyKey(kind: .fingerprint, value: first.displayFingerprint),
      ),
      isNull,
    );
  });
  test(
    'partial and missing verification never make a whole signer available',
    () {
      final first = policy.everydayKey.accountKey.copyWith(
        id: 'first',
        signerId: 'combined',
      );
      final second = policy.coldKey.accountKey.copyWith(
        id: 'second',
        signerId: 'combined',
      );
      final combined = WalletSigner(
        id: 'combined',
        signer: .local,
        signerDevice: null,
        localSeedFingerprint: 'seed',
        descriptorKeys: [first, second],
      );
      BullVaultInspection inspection(Map<String, BullVaultKeyAccess> access) =>
          BullVaultInspection(
            fixture.record,
            fixture.wallet.copyWith(signers: [combined]),
            access,
          );
      expect(
        inspection({'first': .available}).accessForSigner(combined),
        BullVaultKeyAccess.unavailable,
      );
      final protected = inspection({
        'first': .available,
        'second': .passphraseRequired,
      });
      expect(
        protected.accessForSigner(combined),
        BullVaultKeyAccess.passphraseRequired,
      );
      expect(
        protected.accessForSigner(
          combined,
          policyKey: BitcoinPolicyKey(kind: .descriptorKey, value: 'first'),
        ),
        BullVaultKeyAccess.available,
      );
      expect(
        protected.accessForSigner(
          combined,
          policyKey: BitcoinPolicyKey(kind: .descriptorKey, value: 'absent'),
        ),
        BullVaultKeyAccess.unavailable,
      );
    },
  );
}
