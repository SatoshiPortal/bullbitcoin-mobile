import 'dart:convert';
import 'dart:io';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'backup_credential_vectors.dart';

Future<Secret> backupSecretFixture() async {
  final id = Fingerprint(
    hex.encode(
      bip32.Bip32Keys.fromSeed(backupCredentialVectorSeed).fingerprint,
    ),
  );
  FakeSecureStoragePlatform(
    entries: {
      'seed_${id.hex}': jsonEncode({
        'bytes': backupCredentialVectorSeed.toList(),
        'runtimeType': 'bytes',
      }),
    },
  ).install();
  final secrets = Secrets(
    scratchDirectory: () async => Directory.systemTemp.path,
  );
  return (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;
}
