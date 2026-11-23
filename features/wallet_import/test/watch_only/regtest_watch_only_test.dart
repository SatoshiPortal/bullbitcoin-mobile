import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:wallet_import/src/domain/watch_only/parse_watch_only_input_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:bip32_keys/bip32_keys.dart'
    show changeVersionBytes, Slip132Format;
import 'package:signers/signers.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

// Published public BIP84 test-vector account. No private material is needed.
const vpub =
    'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc';
const mainnetXpub =
    'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';

void main() {
  final parse = ParseWatchOnlyInputUsecase();

  test(
    'captures regtest rather than the indistinguishable test public version',
    () async {
      final result = await parse.execute(vpub, environment: NetworkEnv.regtest);
      expect(result, isA<Ok>());
      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value;
      expect(entity.network, BitcoinNetwork.regtest);
      expect(entity.keyNetwork, BitcoinNetwork.testnet);
      expect(entity.signer, SignerEntity.none);
      expect(entity.pubkey, vpub);
    },
  );

  test(
    'the same public account derives bcrt in regtest and tb in testnet',
    () async {
      final result = await parse.execute(vpub, environment: NetworkEnv.regtest);
      final entity = (result as Ok).value;
      final bip32Pubkey = (entity as WatchOnlyXpubEntity).bip32Pubkey;
      final descriptor = bdk.Descriptor(
        descriptor: 'wpkh($bip32Pubkey/0/*)',
        networkKind: bdk.NetworkKind.test,
      );
      String address(bdk.Network network) =>
          bdk.Wallet.createSingle(
                descriptor: descriptor,
                network: network,
                persister: bdk.Persister.newInMemory(),
                lookahead: 20,
              )
              .peekAddress(keychain: bdk.KeychainKind.external_, index: 0)
              .address
              .toString();
      expect(address(bdk.Network.regtest), startsWith('bcrt1q'));
      expect(address(bdk.Network.testnet), startsWith('tb1q'));
      expect(bip32Pubkey, startsWith('tpub'));
    },
  );

  test('software descriptor is accepted without a hardware binding', () async {
    final tpub = changeVersionBytes(vpub, Slip132Format.tpub);
    final descriptor = 'wpkh([73c5da0a/84h/1h/0h]$tpub/<0;1>/*)';
    final result = await parse.execute(
      descriptor,
      environment: NetworkEnv.regtest,
    );
    final entity =
        (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value;
    expect(entity, isA<WatchOnlyDescriptorEntity>());
    expect(entity.network, BitcoinNetwork.regtest);
    expect(entity.signer, SignerEntity.none);
    expect((entity as WatchOnlyDescriptorEntity).signerDevice, isNull);
    final hardware = await WatchOnlyInput.parse(
      descriptor,
      environment: NetworkEnv.regtest,
      signerDevice: SignerDevice.seedsigner,
    );
    expect((hardware as Err).failure, isA<InvalidWatchOnlyInputFailure>());
  });

  test(
    'plain tpub captures the explicit BIP84 context without changing its key',
    () async {
      final tpub = changeVersionBytes(vpub, Slip132Format.tpub);
      final result = await parse.execute(tpub, environment: NetworkEnv.regtest);
      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value;
      expect(entity.pubkey, tpub);
      final hardwareScanned =
          (await WatchOnlyInput.parse(
                tpub,
                signerDevice: SignerDevice.seedsigner,
              ) as Ok).value
              as WatchOnlyInput;
      expect(
        hardwareScanned.captureEnvironment(NetworkEnv.regtest),
        isA<Err>(),
      );
      final scanned =
          (await WatchOnlyInput.parse(tpub) as Ok).value as WatchOnlyInput;
      final bound = scanned.captureEnvironment(NetworkEnv.regtest);
      expect(
        ((bound as Ok).value as WatchOnlyInput).scriptType,
        ScriptType.bip84,
      );
      final legacyScanned =
          (await WatchOnlyInput.parse('[73c5da0a/44h/1h/0h]$tpub') as Ok).value
              as WatchOnlyInput;
      expect(legacyScanned.captureEnvironment(NetworkEnv.regtest), isA<Err>());
      expect(entity.network, BitcoinNetwork.regtest);
      final invalidOrigin = await WatchOnlyInput.parse(
        '[73c5da0a/44h/1h/0h]$tpub',
        environment: NetworkEnv.regtest,
      );
      expect(
        (invalidOrigin as Err).failure,
        isA<InvalidWatchOnlyInputFailure>(),
      );
      expect(
        entity.validatedInput(NetworkEnv.testnet),
        isA<Err<WatchOnlyInput, ImportWatchOnlyFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<NetworkMismatchFailure>(),
        ),
      );
    },
  );

  test(
    'regtest rejects mainnet keys and unsupported script descriptors',
    () async {
      final mismatch = await parse.execute(
        mainnetXpub,
        environment: NetworkEnv.regtest,
      );
      expect((mismatch as Err).failure, isA<NetworkMismatchFailure>());
      final tpub = changeVersionBytes(vpub, Slip132Format.tpub);
      for (final (operand, purpose, suffix) in [
        ('pkh', 44, ''),
        ('sh(wpkh', 49, ')'),
      ]) {
        final descriptor =
            '$operand([73c5da0a/${purpose}h/1h/0h]$tpub/<0;1>/*)$suffix';
        final result = await parse.execute(
          descriptor,
          environment: NetworkEnv.regtest,
        );
        expect((result as Err).failure, isA<InvalidFormatFailure>());
      }
    },
  );

  test('mainnet/testnet context and mismatch behavior are preserved', () async {
    final mainnet = await parse.execute(
      mainnetXpub,
      environment: NetworkEnv.mainnet,
    );
    expect(
      (mainnet as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
          .value
          .network,
      BitcoinNetwork.mainnet,
    );
    final testnet = await parse.execute(vpub, environment: NetworkEnv.testnet);
    expect(
      (testnet as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
          .value
          .network,
      BitcoinNetwork.testnet,
    );
    expect(
      (await parse.execute(
        vpub,
        environment: NetworkEnv.mainnet,
      ) as Err).failure,
      isA<NetworkMismatchFailure>(),
    );
  });
}
