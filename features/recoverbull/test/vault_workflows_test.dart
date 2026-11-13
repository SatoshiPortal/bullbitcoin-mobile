import 'dart:async';
import 'dart:convert';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  // Published BIP39 vector, never a user's wallet.
  final words = '${'abandon ' * 11}about'.split(' ');
  late FakeSecureStoragePlatform storage;
  late custody.Secrets secrets;
  late SecretsVaultRepository repository;
  late _Wallets wallets;
  late RecoverBullFacade facade;
  final context = VaultContext(
    fingerprint: Fingerprint('73c5da0a'),
    network: BitcoinNetwork.testnet,
  );

  setUp(() async {
    storage = FakeSecureStoragePlatform().install();
    secrets = custody.Secrets(scratchDirectory: () async => '.');
    _ok(await secrets.import(words: words));
    repository = SecretsVaultRepository(secrets);
    wallets = _Wallets(context);
    facade = RecoverBullFeature.create(
      secrets: secrets,
      wallets: wallets,
    ).facade;
  });

  test(
    'create and test retain the captured network without importing',
    () async {
      final backup = _ok(await facade.create());
      final before = Map.of(storage.entries);
      final reads = storage.reads;
      final checked = _ok(
        await facade.test(vault: backup.vault, key: backup.key),
      );
      expect(checked.matches(context), isTrue);
      expect(backup.context.matches(context), isTrue);
      expect(storage.entries, before);
      expect(
        storage.reads,
        reads,
        reason: 'inspection never reads the keystore',
      );
      expect(wallets.restores, 0);
      expect(repository.encode(backup.vault), isNot(contains('abandon')));
      expect(backup.toString(), isNot(contains(backup.key.hex)));
    },
  );

  test('untrusted metadata cannot certify a different wallet', () async {
    final secret = _ok(await secrets.fetch(context.fingerprint));
    final sealed = _ok(
      await secret.backup.recoverbull(
        metadata: {
          'masterFingerprint': 'ffffffff',
          'isEncryptedVaultTested': true,
        },
      ),
    );
    final vault = _ok(repository.parse(sealed.vault.json));
    wallets.current = VaultContext(
      fingerprint: Fingerprint('ffffffff'),
      network: BitcoinNetwork.testnet,
    );
    expect(
      await facade.test(vault: vault, key: sealed.key),
      isA<Err<VaultContext, RecoverBullFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<VaultWalletMismatchFailure>(),
      ),
    );
  });

  test('malformed files and wrong keys return sanitized failures', () async {
    final backup = _ok(await facade.create());
    for (final file in ['not json', '[]', '{"id":"sensitive input"}']) {
      expect(
        repository.parse(file),
        isA<Err<EncryptedVault, RecoverBullFailure>>(),
      );
    }
    final before = Map.of(storage.entries);
    final result = await repository.restore(backup.vault, VaultKey('00' * 32));
    expect(
      result,
      isA<Err<Fingerprint, RecoverBullFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<VaultInvalidFailure>(),
      ),
    );
    expect(storage.entries, before);
  });

  test('legacy unversioned files remain inspectable', () async {
    final backup = _ok(await facade.create());
    final file =
        jsonDecode(repository.encode(backup.vault)) as Map<String, dynamic>;
    file.remove('version');
    file['path'] = 'm/${file['path']}';
    final parsed = _ok(repository.parse(jsonEncode(file)));
    expect(
      _ok(await repository.fingerprint(parsed, backup.key)),
      context.fingerprint,
    );
  });

  test('locked, missing and corrupt custody remain distinct', () async {
    storage.locked = true;
    expect(
      await facade.create(),
      isA<Err<VaultBackup, RecoverBullFailure>>().having(
        (r) => r.failure,
        'locked',
        isA<VaultKeystoreLockedFailure>(),
      ),
    );
    storage.locked = false;
    storage.entries.clear();
    expect(
      await facade.create(),
      isA<Err<VaultBackup, RecoverBullFailure>>().having(
        (r) => r.failure,
        'missing',
        isA<VaultSecretMissingFailure>(),
      ),
    );
    storage.entries['seed_73c5da0a'] = 'invalid';
    expect(
      await facade.create(),
      isA<Err<VaultBackup, RecoverBullFailure>>().having(
        (r) => r.failure,
        'corrupt',
        isA<VaultStorageFailure>(),
      ),
    );
  });

  test('cancellation before import makes no keystore change', () async {
    final backup = _ok(await facade.create());
    storage.entries.clear();
    final result = await facade.restore(
      vault: backup.vault,
      key: backup.key,
      network: context.network,
      cancelled: () => true,
    );
    expect(result, isA<Err<VaultRecovery, RecoverBullFailure>>());
    expect(storage.entries, isEmpty);
    expect(wallets.restores, 0);
  });

  test(
    'cancellation after import does not erase its committed result',
    () async {
      final backup = _ok(await facade.create());
      storage.entries.clear();
      final pending = Completer<Result<VaultContext, RecoverBullFailure>>();
      wallets.pending = pending.future;
      var cancelled = false;
      final recovery = facade.restore(
        vault: backup.vault,
        key: backup.key,
        network: context.network,
        cancelled: () => cancelled,
      );
      await wallets.started.future;
      cancelled = true;
      pending.complete(Ok(context));
      expect(_ok(await recovery), isA<VaultRecovered>());
      expect(_ok(await secrets.exists(context.fingerprint)), isTrue);
    },
  );

  test(
    'wallet failure reports the imported secret without rolling it back',
    () async {
      final backup = _ok(await facade.create());
      final before = Map.of(storage.entries);
      wallets.pending = Future.value(const Err(VaultStorageFailure()));
      final result = _ok(
        await facade.restore(
          vault: backup.vault,
          key: backup.key,
          network: context.network,
          cancelled: () => false,
        ),
      );
      expect(result, isA<VaultRecoveryNeedsWallets>());
      expect(result.importedSecret, context.fingerprint);
      expect(
        storage.entries,
        before,
        reason: 'a reused secret is never deleted',
      );
    },
  );

  test('a different restored network is never certified', () async {
    final backup = _ok(await facade.create());
    wallets.pending = Future.value(
      Ok(
        VaultContext(
          fingerprint: context.fingerprint,
          network: BitcoinNetwork.mainnet,
        ),
      ),
    );
    final result = _ok(
      await facade.restore(
        vault: backup.vault,
        key: backup.key,
        network: context.network,
        cancelled: () => false,
      ),
    );
    expect(
      result,
      isA<VaultRecoveryNeedsWallets>().having(
        (r) => r.failure,
        'failure',
        isA<VaultContextChangedFailure>(),
      ),
    );
  });
}

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};

final class _Wallets implements RecoverBullWalletPort {
  VaultContext? current;
  int restores = 0;
  final started = Completer<void>();
  Future<Result<VaultContext, RecoverBullFailure>>? pending;

  _Wallets(this.current);

  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      Ok(current);

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) {
    restores++;
    started.complete();
    return pending ?? Future.value(Ok(requested));
  }
}
