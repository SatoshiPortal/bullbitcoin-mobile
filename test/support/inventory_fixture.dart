import 'dart:io';

import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

import 'wallet_registrations.dart';

final class InventoryFixture {
  final RuntimeAdmission admission;
  final SecretsInventory inventory;
  final backup = const VerifiedBackups();

  InventoryFixture._(this.admission, this.inventory);

  static Future<InventoryFixture> open(Directory directory) async {
    final file = File('${directory.path}/test-secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/test-secrets.gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final prepared = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
      if (await owner.initializeFresh() case Err()) {
        throw StateError('Inventory initialization failed');
      }
      if (await owner.close() case Err()) {
        throw StateError('Inventory owner close failed');
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
    if (opened case Err()) {
      await admission.close();
      throw StateError('Inventory open failed');
    }
    final inventory =
        (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
    return InventoryFixture._(admission, inventory);
  }

  Future<void> registerMnemonic(
    Secret secret, {
    Network network = Network.bitcoinMainnet,
    String? unresolvedNetwork,
    String? internalDescriptor,
  }) async {
    final metadata = await WalletMetadataService.deriveFromSecret(
      secret: secret,
      network: network,
      scriptType: ScriptType.bip84,
      isDefault: false,
    );
    final registered = await inventory.registerWallet(
      RegisteredWallet(
        id: unresolvedNetwork == null ? metadata.id : 'invalid origin',
        secretFingerprint: secret.id.hex,
        masterFingerprint: metadata.masterFingerprint,
        signer: 'local',
        network: unresolvedNetwork ?? metadata.networkCode,
        xpub: metadata.xpub,
        externalDescriptor: metadata.externalPublicDescriptor,
        internalDescriptor:
            internalDescriptor ?? metadata.internalPublicDescriptor,
        label: metadata.label,
        birthday: null,
        isDefault: false,
      ),
    );
    expect(registered, isA<Ok<void, SecretFailure>>());
  }

  void register(GetIt services) {
    services.registerSingleton<SecretsInventory>(inventory);
    services.registerSingleton<InventoryBackupVerification>(backup);
    services.registerSingleton<WalletRegistrations>(
      MemoryWalletRegistrations(),
    );
  }

  Future<void> close() async {
    await inventory.close();
    await admission.close();
  }
}

final class VerifiedBackups implements InventoryBackupVerification {
  const VerifiedBackups();

  @override
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    List<WalletRegistration> defaults,
  ) async => const Ok(true);
}

/// Lets the database isolate and the widget test's fake clock advance together.
Future<void> pumpUntilInventoryReady(
  WidgetTester tester,
  bool Function() ready,
) async {
  final clock = Stopwatch()..start();
  while (!ready() && clock.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}
