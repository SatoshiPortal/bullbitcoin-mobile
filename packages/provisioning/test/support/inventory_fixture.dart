import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

/// A real `SecretsInventory` on a temporary file: provisioning tests read the
/// committed catalog, not a projection of it.
final class InventoryFixture {
  final RuntimeAdmission admission;
  final SecretsInventory inventory;

  InventoryFixture._(this.admission, this.inventory);

  Future<void> addWallet(RegisteredWallet wallet) async {
    final registered = await inventory.registerWallet(wallet);
    if (registered case Err(:final failure)) {
      throw StateError('Fixture registration failed: $failure');
    }
  }

  static Future<InventoryFixture> open(Directory directory) async {
    final file = File('${directory.path}/test-secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/test-secrets.gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final prepared = await SecretsImport(file: file).prepare(
        exclusive,
        OwnerOrigin.fresh,
      );
      final owner = switch (prepared) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('Fixture prepare: $failure'),
      };
      try {
        if (await owner.initializeFresh() case Err()) {
          throw StateError('Fixture initialization failed');
        }
      } finally {
        if (await owner.close() case Err()) {
          throw StateError('Fixture owner close failed');
        }
      }
    } finally {
      await exclusive.close();
    }
    final admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    try {
      final inventory = switch (await SecretsInventory.open(
        file: file,
        admission: admission,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('Inventory open: $failure'),
      };
      return InventoryFixture._(admission, inventory);
    } catch (_) {
      await admission.close();
      rethrow;
    }
  }

  Future<void> openSecondView(InventoryFixture _) async {}

  Future<void> close() async {
    await inventory.close();
    await admission.close();
  }
}
