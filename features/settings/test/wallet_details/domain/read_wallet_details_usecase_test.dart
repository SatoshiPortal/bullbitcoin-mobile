import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';
import 'package:settings/src/wallet_details/domain/read_wallet_details_usecase.dart';
import 'package:settings/src/wallet_details/domain/wallet_details.dart';
import 'package:settings/src/wallet_details/domain/wallet_details_failure.dart';
import 'package:signers/signers.dart' show SignerDevice;

import '../support/inventory.dart';

/// Reading one wallet's public description from the inventory, against the
/// real stores.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InventoryFixture inventory;
  late ReadWalletDetailsUsecase usecase;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    inventory = await InventoryFixture.open();
    usecase = ReadWalletDetailsUsecase(inventory.inventory, inventory.devices);
  });

  tearDown(() => inventory.close());

  test('describes a wallet with its signer device', () async {
    const id = 'wpkh([0a1b2c3d/84h/0h/0h])';
    await inventory.register(
      walletRow(
        id: id,
        masterFingerprint: '0a1b2c3d',
        label: 'Savings',
        purpose: 84,
      ),
      device: SignerDevice.coldcardQ,
    );

    final result = await usecase.execute(id);

    expect(result, isA<Ok<WalletDetails, WalletDetailsFailure>>());
    final details = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('read failed: ${failure.runtimeType}'),
    };
    expect(details.id, id);
    expect(details.label, 'Savings');
    expect(details.isDefault, isFalse);
    expect(details.network, BitcoinNetwork.mainnet);
    expect(details.scriptType, ScriptType.bip84);
    expect(details.masterFingerprint, '0a1b2c3d');
    expect(details.xpub, 'xpub-marker');
    expect(details.externalDescriptor, contains('wpkh('));
    expect(details.signer, SignerEntity.none);
    expect(details.signerDevice, SignerDevice.coldcardQ);
    expect(details.addressType, 'Native Segwit');
    expect(details.networkName, 'Bitcoin Network');
    expect(details.derivationPath, 'm/84h/0h/0h');
  });

  test('keeps the default flag and the network of the registration', () async {
    const id = 'wpkh([0a1b2c3d/84h/1h/0h]):regtest';
    await inventory.register(
      walletRow(
        id: id,
        masterFingerprint: '0a1b2c3d',
        network: 'bitcoinRegtest',
        isDefault: true,
      ),
    );

    final details = switch (await usecase.execute(id)) {
      Ok(:final value) => value,
      Err(:final failure) => fail('read failed: ${failure.runtimeType}'),
    };

    expect(details.isDefault, isTrue);
    expect(details.network, BitcoinNetwork.regtest);
    expect(details.networkName, 'Bitcoin Regtest');
    expect(details.signerDevice, isNull);
  });

  for (final (signer, expected) in [
    ('local', SignerEntity.local),
    ('remote', SignerEntity.remote),
  ]) {
    test('maps a $signer signer to ${expected.name}', () async {
      const id = 'wpkh([0a1b2c3d/49h/0h/0h])';
      await inventory.register(
        walletRow(
          id: id,
          masterFingerprint: '0a1b2c3d',
          secretFingerprint: signer == 'local' ? '0a1b2c3d' : null,
          signer: signer,
          purpose: 49,
        ),
      );

      final details = switch (await usecase.execute(id)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('read failed: ${failure.runtimeType}'),
      };

      expect(details.signer, expected);
      expect(details.addressType, 'Nested Segwit');
    });
  }

  test('reports a missing wallet as not found', () async {
    final result = await usecase.execute('wpkh([0a1b2c3d/84h/0h/0h])');

    expect(result, isA<Err<WalletDetails, WalletDetailsFailure>>());
    expect(switch (result) {
      Err(:final failure) => failure,
      Ok() => fail('expected a failure'),
    }, isA<WalletDetailsNotFoundFailure>());
  });

  test('reports an unreadable registration as unavailable', () async {
    // The row exists but its identity is not decodable: not found would claim
    // the wallet is absent, which is a different and wrong answer.
    await inventory.register(
      walletRow(id: 'invalid origin', masterFingerprint: '0a1b2c3d'),
    );

    final result = await usecase.execute('invalid origin');

    expect(switch (result) {
      Err(:final failure) => failure,
      Ok() => fail('expected a failure'),
    }, isA<WalletDetailsUnavailableFailure>());
  });

  test('refuses to describe a wallet of a locked inventory', () async {
    const id = 'wpkh([0a1b2c3d/84h/0h/0h])';
    await inventory.register(walletRow(id: id, masterFingerprint: '0a1b2c3d'));
    inventory.inventory.lock();

    final result = await usecase.execute(id);

    expect(switch (result) {
      Err(:final failure) => failure,
      Ok() => fail('expected a failure'),
    }, isA<WalletDetailsUnavailableFailure>());
  });
}
