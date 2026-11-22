import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late SecretsInventory inventory;
  late BackgroundWalletDescriptors background;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-session-');
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
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    inventory = _value(
      await SecretsInventory.open(file: file, admission: admission),
    );
    background = _value(
      await BackgroundWalletDescriptors.open(file: file, admission: admission),
    );
  });

  tearDown(() async {
    await admission.close();
    await directory.delete(recursive: true);
  });

  test(
    'locking withdraws foreground inventory and keeps background grant',
    () async {
      expect(
        await inventory.registerWallet(_wallet('test-wallet', '01234567')),
        isA<Ok>(),
      );
      final pending = inventory.listWallets();
      inventory.lock();

      expect(await pending, isA<Err>());
      expect(await inventory.listWallets(), isA<Err>());
      expect(await inventory.findWallet('test-wallet'), isA<Err>());
      expect(_value(await background.list()).single.id, 'test-wallet');
      expect(await inventory.resumeUnprotected(), isA<Ok>());
      expect(_value(await inventory.listWallets()).single.id, 'test-wallet');
    },
  );

  test('background opt-out stops descriptor access at the owner', () async {
    expect(
      await inventory.registerWallet(_wallet('test-wallet', '01234567')),
      isA<Ok>(),
    );
    expect(_value(await background.list()), hasLength(1));
    expect(await inventory.setBackgroundEnabled(false), isA<Ok>());
    inventory.lock();
    expect(_value(await background.list()), isEmpty);
    expect(await inventory.setBackgroundEnabled(true), isA<Err>());
  });

  test(
    'reservations are serial per parent and include revoked records',
    () async {
      final parent = Fingerprint('01234567');
      final otherParent = Fingerprint('89abcdef');
      expect(
        await inventory.registerWallet(_wallet('one', parent.hex)),
        isA<Ok>(),
      );
      expect(
        await inventory.registerWallet(_wallet('two', otherParent.hex)),
        isA<Ok>(),
      );
      Future<RecordedDerivation> reserve(Fingerprint parent) async => _value(
        await inventory.reserveHexDerivation(parent: parent, length: 16),
      );

      final pair = await Future.wait([reserve(parent), reserve(parent)]);
      expect(pair.map((record) => record.index), unorderedEquals([0, 1]));
      expect(
        await inventory.setDerivationActive(pair.last, active: false),
        isA<Ok>(),
      );
      expect((await reserve(parent)).index, 2);
      expect((await reserve(otherParent)).index, 0);
    },
  );

  test('ordinary module key handles cannot open the inventory', () {
    final keys = Secrets(scratchDirectory: () async => directory.path);
    expect(() => keys.databaseKeys(module: 'secrets'), throwsArgumentError);
  });
}

RegisteredWallet _wallet(String id, String parent) => RegisteredWallet(
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

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
