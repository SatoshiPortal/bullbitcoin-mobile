import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_definitions_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = WalletDefinitionsCodec();
  const xOnlyKey =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

  test('encodes definitions in canonical receive-descriptor order', () {
    final first = _definition('a', 'tr($xOnlyKey)');
    final second = _definition('b', 'wpkh(02$xOnlyKey)');

    final encoded = codec.encode([second, first]);
    final decoded = codec.decode(encoded);

    expect(decoded.map((definition) => definition.walletRef), ['a', 'b']);
    expect(codec.encode(decoded), encoded);
    expect(encoded, contains('"signerDevice":"ledgerNanoX"'));
    expect(encoded, contains('"provenance":"externalSigner"'));
  });

  test('accepts a valid x-only Taproot descriptor', () {
    final encoded = codec.encode([_definition('taproot', 'tr($xOnlyKey)')]);

    expect(codec.decode(encoded).single.walletRef, 'taproot');
  });

  test('round-trips mnemonic provenance and passphrase state', () {
    final definition = WalletDefinition(
      walletRef: 'mnemonic',
      network: Network.bitcoinMainnet,
      receiveDescriptor: 'tr($xOnlyKey)',
      provenance: WalletProvenance.importedMnemonic,
      seedPassphraseUsed: true,
    );

    final decoded = codec.decode(codec.encode([definition])).single;

    expect(decoded.provenance, WalletProvenance.importedMnemonic);
    expect(decoded.seedPassphraseUsed, isTrue);
  });

  test('rejects a descriptor containing private key material', () {
    final mnemonic = bdk.Mnemonic.fromString(
      mnemonic:
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about',
    );
    final secretKey = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.main,
      mnemonic: mnemonic,
      password: null,
    );
    final privateDescriptor = bdk.Descriptor.newBip84(
      secretKey: secretKey,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.main,
    ).toStringWithSecret();

    expect(
      () => codec.encode([_definition('private', privateDescriptor)]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate descriptor-set identities', () {
    final descriptor = 'tr($xOnlyKey)';

    expect(
      () => codec.encode([
        _definition('one', descriptor),
        _definition('two', descriptor),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects descriptors larger than the wire limit', () {
    expect(
      () => WalletDefinition(
        walletRef: 'oversized',
        network: Network.bitcoinMainnet,
        receiveDescriptor: 'x' * (WalletDefinition.maxDescriptorLength + 1),
        provenance: WalletProvenance.watchOnly,
      ),
      throwsArgumentError,
    );
  });

  test('rejects non-canonical payload bytes', () {
    final canonical = codec.encode([_definition('a', 'tr($xOnlyKey)')]);

    expect(() => codec.decode('$canonical\n'), throwsA(isA<FormatException>()));
  });
}

WalletDefinition _definition(String walletRef, String receiveDescriptor) =>
    WalletDefinition(
      walletRef: walletRef,
      network: Network.bitcoinMainnet,
      receiveDescriptor: receiveDescriptor,
      masterFingerprint: '01234567',
      signerDevice: SignerDeviceEntity.ledgerNanoX,
      birthday: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      provenance: WalletProvenance.externalSigner,
    );
