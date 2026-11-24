import 'dart:io';

import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
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
import 'package:signers/storage.dart';

import 'wallet_registrations.dart';

final class InventoryFixture {
  final RuntimeAdmission admission;
  final SecretsInventory inventory;
  final SignerDevices? signerDevices;
  final backup = const VerifiedBackups();

  InventoryFixture._(this.admission, this.inventory, this.signerDevices);

  Future<void> addPublicWallet({
    required String id,
    required String network,
  }) async {
    final liquid = network.startsWith('liquid');
    expect(
      await inventory.registerWallet(
        RegisteredWallet(
          id: id,
          network: network,
          masterFingerprint: '',
          secretFingerprint: null,
          signer: 'none',
          xpub: 'public-key-marker',
          externalDescriptor: liquid
              ? "ct(slip77(public),elwpkh([01234567/84'/1776'/7']public-key-marker/0/*))"
              : "wpkh([01234567/84'/1'/7']public-key-marker/0/*)",
          internalDescriptor: liquid ? '' : 'wpkh(public-key-marker/1/*)',
          label: '',
          birthday: null,
          isDefault: false,
        ),
      ),
      isA<Ok<void, SecretFailure>>(),
    );
  }

  static Future<InventoryFixture> open(
    Directory directory, {
    bool includeSignerDevices = false,
  }) async {
    final file = File('${directory.path}/test-secrets.sqlite');
    final signersFile = File('${directory.path}/test-signers.sqlite');
    final signerKeys = Secrets(scratchDirectory: () async => directory.path)
        .databaseKeys(module: 'signers');
    final gate = NativeFileGate(File('${directory.path}/test-secrets.gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      for (final participant in [
        SecretsImport(file: file),
        if (includeSignerDevices)
          signersWalletMetadataImport(file: signersFile, keys: signerKeys),
      ]) {
        final prepared = await participant.prepare(
          exclusive,
          OwnerOrigin.fresh,
        );
        final owner =
            (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
        try {
          if (await owner.initializeFresh() case Err()) {
            throw StateError('Inventory fixture initialization failed');
          }
        } finally {
          if (await owner.close() case Err()) {
            throw StateError('Inventory fixture owner close failed');
          }
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
      final inventory =
          (await SecretsInventory.open(file: file, admission: admission)).fold(
            (value) => value,
            (_) => throw StateError('Inventory open failed'),
          );
      final signers = includeSignerDevices
          ? (await SignerDevices.open(
              file: signersFile,
              admission: admission,
              keys: signerKeys,
            )).fold(
              (value) => value,
              (_) => throw StateError('Signer devices open failed'),
            )
          : null;
      return InventoryFixture._(admission, inventory, signers);
    } catch (_) {
      await admission.close();
      rethrow;
    }
  }

  Future<void> registerMnemonic(
    Secret secret, {
    Network network = Network.bitcoinMainnet,
    String? unresolvedNetwork,
    String? internalDescriptor,
  }) async {
    final shared = network.shared;
    final xpub = switch (await secret.derive.xpub(
      network: shared,
      scriptType: ScriptType.bip84,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('xpub: ${failure.runtimeType}'),
    };
    final ({String external, String internal}) descriptors;
    switch (shared) {
      case BitcoinNetwork():
        descriptors = switch (await secret.derive.descriptors.bitcoin(
          network: shared,
          scriptType: ScriptType.bip84,
        )) {
          Ok(:final value) => (
            external: value.external,
            internal: value.internal,
          ),
          Err(:final failure) => fail('descriptors: ${failure.runtimeType}'),
        };
      case LiquidNetwork():
        final descriptor = switch (await secret.derive.descriptors.liquid(
          network: shared,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => fail('descriptor: ${failure.runtimeType}'),
        };
        descriptors = (external: descriptor, internal: descriptor);
    }
    final registered = await inventory.registerWallet(
      RegisteredWallet(
        id: unresolvedNetwork == null
            ? WalletMetadataService.encodeId(
                fingerprint: secret.id.hex,
                network: network,
                scriptType: ScriptType.bip84,
              )
            : 'invalid origin',
        secretFingerprint: secret.id.hex,
        masterFingerprint: secret.id.hex,
        signer: 'local',
        network: unresolvedNetwork ?? WalletNetworkCodec.encode(network),
        xpub: xpub,
        externalDescriptor: descriptors.external,
        internalDescriptor: internalDescriptor ?? descriptors.internal,
        label: null,
        birthday: null,
        isDefault: false,
      ),
    );
    expect(registered, isA<Ok<void, SecretFailure>>());
  }

  void register(GetIt services) {
    services.registerSingleton<SecretsInventory>(inventory);
    if (signerDevices case final devices?) services.registerSingleton(devices);
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
