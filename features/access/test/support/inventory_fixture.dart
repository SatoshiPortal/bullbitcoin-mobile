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
  final backup = const VerifiedBackups();

  InventoryFixture._(
    this.directory,
    this.admission,
    this.inventory,
    this.storage,
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
    final opened = await SecretsInventory.open(
      file: file,
      admission: admission,
    );
    final inventory =
        (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
    return InventoryFixture._(directory, admission, inventory, storage);
  }

  Future<void> close() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  }
}

final class VerifiedBackups implements InventoryBackupVerification {
  const VerifiedBackups();

  @override
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    Set<String> secretFingerprints,
  ) async => const Ok(true);
}
