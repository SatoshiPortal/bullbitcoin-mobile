import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_definitions_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_bullvault_backup.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import '../support/canonical_backup_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = WalletDefinitionsCodec();
  const descriptor =
      "wpkh([86241f88/84'/0'/0']xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)#y0kg3ch2";
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

  test('reads existing version-2 files without inventing signer facts', () {
    final original = _definition('saved-v2', descriptor);
    final document =
        jsonDecode(codec.encode([original])) as Map<String, dynamic>;
    document['version'] = 2;
    for (final definition in document['definitions'] as List) {
      for (final signer in definition['signers'] as List) {
        (signer as Map).remove('registrationName');
        signer.remove('localSeedFingerprint');
        for (final key in signer['descriptorKeys'] as List) {
          (key as Map).remove('requiresPassphrase');
        }
      }
    }
    final restored = codec.decode(jsonEncode(document)).single;
    expect(restored.signers, original.signers);
    expect(restored.signers.single.registrationName, isNull);
    expect(restored.signers.single.localSeedFingerprint, isNull);
    expect(
      restored.signers.single.descriptorKeys.single.requiresPassphrase,
      isFalse,
    );
    expect(jsonDecode(codec.encode([restored]))['version'], 3);
  });

  test('rejects non-integer versions and missing version-3 signer facts', () {
    final encoded = codec.encode([_definition('wallet', descriptor)]);
    final document = jsonDecode(encoded) as Map<String, dynamic>;
    document['version'] = 3.0;
    expect(() => codec.decode(jsonEncode(document)), throwsFormatException);
    document['version'] = 3;
    final definition = (document['definitions'] as List).single as Map;
    final signer = (definition['signers'] as List).single as Map;
    signer.remove('registrationName');
    expect(() => codec.decode(jsonEncode(document)), throwsFormatException);
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

  test('rejects malformed signer recovery facts', () {
    final encoded = codec.encode([_definition('wallet', descriptor)]);
    for (final invalid in <Map<String, Object?>>[
      {'registrationName': 123},
      {'registrationName': '  '},
      {'localSeedFingerprint': 'not-a-fingerprint', 'signer': 'local'},
      {'localSeedFingerprint': 'aabbccdd', 'signer': 'remote'},
    ]) {
      final document = jsonDecode(encoded) as Map<String, dynamic>;
      final definition = (document['definitions'] as List).single as Map;
      final signer = (definition['signers'] as List).single as Map;
      signer.addAll(invalid);
      expect(() => codec.decode(jsonEncode(document)), throwsFormatException);
    }
    for (final invalid in <Object?>[null, 'true', 1]) {
      final document = jsonDecode(encoded) as Map<String, dynamic>;
      final definition = (document['definitions'] as List).single as Map;
      final signer = (definition['signers'] as List).single as Map;
      final key = (signer['descriptorKeys'] as List).single as Map;
      key['requiresPassphrase'] = invalid;
      expect(() => codec.decode(jsonEncode(document)), throwsFormatException);
    }
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

  test('round-trips every signer and key of a multi-signer definition', () {
    final definition = WalletDefinition(
      walletRef: 'shared',
      network: Network.bitcoinMainnet,
      descriptor: canonicalExternalDescriptor,
      signers: [
        WalletSigner(
          id: 'signer-0',
          signer: SignerEntity.local,
          signerDevice: null,
          registrationName: 'Saved policy name',
          localSeedFingerprint: '12345678',
          descriptorKeys: [
            WalletDescriptorKey(
              id: 'key-0',
              signerId: 'signer-0',
              masterFingerprint: '73c5da0a',
              xpubFingerprint: 'aaaaaaaa',
              xpub: 'xpub-local',
              derivationPath: "m/48'/0'/0'/2'",
              descriptorPath: '/<0;1>/*',
              requiresPassphrase: true,
            ),
          ],
        ),
        WalletSigner(
          id: 'signer-1',
          signer: SignerEntity.remote,
          signerDevice: SignerDeviceEntity.coldcardQ,
          descriptorKeys: [
            WalletDescriptorKey(
              id: 'key-1',
              signerId: 'signer-1',
              masterFingerprint: '86241f88',
              xpubFingerprint: 'bbbbbbbb',
              xpub: 'xpub-cold',
              derivationPath: null,
              descriptorPath: '/<0;1>/*',
            ),
          ],
        ),
      ],
      provenance: WalletProvenance.descriptor,
    );

    final decoded = codec.decode(codec.encode([definition])).single;

    expect(decoded.signers, definition.signers);
    expect(
      decoded.signerDevice,
      isNull,
      reason: 'two signers, no single device',
    );
    expect(decoded.hasRemoteSigner, isTrue);
    expect(decoded.provenance, WalletProvenance.descriptor);
  });

  test('does not write a seed reference that its reader would reject', () {
    final source = _definition('wallet', descriptor);
    final signer = source.signers.single;
    final invalid = WalletDefinition(
      walletRef: source.walletRef,
      network: source.network,
      descriptor: source.descriptor,
      provenance: source.provenance,
      signers: [
        signer.copyWith(
          signer: SignerEntity.local,
          localSeedFingerprint: 'invalid',
        ),
      ],
    );
    expect(() => codec.encode([invalid]), throwsFormatException);
  });
}

WalletDefinition _definition(String walletRef, String descriptor) =>
    WalletDefinition(
      walletRef: walletRef,
      network: Network.bitcoinMainnet,
      descriptor: descriptor,
      signers: [singleRemoteSigner(SignerDeviceEntity.ledgerNanoX)],
      birthday: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      provenance: WalletProvenance.externalSigner,
    );
