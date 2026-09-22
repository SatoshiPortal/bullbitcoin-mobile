import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault_test_fixture.dart';

class _Records extends Fake implements BullVaultRepository {
  final BullVaultRecord? record;
  final ids = <String>[];
  _Records(this.record);
  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String id,
  ) async {
    ids.add(id);
    return Ok(record);
  }
}

class _Wallets extends Fake implements GetWalletUsecase {
  final Wallet wallet;
  final ids = <String>[];
  _Wallets(this.wallet);
  @override
  Future<Wallet?> execute(String id, {bool sync = false}) async {
    ids.add(id);
    return wallet;
  }
}

class _Seeds extends Fake implements SeedVerificationPort {
  bool locked = false;
  final calls =
      <
        ({
          String fingerprint,
          List<({String derivationPath, String xpub})> keys,
        })
      >[];
  @override
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  }) async {
    calls.add((fingerprint: fingerprint, keys: keys));
    if (locked) throw Exception('private storage locked');
    return keys.every((key) => key.xpub == 'matching-public-key');
  }
}

WalletDescriptorKey _key(
  String id, {
  String signer = 'local',
  bool protected = false,
  String? path = "m/48'/0'/0'/2'",
  String xpub = 'matching-public-key',
}) => WalletDescriptorKey(
  id: id,
  signerId: signer,
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'cafebabe',
  xpub: xpub,
  derivationPath: path,
  descriptorPath: '/<0;1>/*',
  requiresPassphrase: protected,
);
void main() {
  test(
    'inspects the selected historical record and proves each available key through its owner',
    () async {
      final fixture = testBullVaultCreateResult(
        walletId: 'historical',
        status: .migrating,
      );
      final local = WalletSigner(
        id: 'local',
        signer: SignerEntity.local,
        signerDevice: null,
        localSeedFingerprint: 'stored-seed',
        descriptorKeys: [
          _key('available'),
          _key('mismatch', xpub: 'different-public-key'),
          _key('protected', protected: true),
          _key('unknown-path', path: null),
        ],
      );
      final external = WalletSigner(
        id: 'external',
        signer: SignerEntity.remote,
        signerDevice: null,
        descriptorKeys: [_key('external', signer: 'external')],
      );
      final records = _Records(fixture.record);
      final wallets = _Wallets(
        fixture.wallet.copyWith(signers: [local, external]),
      );
      final seeds = _Seeds();
      final result = await InspectBullVaultUsecase(
        records,
        wallets,
        seeds,
      ).execute('historical');
      final inspection =
          (result as Ok<BullVaultInspection, BullVaultFailure>).value;
      expect(inspection.record, same(fixture.record));
      expect(inspection.wallet, same(wallets.wallet));
      expect(inspection.keyAccess, {
        'available': BullVaultKeyAccess.available,
        'mismatch': BullVaultKeyAccess.unavailable,
        'protected': BullVaultKeyAccess.passphraseRequired,
        'unknown-path': BullVaultKeyAccess.unavailable,
        'external': BullVaultKeyAccess.external,
      });
      expect(records.ids, ['historical']);
      expect(wallets.ids, ['historical']);
      expect(seeds.calls.length, 2);
      expect(
        seeds.calls.every((call) => call.fingerprint == 'stored-seed'),
        isTrue,
      );
    },
  );
  test(
    'locked or missing private storage leaves public policy and keys inspectable',
    () async {
      final fixture = testBullVaultCreateResult();
      final wallet = fixture.wallet.copyWith(
        signers: [
          WalletSigner(
            id: 'local',
            signer: SignerEntity.local,
            signerDevice: null,
            localSeedFingerprint: 'stored-seed',
            descriptorKeys: [_key('available')],
          ),
        ],
      );
      final seeds = _Seeds()..locked = true;
      final result = await InspectBullVaultUsecase(
        _Records(fixture.record),
        _Wallets(wallet),
        seeds,
      ).execute(fixture.record.walletId);
      final inspection =
          (result as Ok<BullVaultInspection, BullVaultFailure>).value;
      expect(inspection.keyAccess['available'], BullVaultKeyAccess.unavailable);
      expect(
        inspection.record.recoveryPackage,
        same(fixture.record.recoveryPackage),
      );
      expect(inspection.wallet.signers, wallet.signers);
    },
  );
  test(
    'an unknown selected vault does not become the active or default vault',
    () async {
      final wallets = _Wallets(testBullVaultCreateResult().wallet);
      expect(
        await InspectBullVaultUsecase(
          _Records(null),
          wallets,
          _Seeds(),
        ).execute('unknown'),
        isA<Err>(),
      );
      expect(wallets.ids, isEmpty);
    },
  );
}
