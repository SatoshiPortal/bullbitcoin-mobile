import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:signers/storage.dart';
import 'package:secrets/testing.dart' show unlockedSessionAuthority;

/// A real inventory and its signer-device store, opened the way the app opens
/// them: fresh owner databases behind an admitted native file gate.
///
/// Wallet details read, delete and refuse through these stores. The fail-closed
/// rules under test live in the inventory, so a double would only re-assert
/// the test's own assumptions; a fake here would test the fake.
final class InventoryFixture {
  final Directory directory;
  final RuntimeAdmission admission;
  final SecretsInventory inventory;
  final SignerDevices devices;

  InventoryFixture._(
    this.directory,
    this.admission,
    this.inventory,
    this.devices,
  );

  /// A [FakeSecureStoragePlatform] must be installed before opening: the
  /// signer-device module derives its database key from the keystore.
  static Future<InventoryFixture> open() async {
    final directory = await Directory.systemTemp.createTemp('wallet-details-');
    final secretsFile = File('${directory.path}/secrets.sqlite');
    final signersFile = File('${directory.path}/signers.sqlite');
    final keys = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    ).databaseKeys(module: 'signers');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      for (final participant in [
        SecretsImport(file: secretsFile),
        signersWalletMetadataImport(file: signersFile, keys: keys),
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
          (await SecretsInventory.open(
            authority: SessionAuthority(),
            file: secretsFile,
            admission: admission,
          )).fold(
            (value) => value,
            (_) => throw StateError('Inventory open failed'),
          );
      final devices =
          (await SignerDevices.open(
            file: signersFile,
            admission: admission,
            keys: keys,
          )).fold(
            (value) => value,
            (_) => throw StateError('Signer devices open failed'),
          );
      return InventoryFixture._(directory, admission, inventory, devices);
    } catch (_) {
      await admission.close();
      rethrow;
    }
  }

  /// Registers [wallet], and records [device] for it when given. Registration
  /// failures are test bugs, not conditions under test.
  Future<void> register(RegisteredWallet wallet, {SignerDevice? device}) async {
    final registered = await inventory.registerWallet(wallet);
    if (registered case Err(:final failure)) {
      throw StateError('Wallet registration failed: ${failure.runtimeType}');
    }
    if (device == null) return;
    final written = await devices.write(wallet.id, device);
    if (written case Err(:final failure)) {
      throw StateError('Signer device write failed: ${failure.runtimeType}');
    }
  }

  Future<void> close() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  }
}

/// A registered wallet row. Bitcoin only: the identity string must spell its
/// script type as `<84h|49h|44h>` for the inventory to decode it, and carry
/// `:regtest` exactly on regtest. A local row's seed reference must equal its
/// master fingerprint, as the real import writes it.
RegisteredWallet walletRow({
  required String id,
  required String masterFingerprint,
  String? secretFingerprint,
  String signer = 'none',
  String network = 'bitcoinMainnet',
  String xpub = 'xpub-marker',
  int purpose = 84,
  String? externalDescriptor,
  String? internalDescriptor,
  String? label,
  bool isDefault = false,
}) => RegisteredWallet(
  id: id,
  secretFingerprint: secretFingerprint,
  masterFingerprint: masterFingerprint,
  signer: signer,
  network: network,
  xpub: xpub,
  externalDescriptor:
      externalDescriptor ??
      "wpkh([$masterFingerprint/${purpose}h/0h/0h]$xpub/0/*)",
  internalDescriptor: internalDescriptor ?? "wpkh($xpub/1/*)",
  label: label,
  birthday: null,
  isDefault: isDefault,
);

/// The identity of a wallet derived from [fingerprint], for [purpose] (84, 49
/// or 44). The path in the identity is what the inventory reads its script
/// type from; the account path here is mainnet's for readability only.
String walletIdFor(String fingerprint, {int purpose = 84}) =>
    'wpkh([$fingerprint/${purpose}h/0h/0h])';
