import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

/// One simulated phone: a real unprotected Secrets inventory in [directory].
final class Phone {
  final Directory directory;
  final SecretsInventory inventory;
  final RuntimeAdmission admission;
  final Secrets secrets;

  Phone._(this.directory, this.inventory, this.admission, this.secrets);

  String get journalPath => '${directory.path}/backup-metadata.sqlite';

  static Future<Phone> open(Directory directory) async {
    FakeSecureStoragePlatform().install();
    final file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final result = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    final admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    final inventory = valueOf(
      await SecretsInventory.open(file: file, admission: admission),
    );
    return Phone._(
      directory,
      inventory,
      admission,
      Secrets(scratchDirectory: () async => directory.path),
    );
  }

  Future<void> close() async {
    await inventory.close();
    await admission.close();
  }
}

T valueOf<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
