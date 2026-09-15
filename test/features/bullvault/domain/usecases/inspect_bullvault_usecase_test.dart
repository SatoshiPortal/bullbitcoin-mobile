import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../bullvault_test_fixture.dart';

class _Vaults extends Mock implements BullVaultRepository {}

class _Wallets extends Mock implements GetWalletUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Seeds extends Mock implements SeedVerificationPort {}

void main() {
  final created = testBullVaultCreateResult(includesInheritance: true);
  final key = created.record.recoveryPackage.policy.everydayKey.accountKey;
  final signer = WalletSigner(
    id: key.signerId,
    signer: SignerEntity.local,
    signerDevice: null,
    localSeedFingerprint: '12345678',
    descriptorKeys: [key],
  );
  late _Vaults vaults;
  late _Wallets wallets;
  late _Seeds seeds;
  late InspectBullVaultUsecase inspect;
  setUp(() {
    vaults = _Vaults();
    wallets = _Wallets();
    seeds = _Seeds();
    when(
      () => vaults.getByWalletId(created.wallet.id),
    ).thenAnswer((_) async => Ok(created.record));
    when(
      () => wallets.execute(created.wallet.id),
    ).thenAnswer((_) async => created.wallet.copyWith(signers: [signer]));
    inspect = InspectBullVaultUsecase(vaults, wallets, _Settings(), seeds);
  });
  Future<BullVaultInspection> result() async =>
      (await inspect.execute(created.wallet.id)
              as Ok<BullVaultInspection, BullVaultFailure>)
          .value;
  test(
    'only a full account-key match claims local signing availability',
    () async {
      when(
        () => seeds.matchesXpubs(
          fingerprint: '12345678',
          keys: any(named: 'keys'),
        ),
      ).thenAnswer((call) async {
        expect(call.namedArguments[#keys], [
          (derivationPath: key.derivationPath!, xpub: key.xpub),
        ]);
        return false;
      });
      expect(
        (await result()).keyAccess[key.id],
        BullVaultKeyAccess.unavailable,
      );
      when(
        () => seeds.matchesXpubs(
          fingerprint: '12345678',
          keys: any(named: 'keys'),
        ),
      ).thenAnswer((_) async => true);
      expect((await result()).keyAccess[key.id], BullVaultKeyAccess.available);
    },
  );
  test('a missing seed never prevents viewing the public policy', () async {
    when(
      () => seeds.matchesXpubs(
        fingerprint: '12345678',
        keys: any(named: 'keys'),
      ),
    ).thenThrow(Exception('unavailable'));
    final value = await result();
    expect(value.record, same(created.record));
    expect(value.keyAccess[key.id], BullVaultKeyAccess.unavailable);
  });
  test(
    'passphrased and external keys are never reported as ready from metadata',
    () async {
      when(() => wallets.execute(created.wallet.id)).thenAnswer(
        (_) async => created.wallet.copyWith(
          signers: [
            WalletSigner(
              id: key.signerId,
              signer: SignerEntity.local,
              signerDevice: null,
              localSeedFingerprint: '12345678',
              descriptorKeys: [key.copyWith(requiresPassphrase: true)],
            ),
          ],
        ),
      );
      expect(
        (await result()).keyAccess[key.id],
        BullVaultKeyAccess.passphraseRequired,
      );
      when(() => wallets.execute(created.wallet.id)).thenAnswer(
        (_) async => created.wallet.copyWith(
          signers: [
            WalletSigner(
              id: key.signerId,
              signer: SignerEntity.remote,
              signerDevice: null,
              descriptorKeys: [key],
            ),
          ],
        ),
      );
      expect((await result()).keyAccess[key.id], BullVaultKeyAccess.external);
      verifyZeroInteractions(seeds);
    },
  );
}
