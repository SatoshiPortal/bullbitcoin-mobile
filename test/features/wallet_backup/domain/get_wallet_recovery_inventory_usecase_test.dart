import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_recovery_inventory_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  final fingerprint = Fingerprint('aabbccdd');
  final manifest = KeychainManifest(
    parentFingerprint: fingerprint,
    generatedAt: 1,
    entries: const [],
  );

  test('refreshes seed-derived facts before returning the inventory', () async {
    final calls = <String>[];
    final usecase = GetWalletRecoveryInventoryUsecase(
      () async {
        calls.add('resolve');
        return Ok((
          parentFingerprint: fingerprint.hex,
          encryptionKey: WalletBackupEncryptionKey('00' * 32),
        ));
      },
      (parent) async {
        expect(parent, fingerprint);
        calls.add('refresh');
        return const Ok(null);
      },
      (parent) async {
        expect(parent, fingerprint);
        calls.add('read');
        return Ok(manifest);
      },
    );

    expect(
      await usecase.execute(),
      isA<Ok<KeychainManifest, WalletBackupFailure>>().having(
        (result) => result.value,
        'value',
        manifest,
      ),
    );
    expect(calls, ['resolve', 'refresh', 'read']);
  });

  test('does not read stale inventory when refresh fails', () async {
    var read = false;
    final usecase = GetWalletRecoveryInventoryUsecase(
      () async => Ok((
        parentFingerprint: fingerprint.hex,
        encryptionKey: WalletBackupEncryptionKey('00' * 32),
      )),
      (_) async => const Err(WalletBackupStorageFailure()),
      (_) async {
        read = true;
        return Ok(manifest);
      },
    );

    expect(await usecase.execute(), isA<Err>());
    expect(read, isFalse);
  });
}
