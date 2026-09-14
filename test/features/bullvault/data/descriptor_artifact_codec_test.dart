import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_artifact_codec.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bip138_prototype_fixture.dart';

/// A public synthetic 32-byte key. The credential that produces the real one
/// lives in `nostr_identity`; this codec only ever sees bytes.
final _key = Uint8List.fromList(
  hex.decode(
    '301375cfd80649921db2be0ad3bb812460bf9a712a256de81704f909f84907f3',
  ),
);
final _otherKey = Uint8List.fromList(List.filled(32, 7));

void main() {
  final descriptor = Bip138PrototypeFixture().descriptor();
  const encryption = RecoverBullEncryption();

  test('an artifact survives encryption and decryption unchanged', () async {
    final artifact = DescriptorArtifact(
      network: 'testnet4',
      descriptor: descriptor,
    );

    final sealed = await encryption.encrypt(_key, artifact.encode());
    final opened = DescriptorArtifact.decode(
      await encryption.decrypt(_key, sealed),
    );

    expect(opened.descriptor, descriptor);
    expect(opened.network, 'testnet4');
    expect(sealed, isNot(orderedEquals(artifact.encode())));
  });

  test('two sealings of the same artifact differ', () async {
    final artifact = DescriptorArtifact(
      network: 'testnet4',
      descriptor: descriptor,
    );

    expect(
      await encryption.encrypt(_key, artifact.encode()),
      isNot(orderedEquals(await encryption.encrypt(_key, artifact.encode()))),
      reason: 'a fresh nonce per sealing',
    );
  });

  test('another key opens nothing', () async {
    final sealed = await encryption.encrypt(
      _key,
      DescriptorArtifact(network: 'bitcoin', descriptor: descriptor).encode(),
    );

    expect(
      () => encryption.decrypt(_otherKey, sealed),
      throwsA(isA<RecoverBullEncryptionException>()),
    );
  });

  test('the frame carries the descriptor, its network and nothing else', () {
    final artifact = DescriptorArtifact(
      network: 'regtest',
      descriptor: descriptor,
    );

    final json =
        jsonDecode(utf8.decode(gzip.decode(artifact.encode())))
            as Map<String, dynamic>;

    expect(json.keys, ['format', 'kind', 'network', 'contents']);
    expect(json['format'], DescriptorArtifact.profile);
    expect(json['kind'], 'vault');
    expect(json['contents'], descriptor);
  });

  test('a compressed expansion bomb is refused', () {
    final bomb = Uint8List.fromList(
      gzip.encode(List.filled(DescriptorArtifact.maxBytes + 1, 32)),
    );

    expect(bomb.length, lessThan(2000));
    expect(() => DescriptorArtifact.decode(bomb), throwsFormatException);
  });

  test('a foreign profile, kind or shape is refused', () {
    for (final change in [
      {'format': 'future-profile'},
      {'kind': 'metadata'},
      {'kind': 'seed'},
      {'contents': 12},
      {'network': 'mainnet'},
      {'contents': ''},
    ]) {
      final compressed = Uint8List.fromList(
        gzip.encode(
          utf8.encode(
            jsonEncode({
              'format': DescriptorArtifact.profile,
              'kind': 'vault',
              'network': 'testnet4',
              'contents': descriptor,
              ...change,
            }),
          ),
        ),
      );

      expect(
        () => DescriptorArtifact.decode(compressed),
        throwsFormatException,
        reason: '$change',
      );
    }
  });

  test('an artifact validates itself at construction', () {
    expect(
      () => DescriptorArtifact(network: 'unknown', descriptor: descriptor),
      throwsFormatException,
    );
    expect(
      () => DescriptorArtifact(network: 'bitcoin', descriptor: ''),
      throwsFormatException,
    );
    expect(
      () => DescriptorArtifact(
        network: 'bitcoin',
        descriptor: 'x' * (DescriptorArtifact.maxDescriptorLength + 1),
      ),
      throwsFormatException,
    );
  });
}
