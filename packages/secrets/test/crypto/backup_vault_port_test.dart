import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/backup_vault_adapter.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_lifecycle_adapter.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import '../data/fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

class _FakeSeedIndex implements SecretIndexPort {
  final Map<String, SecretInfo> _m = {};
  @override
  Future<List<SecretInfo>> all() async => _m.values.toList();
  @override
  Future<SecretInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SecretInfo info) async => _m[info.fingerprint.hex] = info;
}

T _unwrap<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

void main() {
  late FssSecretStoreAdapter store;
  late SecretLifecycleAdapter repo;
  late BackupVaultAdapter vaultPort;
  late Fingerprint zooFp;

  setUp(() async {
    final kv = FakeSecureKeyValueStore();
    store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
    repo = SecretLifecycleAdapter(store: store, index: _FakeSeedIndex());
    zooFp = _unwrap(await repo.importMnemonic(words: zooWords));
    vaultPort = BackupVaultAdapter(store: store, repository: repo);
  });

  // A caller-supplied key — encryptVault no longer mints one. A random 32-byte
  // key round-trips; real callers derive it via bip85RecoverbullKey / the key
  // server and store it APART from the ciphertext.
  VaultKey freshKey() {
    final rnd = Random.secure();
    return VaultKey(
        Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256))));
  }

  test('encrypt returns ONLY the ciphertext (no key co-returned)', () async {
    final vault = _unwrap(
        await vaultPort.encryptVault(fingerprint: zooFp, vaultKey: freshKey()));
    // The return type is the bare EncryptedVault — the key is never handed back.
    expect(vault, isA<EncryptedVault>());
  });

  test('encrypt → restore round-trips to the same fingerprint', () async {
    final key = freshKey();
    final vault =
        _unwrap(await vaultPort.encryptVault(fingerprint: zooFp, vaultKey: key));

    // Wipe the seed so restore must re-import it from the vault.
    await repo.delete(zooFp);
    expect(_unwrap(await repo.exists(zooFp)), isFalse);

    final fps = _unwrap(await vaultPort.restoreVault(vault: vault, vaultKey: key));
    expect(fps, [zooFp]);
    expect(_unwrap(await repo.exists(zooFp)), isTrue);
  });

  test('restore with a wrong key → VaultFailure (no crash)', () async {
    final vault =
        _unwrap(await vaultPort.encryptVault(fingerprint: zooFp, vaultKey: freshKey()));
    final res = await vaultPort.restoreVault(
      vault: vault,
      vaultKey: VaultKey(Uint8List.fromList(List.filled(32, 0))),
    );
    expect((res as Err).failure, isA<VaultFailure>());
  });

  test('restore of a TAMPERED ciphertext → VaultFailure (HMAC rejects)',
      () async {
    final key = freshKey();
    final vault =
        _unwrap(await vaultPort.encryptVault(fingerprint: zooFp, vaultKey: key));
    // Flip one byte inside the authenticated (nonce‖ciphertext‖HMAC) blob, then
    // re-wrap as valid JSON so the failure is the MAC check — not a parse error
    // — proving the vault authenticates ciphertext (encrypt-then-MAC), distinct
    // from the wrong-key case above.
    final map = jsonDecode(vault.ciphertextJson) as Map<String, dynamic>;
    final blob = base64.decode(map['ciphertext'] as String);
    blob[blob.length ~/ 2] ^= 0xFF; // mutate a middle (ciphertext) byte
    map['ciphertext'] = base64.encode(blob);
    final tampered = EncryptedVault(jsonEncode(map));

    await repo.delete(zooFp); // restore must actually decrypt, not short-circuit
    final res = await vaultPort.restoreVault(
      vault: tampered,
      vaultKey: key, // CORRECT key — only the ciphertext is tampered
    );
    expect((res as Err).failure, isA<VaultFailure>());
    // The rejected vault imported nothing.
    expect(_unwrap(await repo.exists(zooFp)), isFalse);
  });

  test('encrypt of a missing seed → SecretNotFoundFailure', () async {
    final res = await vaultPort.encryptVault(
        fingerprint: Fingerprint('00000000'), vaultKey: freshKey());
    expect((res as Err).failure, isA<SecretNotFoundFailure>());
  });

  test('restore of an ALREADY-PRESENT seed → Ok (duplicate is benign)',
      () async {
    // The seed is still stored (not deleted). Restore decrypts to the SAME
    // words → SAME fingerprint; the import hits DuplicateSecretFailure, which
    // restoreVault deliberately rewrites to Ok([fp]) — the ONLY Err→Ok in the
    // package. Pin that it is FINGERPRINT IDENTITY (content-derived) that proves
    // equivalence, so the rewrite can never mask a different seed.
    final key = freshKey();
    final vault =
        _unwrap(await vaultPort.encryptVault(fingerprint: zooFp, vaultKey: key));
    expect(_unwrap(await repo.exists(zooFp)), isTrue); // NOT deleted

    final fps = _unwrap(await vaultPort.restoreVault(vault: vault, vaultKey: key));
    expect(fps, [zooFp]); // the duplicate resolved to the existing fingerprint
  });
}
