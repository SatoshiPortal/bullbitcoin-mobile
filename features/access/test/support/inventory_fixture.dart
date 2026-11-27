import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

final class InventoryFixture {
  final Directory directory;
  final RuntimeAdmission admission;
  final SecretsInventory inventory;
  final FakeSecureStoragePlatform storage;
  final TestBackups backup;

  InventoryFixture._(
    this.directory,
    this.admission,
    this.inventory,
    this.storage,
    this.backup,
  );

  static Future<InventoryFixture> open({String? pin}) async {
    final directory = await Directory.systemTemp.createTemp(
      'access-inventory-',
    );
    final storage = FakeSecureStoragePlatform(
      entries: pin == null ? {} : {'securityKey': pin},
    )..install();
    final file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final owner = (await participant.prepare(
        exclusive,
        OwnerOrigin.fresh,
      ) as Ok<PreparedOwner, LegacyImportFailure>).value;
      final result = await owner.initializeFresh();
      if (result is Err) throw StateError('inventory initialization failed');
      if (await owner.close() case Err()) {
        throw StateError('inventory close failed');
      }
    } finally {
      await exclusive.close();
    }
    final admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    final backup = TestBackups();
    final opened = await SecretsInventory.open(
      authority: SessionAuthority(),
      file: file,
      admission: admission,
      backupVerification: backup,
    );
    final inventory =
        (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
    final fixture = InventoryFixture._(
      directory,
      admission,
      inventory,
      storage,
      backup,
    );
    if (pin != null) {
      final credential = await inventory.setCredential(pin);
      if (credential case Err()) {
        await fixture.close();
        throw StateError('inventory credential setup failed');
      }
      await inventory.lock();
    }
    return fixture;
  }

  Future<void> close() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  }
}

/// A backup owner the test controls: every secret is proven until
/// [verified] is cleared, and each read is counted.
final class TestBackups implements InventoryBackupVerification {
  bool verified = true;
  int reads = 0;

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async {
    reads++;
    return Ok(verified ? BackupProof.verified : BackupProof.missing);
  }
}

/// A wallet whose seed the inventory holds, so a view has a secret to prove.
RegisteredWallet localWallet() => const RegisteredWallet(
  id: 'wallet-a',
  secretFingerprint: '01234567',
  masterFingerprint: '01234567',
  signer: 'local',
  network: 'bitcoinMainnet',
  xpub: 'xpub-marker',
  externalDescriptor: 'external-marker',
  internalDescriptor: 'internal-marker',
  label: null,
  birthday: null,
  isDefault: false,
);
