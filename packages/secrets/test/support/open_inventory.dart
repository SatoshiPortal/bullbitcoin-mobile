import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

/// A fresh unprotected inventory in [directory], for one test.
Future<
  ({
    SecretsInventory inventory,
    RuntimeAdmission admission,
    SessionAuthority authority,
  })
>
openFreshInventory(Directory directory) async {
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
  final authority = SessionAuthority();
  final opened = await SecretsInventory.open(
    file: file,
    admission: admission,
    authority: authority,
  );
  return (
    inventory: valueOf(opened),
    admission: admission,
    authority: authority,
  );
}

T valueOf<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}

/// A public watch-only Bitcoin account: no seed reference, public descriptors.
RegisteredWallet watchOnlyWallet(
  String id, {
  String network = 'bitcoinTestnet',
  String external = "wpkh([01234567/84'/1'/0']tpubMarker/0/*)",
  String internal = "wpkh([01234567/84'/1'/0']tpubMarker/1/*)",
  String? label,
  String? birthday,
  bool isDefault = false,
  String signer = 'remote',
}) => RegisteredWallet(
  id: id,
  secretFingerprint: null,
  masterFingerprint: '01234567',
  signer: signer,
  network: network,
  xpub: 'tpubMarker',
  externalDescriptor: external,
  internalDescriptor: internal,
  label: label,
  birthday: birthday,
  isDefault: isDefault,
);

/// A signing wallet of the seed [parent], enough to authorize its derivations.
RegisteredWallet localWallet(String id, String parent) => RegisteredWallet(
  id: id,
  secretFingerprint: parent,
  masterFingerprint: parent,
  signer: 'local',
  network: 'bitcoinMainnet',
  xpub: 'xpub-marker',
  externalDescriptor: 'external-marker',
  internalDescriptor: 'internal-marker',
  label: null,
  birthday: null,
  isDefault: false,
);
