import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_renewal_client.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_account_registry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/ark_renewal.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import '../../support/inventory_fixture.dart';

final class _Registry implements ArkAccountRegistryRepository {
  final List<ArkAccountConfig> configs;
  _Registry(this.configs);

  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async =>
      const Ok(null);

  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async =>
      Ok(configs);
}

ArkAccountConfig _config(Fingerprint parent) => ArkAccountConfig(
  id: ArkAccountId(
    parent: parent,
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  ),
  arkUrl: Uri.parse('http://localhost:3535'),
  primaryEsploraUrl: Uri.parse('http://localhost:3000'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late FakeSecureStoragePlatform keystore;
  late InventoryFixture fixture;
  late Secrets secrets;
  late ArkRenewalSecrets renewal;
  late Fingerprint parent;
  late ArkAccountConfig account;
  final stranger = Fingerprint('01234567');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ark-renewal-client-');
    keystore = FakeSecureStoragePlatform()..install();
    fixture = await InventoryFixture.open(directory);
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    parent = switch (await secrets.generate()) {
      Ok(:final value) => value.id,
      Err() => throw StateError('seed generation failed'),
    };
    expect(
      await fixture.inventory.registerWallet(
        RegisteredWallet(
          id: 'wpkh([${parent.hex}/84h/1h/0h]):regtest',
          secretFingerprint: parent.hex,
          masterFingerprint: parent.hex,
          signer: 'local',
          network: 'bitcoinRegtest',
          xpub: 'public-marker',
          externalDescriptor: 'wpkh(public-marker/0/*)',
          internalDescriptor: 'wpkh(public-marker/1/*)',
          label: null,
          birthday: null,
          isDefault: true,
        ),
      ),
      isA<Ok>(),
    );
    renewal = switch (await ArkRenewalSecrets.open(
      file: File('${directory.path}/test-secrets.sqlite'),
      admission: fixture.admission,
    )) {
      Ok(:final value) => value,
      Err() => throw StateError('renewal secrets unavailable'),
    };
    account = _config(parent);
  });

  tearDown(() async {
    await renewal.close();
    await fixture.inventory.close();
    await fixture.admission.close();
    await directory.delete(recursive: true);
  });

  ArkRenewalChildProvider provider([List<ArkAccountConfig>? registered]) =>
      ArkRenewalChildProvider(
        renewal,
        _Registry(registered ?? [account, _config(stranger)]),
      );

  Future<Result<String, ArkWalletFailure>> open(
    ArkRenewalChildProvider subject,
    ArkAccountConfig config,
  ) => subject.withChild<String>(
    config.id,
    (words, fingerprint) async => Ok(fingerprint.hex),
  );

  test('the worker gets the dedicated child of the exact account, never the parent', () async {
    final handle = switch (await secrets.fetch(parent)) {
      Ok(:final value) => value,
      Err() => throw StateError('seed missing'),
    };
    final expectedWords = switch (await handle.derive.bip85.mnemonic(
      wordCount: MnemonicLength.words12,
      index: arkChildBip85Index,
      language: Language.english,
    )) {
      Ok(:final value) => value.join(' '),
      Err() => throw StateError('derivation failed'),
    };
    String? seenWords;
    Fingerprint? seenChild;

    final result = await provider().withChild<String>(account.id, (
      words,
      fingerprint,
    ) async {
      seenWords = words;
      seenChild = fingerprint;
      return Ok(fingerprint.hex);
    });

    expect(result, isA<Ok<String, ArkWalletFailure>>());
    expect(seenWords, expectedWords);
    expect(seenChild, isNot(parent), reason: 'a child, not the parent seed');
    expect((result as Ok<String, ArkWalletFailure>).value, seenChild?.hex);
  });

  test('a view protected by a PIN is refreshed', () async {
    expect(await fixture.inventory.setCredential('1234'), isA<Ok>());
    expect(await fixture.inventory.lock(), isTrue);
    final subject = provider();

    expect(await open(subject, account), isA<Ok<String, ArkWalletFailure>>());
    expect(await subject.admitBatch(account.id), isA<Ok>());
  });

  test(
    'an account that is not registered is refused and reads no seed',
    () async {
      final baseline = keystore.reads;
      final result = await open(provider([_config(stranger)]), account);
      expect(
        (result as Err<String, ArkWalletFailure>).failure,
        isA<ArkRecoveryRequiredFailure>(),
      );
      expect(keystore.reads, baseline);
    },
  );

  test(
    'two registered accounts: the one without background access is refused',
    () async {
      final subject = provider();
      final baseline = keystore.reads;

      final forbidden = await open(subject, _config(stranger));
      expect(
        (forbidden as Err<String, ArkWalletFailure>).failure,
        isA<ArkRenewalNotPermittedFailure>(),
      );
      expect(
        keystore.reads,
        baseline,
        reason: 'the refused account read nothing',
      );
      expect(await subject.admitBatch(_config(stranger).id), isA<Err>());

      expect(await open(subject, account), isA<Ok<String, ArkWalletFailure>>());
    },
  );

  test(
    'background access withdrawn between two lots stops the second',
    () async {
      final subject = provider();
      expect(
        await subject.admitBatch(account.id),
        isA<Ok>(),
        reason: 'first lot',
      );

      expect(await fixture.inventory.setBackgroundEnabled(false), isA<Ok>());

      final second = await subject.admitBatch(account.id);
      expect(
        (second as Err<void, ArkWalletFailure>).failure,
        isA<ArkRenewalNotPermittedFailure>(),
      );
      expect(
        await open(subject, account),
        isA<Err<String, ArkWalletFailure>>(),
      );
    },
  );

  test(
    'an inventory that could not be opened leaves refresh unavailable',
    () async {
      final baseline = keystore.reads;
      final subject = ArkRenewalChildProvider(null, _Registry([account]));

      final opened = await open(subject, account);
      expect(
        (opened as Err<String, ArkWalletFailure>).failure,
        isA<ArkUnavailableFailure>(),
      );
      expect(await subject.admitBatch(account.id), isA<Err>());
      expect(keystore.reads, baseline);
    },
  );
}
