import 'dart:io';

import 'package:bb_mobile/wallet_inventory_setup.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/native.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:sync/storage.dart' show syncWalletMetadataImport;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/testing.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/storage.dart';

import 'package:secrets/testing.dart' show unlockedSessionAuthority;

final class InventoryFixture {
  final RuntimeAdmission admission;
  final SecretsInventory inventory;
  final SignerDevices? _signerDevices;
  final bool _ownsInventory;
  final backup = const VerifiedBackups();

  InventoryFixture._(
    this.admission,
    this.inventory,
    this._signerDevices, [
    this._ownsInventory = true,
  ]);

  SignerDevices? get signerDevices => _signerDevices;

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
    bool withSignerDevices = false,
  }) async {
    final file = File('${directory.path}/test-secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/test-secrets.gate'));
    final signerFile = File('${directory.path}/test-signers.sqlite');
    final signerKeys = withSignerDevices
        ? Secrets(
            authority: unlockedSessionAuthority(),
            scratchDirectory: () async => directory.path,
          ).databaseKeys(module: 'signers')
        : null;
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      for (final participant in [
        SecretsImport(file: file),
        if (signerKeys != null)
          signersWalletMetadataImport(file: signerFile, keys: signerKeys),
      ]) {
        final prepared = await participant.prepare(
          exclusive,
          OwnerOrigin.fresh,
        );
        final owner =
            (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
        try {
          if (await owner.initializeFresh() case Err()) {
            throw StateError('${participant.ownerId} initialization failed');
          }
        } finally {
          if (await owner.close() case Err()) {
            throw StateError('${participant.ownerId} owner close failed');
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
    SecretsInventory? inventory;
    try {
      final opened = await SecretsInventory.open(
        authority: SessionAuthority(),
        file: file,
        admission: admission,
        backupVerification: const VerifiedBackups(),
      );
      if (opened case Err()) throw StateError('Inventory open failed');
      inventory = (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
      SignerDevices? signerDevices;
      if (signerKeys != null) {
        final opened = await SignerDevices.open(
          file: signerFile,
          admission: admission,
          keys: signerKeys,
        );
        if (opened case Err()) throw StateError('Signer devices open failed');
        signerDevices =
            (opened as Ok<SignerDevices, SignerDeviceFailure>).value;
      }
      return InventoryFixture._(admission, inventory, signerDevices);
    } catch (_) {
      try {
        await inventory?.close();
      } finally {
        await admission.close();
      }
      rethrow;
    }
  }

  /// Composes the wallet owners the way production does: the storage cutover
  /// admits the owners, then `openWalletInventory` opens and registers the
  /// inventory, Signers, Sync freshness, both RecoverBull backups and the
  /// wallet projections in [services]. [services] owns the opened stores and
  /// closes them on reset; call [close] after the reset to release the
  /// admission.
  static Future<InventoryFixture> compose(
    Directory directory,
    GetIt services,
  ) async {
    File owner(String name) => File('${directory.path}/test-$name.sqlite');
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    final signerKeys = secrets.databaseKeys(module: 'signers');
    final syncKeys = secrets.databaseKeys(module: 'sync');
    final legacyFile = owner('legacy');
    final source = SqliteDatabase(NativeDatabase(legacyFile));
    try {
      await source.customStatement('SELECT 1');
    } finally {
      await source.close();
    }
    final legacy = LegacySourceStore(
      source: LegacySource(legacyFile, SqliteDatabase.currentSchemaVersion),
      create: SqliteDatabase.new,
    );
    final recoverBull = recoverBullCutoverForTesting(
      file: owner('recoverbull'),
      standalone: File('${directory.path}/test-recoverbull-standalone.sqlite'),
    );
    final regtestRecoverBull = recoverBullCutoverForTesting(
      file: owner('recoverbull-regtest'),
      standalone: File(
        '${directory.path}/test-recoverbull-regtest-standalone.sqlite',
      ),
      regtest: true,
    );
    final prepared = await StorageCutover(
      directory: Directory('${directory.path}/wallet-owner-coordination'),
      legacy: legacy,
      expectedOwners: const {
        'secrets',
        'signers',
        'sync',
        'recoverbull',
        'recoverbull_regtest',
      },
      participants: [
        recoverBull.participant,
        regtestRecoverBull.participant,
        SecretsImport(file: owner('secrets')),
        signersWalletMetadataImport(file: owner('signers'), keys: signerKeys),
        syncWalletMetadataImport(file: owner('sync'), keys: syncKeys),
      ],
    ).prepare();
    final admission = switch (prepared) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Cutover failed: ${failure.runtimeType}'),
    };
    // The composition's one authority, as production registers it: the
    // locator's `Secrets` follows the inventory's session.
    final authority = SessionAuthority();
    services.registerSingleton<SessionAuthority>(authority);
    final opened = await openWalletInventory(
      services,
      admission: admission,
      legacy: legacy.source,
      authority: authority,
      inventoryFile: owner('secrets'),
      signersFile: owner('signers'),
      syncFile: owner('sync'),
      signerKeys: signerKeys,
      syncKeys: syncKeys,
      recoverBull: recoverBull,
      regtestRecoverBull: regtestRecoverBull,
    );
    final inventory = switch (opened) {
      Ok(:final value) => value,
      Err(:final failure) => fail('Inventory failed: ${failure.runtimeType}'),
    };
    return InventoryFixture._(
      admission,
      inventory,
      services<SignerDevices>(),
      false,
    );
  }

  Future<void> registerMnemonic(
    Secret secret, {
    Network network = BitcoinNetwork.mainnet,
    String? unresolvedNetwork,
    String? internalDescriptor,
  }) async {
    final shared = network;
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
            ? walletIdForTesting(
                fingerprint: secret.id.hex,
                network: network,
                scriptType: ScriptType.bip84,
              )
            : 'invalid origin',
        secretFingerprint: secret.id.hex,
        masterFingerprint: secret.id.hex,
        signer: 'local',
        network: unresolvedNetwork ?? storedWalletNetworkForTesting(network),
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

  Future<void> close() async {
    try {
      if (_ownsInventory) await inventory.close();
    } finally {
      await admission.close();
    }
  }
}

final class VerifiedBackups implements InventoryBackupVerification {
  const VerifiedBackups();

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async => const Ok(BackupProof.verified);
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
