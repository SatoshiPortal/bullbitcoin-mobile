import 'dart:convert';

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
  const descriptor =
      'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)#n8txaeah';
  const otherDescriptor =
      'wpkh([76241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)';

  test('encodes definitions in canonical descriptor order', () {
    final first = _definition('a', otherDescriptor);
    final second = _definition('b', descriptor);

    final encoded = codec.encode([second, first]);
    final decoded = codec.decode(encoded);

    expect(decoded.map((definition) => definition.walletRef), ['a', 'b']);
    expect(codec.encode(decoded), encoded);
    expect(encoded, contains('"signerDevice":"ledgerNanoX"'));
    expect(encoded, contains('"provenance":"externalSigner"'));
  });

  test('stores one canonical multipath descriptor', () {
    final encoded = codec.encode([_definition('wallet', descriptor)]);
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final definition = (json['definitions'] as List).single as Map;

    expect(definition['descriptor'], descriptor);
    expect(definition, isNot(contains('receiveDescriptor')));
    expect(definition, isNot(contains('changeDescriptor')));
    expect(definition, isNot(contains('masterFingerprint')));
    expect(codec.decode(encoded).single.descriptor, descriptor);
  });

  test('rejects the legacy separate-descriptor shape', () {
    final legacy = jsonEncode({
      'version': 1,
      'definitions': [
        {
          'walletRef': 'legacy-wallet',
          'network': 'bitcoinMainnet',
          'receiveDescriptor': descriptor
              .replaceFirst('/<0;1>/*', '/0/*')
              .split('#')
              .first,
          'changeDescriptor': descriptor
              .replaceFirst('/<0;1>/*', '/1/*')
              .split('#')
              .first,
          'masterFingerprint': '86241f88',
          'signerDevice': null,
          'birthdayUnix': null,
          'provenance': 'watchOnly',
        },
      ],
    });

    expect(() => codec.decode(legacy), throwsA(isA<FormatException>()));
  });

  test('rejects seed-recoverable wallets from the definitions section', () {
    final definition = WalletDefinition(
      walletRef: 'mnemonic',
      network: Network.bitcoinMainnet,
      descriptor: descriptor,
      provenance: WalletProvenance.importedMnemonic,
    );

    expect(() => codec.encode([definition]), throwsA(isA<FormatException>()));
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
    ).toStringWithSecret().split('#').first.replaceFirst('/0/*', '/<0;1>/*');

    expect(
      () => codec.encode([_definition('private', privateDescriptor)]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate descriptor-set identities', () {
    expect(
      () => codec.encode([
        _definition('one', descriptor),
        _definition('two', descriptor),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects separate receive-only descriptors', () {
    final external = descriptor
        .replaceFirst('/<0;1>/*', '/0/*')
        .split('#')
        .first;

    expect(
      () => codec.encode([_definition('external', external)]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate wallet ids', () {
    expect(
      () => codec.encode([
        _definition('same', descriptor),
        _definition('same', otherDescriptor),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects descriptors larger than the wire limit', () {
    expect(
      () => WalletDefinition(
        walletRef: 'oversized',
        network: Network.bitcoinMainnet,
        descriptor: 'x' * (WalletDefinition.maxDescriptorLength + 1),
        provenance: WalletProvenance.watchOnly,
      ),
      throwsArgumentError,
    );
  });

  test('accepts conventional JSON whitespace', () {
    final canonical = codec.encode([_definition('a', descriptor)]);
    final formatted = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(canonical));

    expect(codec.decode('$formatted\n'), hasLength(1));
  });

  test('rejects unknown provenance', () {
    final canonical = codec.encode([_definition('a', descriptor)]);
    expect(
      () =>
          codec.decode(canonical.replaceFirst('"externalSigner"', '"unknown"')),
      throwsA(isA<FormatException>()),
    );
  });
}

WalletDefinition _definition(String walletRef, String descriptor) =>
    WalletDefinition(
      walletRef: walletRef,
      network: Network.bitcoinMainnet,
      descriptor: descriptor,
      signerDevice: SignerDeviceEntity.ledgerNanoX,
      birthday: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      provenance: WalletProvenance.externalSigner,
    );
