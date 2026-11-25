import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/storage.dart';

/// One open foreground session over a temporary inventory file.
final class FixtureSession {
  final SecretsInventory inventory;
  final RuntimeAdmission admission;

  FixtureSession._(this.inventory, this.admission);

  Future<void> close() async {
    await inventory.close();
    await admission.close();
  }
}

/// A real inventory on a temporary file: provisioning tests read the committed
/// catalog itself, not a projection of it.
final class InventoryFixture {
  final File file;
  final NativeFileGate gate;
  final FixtureSession session;

  InventoryFixture._(this.file, this.gate, this.session);

  SecretsInventory get inventory => session.inventory;

  /// Publishes a row without going through provisioning, for conflict cases.
  Future<void> addWallet(RegisteredWallet wallet) async {
    switch (await inventory.registerWallet(wallet)) {
      case Ok():
        return;
      case Err(:final failure):
        throw StateError('Fixture registration failed: $failure');
    }
  }

  /// A second foreground session on the same file, for independent writes.
  Future<FixtureSession> openSecond() async {
    final admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    switch (await SecretsInventory.open(file: file, admission: admission)) {
      case Ok(:final value):
        return FixtureSession._(value, admission);
      case Err(:final failure):
        await admission.close();
        throw StateError('Second inventory open failed: $failure');
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
      final prepared = await SecretsImport(file: file)
          .prepare(exclusive, OwnerOrigin.fresh);
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
      switch (await SecretsInventory.open(file: file, admission: admission)) {
        case Ok(:final value):
          return InventoryFixture._(
            file,
            gate,
            FixtureSession._(value, admission),
          );
        case Err(:final failure):
          throw StateError('Inventory open: $failure');
      }
    } catch (_) {
      await admission.close();
      rethrow;
    }
  }

  Future<void> close() => session.close();
}
