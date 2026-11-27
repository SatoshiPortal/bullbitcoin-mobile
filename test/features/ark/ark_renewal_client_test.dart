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

  ArkRenewalAdmission admission([List<ArkAccountConfig>? registered]) =>
      ArkRenewalAdmission(
        renewal,
        _Registry(registered ?? [account, _config(stranger)]),
      );

  test('a view protected by a PIN is admitted for refresh', () async {
    expect(await fixture.inventory.setCredential('1234'), isA<Ok>());
    expect(await fixture.inventory.lock(), isTrue);
    final subject = admission();

    expect(await subject.openRefusal(account.id), isNull);
    expect(await subject.admitBatch(account.id), isA<Ok>());
  });

  test(
    'an account that is not registered is refused and reads no seed',
    () async {
      final baseline = keystore.reads;
      final refusal = await admission([_config(stranger)])
          .openRefusal(account.id);
      expect(refusal, isA<ArkRecoveryRequiredFailure>());
      expect(keystore.reads, baseline);
    },
  );

  test(
    'two registered accounts: the one without background access is refused',
    () async {
      final subject = admission();
      final baseline = keystore.reads;

      final forbidden = await subject.admitBatch(_config(stranger).id);
      expect(
        (forbidden as Err<void, ArkWalletFailure>).failure,
        isA<ArkRenewalNotPermittedFailure>(),
      );
      expect(
        keystore.reads,
        baseline,
        reason: 'the refused account read nothing',
      );

      expect(await subject.admitBatch(account.id), isA<Ok>());
      expect(keystore.reads, baseline, reason: 'admission reads no seed');
    },
  );

  test(
    'background access withdrawn between two lots stops the second',
    () async {
      final subject = admission();
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
    },
  );

  test(
    'an inventory that could not be opened leaves refresh unavailable',
    () async {
      final baseline = keystore.reads;
      final subject = ArkRenewalAdmission(null, _Registry([account]));

      expect(
        await subject.openRefusal(account.id),
        isA<ArkUnavailableFailure>(),
      );
      final batch = await subject.admitBatch(account.id);
      expect(batch, isA<Err<void, ArkWalletFailure>>());
      expect(keystore.reads, baseline);
    },
  );
}
