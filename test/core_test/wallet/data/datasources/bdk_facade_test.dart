import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

import '../../bdk_wallet_test_fixture.dart';

const _mainnetXpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

void main() {
  late List<SignerDescriptorKeys> signers;

  setUpAll(() {
    signers = testMnemonics.map(deriveSignerKeys).toList();
  });

  group('BdkFacade two-path descriptors', () {
    test(
      'expands a conventional external descriptor to receive and change',
      () {
        final descriptor = singleSignatureDescriptors(
          testMnemonics.first,
        ).external;

        final parsed = BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        );

        expect(parsed.descriptor, contains('/<0;1>/*'));
        expect(parsed.inferredChangePath, isTrue);
        expect(parsed.externalDescriptor, contains('/0/*'));
        expect(parsed.internalDescriptor, contains('/1/*'));
        expect(parsed.scriptType, ScriptType.bip84);
        expect(parsed.keys, hasLength(1));
        expect(parsed.keys.single.masterFingerprint, isNotEmpty);
        expect(parsed.keys.single.derivationPath, "m/84'/1'/0'");
      },
    );

    test(
      'rejects a stale checksum before expanding an external descriptor',
      () {
        final descriptor = singleSignatureDescriptors(
          testMnemonics.first,
        ).external.replaceFirst("/84'/1'/0'", "/84'/1'/1'");

        expect(
          () => BdkFacade.parsePublicTwoPathDescriptor(
            descriptor: descriptor,
            isTestnet: true,
          ),
          throwsA(isA<bdk.InvalidDescriptorChecksumDescriptorException>()),
        );
      },
    );

    test('rejects a stale checksum on an explicit multipath descriptor', () {
      final external = singleSignatureDescriptors(
        testMnemonics.first,
      ).external.split('#').first;
      final parsed = bdk.Descriptor(
        descriptor: external.replaceFirst('/0/*', '/<0;1>/*'),
        networkKind: bdk.NetworkKind.test,
      );
      final descriptor = parsed.toString().replaceFirst('<0;1>', '<0;2>');
      parsed.dispose();

      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        ),
        throwsA(isA<bdk.InvalidDescriptorChecksumDescriptorException>()),
      );
    });

    test('rejects descriptors containing private keys', () {
      final descriptor = 'wpkh(${signers.first.externalPrivate})';

      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        ),
        throwsA(isA<bdk.DescriptorException>()),
      );
    });

    test('rejects multipath descriptors without a wildcard', () {
      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: 'wpkh($_mainnetXpub/<0;1>)',
          isTestnet: false,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects extended public keys from another network', () {
      final mismatches = [
        (
          network: 'mainnet',
          isTestnet: false,
          extendedPublicKey: signers.first.xpub,
        ),
        (network: 'testnet', isTestnet: true, extendedPublicKey: _mainnetXpub),
      ];

      for (final mismatch in mismatches) {
        expect(
          () => BdkFacade.parsePublicTwoPathDescriptor(
            descriptor: 'wpkh(${mismatch.extendedPublicKey}/0/*)',
            isTestnet: mismatch.isTestnet,
          ),
          throwsA(isA<bdk.DescriptorException>()),
          reason: '${mismatch.network} must reject the other network key',
        );
      }
    });

    test('accepts apostrophe and h hardened origin notation', () {
      final apostropheDescriptor = singleSignatureDescriptors(
        testMnemonics.first,
      ).external.split('#').first;
      final hDescriptor = apostropheDescriptor.replaceAll("'", 'h');

      final apostrophe = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: apostropheDescriptor,
        isTestnet: true,
      );
      final h = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: hDescriptor,
        isTestnet: true,
      );

      expect(apostrophe.keys.single.derivationPath, "m/84'/1'/0'");
      expect(h.keys.single.derivationPath, "m/84'/1'/0'");
    });

    test('uses the same script identity with or without key origins', () {
      final descriptors = singleSignatureDescriptors(testMnemonics.first);
      final withOrigin = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptors.external,
        isTestnet: true,
      );
      final withoutOrigin = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: 'wpkh(${descriptors.xpub}/0/*)',
        isTestnet: true,
      );

      expect(withOrigin.scriptIdentity, withoutOrigin.scriptIdentity);
    });

    test('uses the same script identity when keychain roles are reversed', () {
      final xpub = singleSignatureDescriptors(testMnemonics.first).xpub;
      final conventional = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: 'wpkh($xpub/<0;1>/*)',
        isTestnet: true,
      );
      final reversed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: 'wpkh($xpub/<1;0>/*)',
        isTestnet: true,
      );

      expect(
        conventional.externalDescriptor,
        isNot(reversed.externalDescriptor),
      );
      expect(
        conventional.internalDescriptor,
        isNot(reversed.internalDescriptor),
      );
      expect(conventional.scriptIdentity, reversed.scriptIdentity);
    });

    test('accepts different two-path branches in one descriptor', () {
      final conventionalKey = signers.first.externalPublic.replaceAll(
        '/0/*',
        '/0/<0;1>/*',
      );
      final recoveryKey = signers.first.externalPublic.replaceAll(
        '/0/*',
        '/1/<0;1>/*',
      );
      final descriptor =
          'wsh(or_d(pk($conventionalKey),and_v(v:older(10),pk($recoveryKey))))';

      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      );

      expect(parsed.keys, hasLength(2));
      expect(parsed.keys.map((key) => key.descriptorPath), {
        '/0/<0;1>/*',
        '/1/<0;1>/*',
      });
      expect(parsed.externalDescriptor, contains('/0/0/*'));
      expect(parsed.externalDescriptor, contains('/1/0/*'));
      expect(parsed.internalDescriptor, contains('/0/1/*'));
      expect(parsed.internalDescriptor, contains('/1/1/*'));
      expect(parsed.inferredChangePath, isFalse);
    });

    test('rejects multipath descriptors with more than two paths', () {
      final key = signers.first.externalPublic.replaceAll('/0/*', '/<0;1;2>/*');

      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: 'wpkh($key)',
          isTestnet: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts two-path Miniscript policies', () {
      final firstKey = signers[0].externalPublic.replaceAll('/0/*', '/<0;1>/*');
      final secondKey = signers[1].externalPublic.replaceAll(
        '/0/*',
        '/<0;1>/*',
      );
      final descriptor =
          'wsh(or_d(pk($firstKey),and_v(v:older(10),pk($secondKey))))';

      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: descriptor,
        isTestnet: true,
      );

      expect(parsed.externalDescriptor, contains('/0/*'));
      expect(parsed.internalDescriptor, contains('/1/*'));
      expect(parsed.inferredChangePath, isFalse);
      expect(parsed.scriptType, isNull);
      expect(parsed.keys, hasLength(2));
    });

    test('does not interpret hashlock digests as descriptor keys', () {
      final key = signers.first.externalPublic.replaceAll('/0/*', '/<0;1>/*');
      const digest =
          '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';

      final parsed = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: 'wsh(and_v(v:pk($key),sha256($digest)))',
        isTestnet: true,
      );

      expect(parsed.keys, hasLength(1));
      expect(parsed.keys.single.xpub, signers.first.xpub.split(']').last);
    });

    test('rejects Taproot descriptors explicitly', () {
      final descriptor = bdk.Descriptor.newTr(
        key: signers.first.externalPublic,
        script: null,
      ).toString();

      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        ),
        throwsA(isA<UnsupportedTaprootDescriptorException>()),
      );
    });

    test('rejects descriptors mixing extended and fixed public keys', () {
      const fixedPublicKey =
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
      final extendedPublicKey = signers.first.externalPublic.replaceAll(
        '/0/*',
        '/<0;1>/*',
      );
      final descriptor =
          'wsh(sortedmulti(2,$extendedPublicKey,$fixedPublicKey))';

      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        ),
        throwsA(isA<UnsupportedFixedPublicKeyDescriptorException>()),
      );
    });

    test('accepts legacy and nested SegWit descriptors', () {
      final key = signers.first.externalPublic;

      final legacy = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: 'pkh($key)',
        isTestnet: true,
      );
      final nestedSegwit = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: 'sh(wpkh($key))',
        isTestnet: true,
      );

      expect(legacy.scriptType, ScriptType.bip44);
      expect(nestedSegwit.scriptType, ScriptType.bip49);
    });

    test('does not infer change from arbitrary derivation indexes', () {
      final descriptor = singleSignatureDescriptors(
        testMnemonics.first,
      ).external.split('#').first.replaceAll('/0/*', '/2/*');

      expect(
        () => BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: descriptor,
          isTestnet: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects receive and change descriptors from different wallets', () {
      final receive = singleSignatureDescriptors(testMnemonics.first).external;
      final change = singleSignatureDescriptors(testMnemonics.last).internal;

      expect(
        () => BdkFacade.combinePublicDescriptorPair(
          externalDescriptor: receive,
          internalDescriptor: change,
          isTestnet: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
