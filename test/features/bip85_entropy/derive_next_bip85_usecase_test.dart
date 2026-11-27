import 'dart:io';

import 'package:bip85/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/bip85.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import '../../support/inventory_fixture.dart';

class _Environment implements ActiveEnvironmentReader {
  Result<Environment, PreferencesFailure> environment = const Ok(
    Environment.testnet,
  );

  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async => environment;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Secrets secrets;
  late InventoryFixture fixture;
  late Bip85Derivations derivations;
  late _Environment preferences;
  late ManageBip85Usecase usecase;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    final directory = await Directory.systemTemp.createTemp('bip85-view-');
    addTearDown(() => directory.delete(recursive: true));
    fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    derivations = fixture.inventory.bip85(secrets);
    preferences = _Environment();
    usecase = ManageBip85Usecase(derivations, fixture.inventory, preferences);
  });

  Future<Fingerprint> registerDefault({
    required String network,
    bool isDefault = true,
    String signer = 'local',
    String? master,
  }) async {
    final parent = _value(await secrets.generate()).id;
    final fingerprint = master ?? parent.hex;
    final id = "wpkh([${parent.hex}/84h/1h/0h])";
    final wallet = RegisteredWallet(
      id: id,
      secretFingerprint: signer == 'local' ? fingerprint : null,
      masterFingerprint: fingerprint,
      signer: signer,
      network: network,
      xpub: 'test',
      externalDescriptor: 'wpkh(external)',
      internalDescriptor: 'wpkh(internal)',
      label: null,
      birthday: null,
      isDefault: isDefault,
    );
    expect(await fixture.inventory.registerWallet(wallet), isA<Ok>());
    return parent;
  }

  test('uses the first Bitcoin default in the active environment', () async {
    await registerDefault(network: 'bitcoinMainnet');
    await registerDefault(network: 'bitcoinTestnet', isDefault: false);
    final candidates = [
      await registerDefault(network: 'bitcoinTestnet'),
      await registerDefault(network: 'bitcoinTestnet'),
    ]..sort((a, b) => a.hex.compareTo(b.hex));
    final next = _value(await usecase.nextMnemonic());
    expect(next.parentFingerprint, candidates.first.hex);
    expect(next.path, "39'/0'/12'/0'");
    expect(
      _value(await usecase.nextHex()).parentFingerprint,
      candidates.first.hex,
    );

    preferences.environment = const Ok(Environment.mainnet);
    expect(_value(await usecase.list()), isEmpty);
  });

  test(
    'separates a missing default from a preference or inventory failure',
    () async {
      expect(
        await usecase.nextMnemonic(),
        isA<Err<Bip85Derivation, Bip85Failure>>().having(
          (result) => result.failure,
          'failure',
          isA<Bip85NoDefaultWalletFailure>(),
        ),
      );
      preferences.environment = const Err(PreferencesReadFailure());
      expect(
        await usecase.nextHex(),
        isA<Err<Bip85Derivation, Bip85Failure>>().having(
          (result) => result.failure,
          'failure',
          isA<Bip85OperationFailure>(),
        ),
      );

      preferences.environment = const Ok(Environment.testnet);
      fixture.inventory.lock();
      expect(
        await usecase.list(),
        isA<Err>().having(
          (result) => result.failure,
          'failure',
          isA<Bip85OperationFailure>(),
        ),
      );
    },
  );

  test('a noncanonical origin cannot become a derivation root', () async {
    await registerDefault(
      network: 'bitcoinTestnet',
      signer: 'remote',
      master: 'invalid',
    );
    expect(
      await usecase.nextMnemonic(),
      isA<Err<Bip85Derivation, Bip85Failure>>().having(
        (result) => result.failure,
        'failure',
        isA<Bip85OperationFailure>(),
      ),
    );
  });

  test('rows of another root key are not re-derived from this one', () async {
    final mainnet = await registerDefault(network: 'bitcoinMainnet');
    final testnet = await registerDefault(network: 'bitcoinTestnet');
    final other = _value(
      await derivations.deriveNextHex(parent: mainnet, length: 30),
    );
    final current = _value(await usecase.nextHex());
    expect(other.path, current.path);
    final children = _value(await usecase.list());
    expect(children.single.derivation.parentFingerprint, testnet.hex);
    final secret = _value(await secrets.fetch(testnet));
    final expected = _value(
      await secret.derive.bip85.hex(numBytes: 30, index: current.index),
    );
    expect(children.single.entropy == expected, isTrue);
  });

  test(
    'parallel reservations receive distinct indices and lock blocks reads',
    () async {
      final parent = await registerDefault(network: 'bitcoinTestnet');
      final reservations = await Future.wait([
        for (var i = 0; i < 3; i++)
          derivations.deriveNextHex(parent: parent, length: 30),
      ]);
      expect(reservations.map(_value).map((entry) => entry.index).toSet(), {
        0,
        1,
        2,
      });
      fixture.inventory.lock();
      expect(await derivations.reveal(parent), isA<Err>());
      expect(await derivations.deriveNextMnemonic(parent: parent), isA<Err>());
    },
  );

  test('alias and status changes retain the reserved index', () async {
    final parent = await registerDefault(network: 'bitcoinTestnet');
    final first = _value(await usecase.nextMnemonic());
    expect(await usecase.rename(first, 'renamed'), isA<Ok>());
    expect(await usecase.setActive(first, active: false), isA<Ok>());
    final revoked = _value(await derivations.list()).single;
    expect(revoked.alias, 'renamed');
    expect(revoked.status, Bip85Status.revoked);
    final second = _value(
      await derivations.deriveNextMnemonic(
        parent: parent,
        length: MnemonicLength.words24,
      ),
    );
    expect(second.index, first.index + 1);
    expect(await usecase.setActive(revoked, active: true), isA<Ok>());
    final records = _value(await derivations.list());
    expect(
      records.every((record) => record.status == Bip85Status.active),
      isTrue,
    );
  });
}

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Unexpected failure: ${failure.runtimeType}'),
};
