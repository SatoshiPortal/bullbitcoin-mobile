import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/adapters/trezor_device_repository_impl.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/frameworks/framework_errors.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trezor_connect/models.dart';
import 'package:trezor_connect/trezor_connect.dart' show TrezorLaunchException;

class _MockDatasource extends Mock implements TrezorConnectDatasource {}

TrezorAddressPublicKey _fakeAccount({
  String? descriptor,
  String xpub = 'xpub6FAKE...',
  int accountIndexHardened = 0x80000000, // account 0
}) => TrezorAddressPublicKey.fromJson({
  'path': [
    0x80000054, // 84'
    0x80000000, // 0'
    accountIndexHardened,
  ],
  'serializedPath': "m/84'/0'/0'",
  'xpub': xpub,
  'xpubSegwit': null, // nullable, can be null
  'chainCode': 'fake_chain_code', // any non-null String
  'childNum': 0,
  'publicKey': 'fake_public_key', // any non-null String
  'fingerprint': 0,
  'depth': 3,
  'descriptor': descriptor, // nullable; passing null is the
});

void main() {
  setUpAll(() {
    registerFallbackValue(ScriptType.bip84);
  });

  late _MockDatasource datasource;
  late TrezorDeviceRepositoryImpl repo;

  setUp(() {
    datasource = _MockDatasource();
    repo = TrezorDeviceRepositoryImpl(datasource: datasource);
  });

  group('verifyAddress', () {
    test('returns true on successful verification', () async {
      when(
        () => datasource.verifyAddress(
          address: any(named: 'address'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => true);

      final ok = await repo.verifyAddress(
        address: 'bc1qaaaaa',
        derivationPath: "m/84'/0'/0'/0/0",
        scriptType: ScriptType.bip84,
        isTestnet: false,
      );
      expect(ok, isTrue);
    });

    test(
      'maps TrezorAddressMismatchException to TrezorAddressMismatch',
      () async {
        when(
          () => datasource.verifyAddress(
            address: any(named: 'address'),
            derivationPath: any(named: 'derivationPath'),
            scriptType: any(named: 'scriptType'),
            isTestnet: any(named: 'isTestnet'),
          ),
        ).thenThrow(
          const TrezorAddressMismatchException(
            expected: 'bc1qexpected',
            returned: 'bc1qreturned',
          ),
        );

        expect(
          () => repo.verifyAddress(
            address: 'bc1qexpected',
            derivationPath: "m/84'/0'/0'/0/0",
            scriptType: ScriptType.bip84,
            isTestnet: false,
          ),
          throwsA(
            isA<TrezorAddressMismatch>()
                .having((e) => e.expected, 'expected', 'bc1qexpected')
                .having((e) => e.returned, 'returned', 'bc1qreturned'),
          ),
        );
      },
    );
  });

  group('getDefaultAccount — master fingerprint', () {
    test('extracts master fingerprint per-account from descriptor', () async {
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer(
        (_) async => [
          _fakeAccount(
            descriptor:
                'wpkh([4126b8c0/84h/0h/0h]xpub6C7M.../<0;1>/*)#2qrhcvp5',
          ),
        ],
      );

      final account = await repo.getDefaultAccount(
        scriptType: ScriptType.bip84,
        isTestnet: false,
      );
      expect(account.masterFingerprint, '4126b8c0');
    });

    test('does not share fingerprint across separate device sessions '
        '(regression: review #2 cross-device pollution)', () async {
      // First device returns fingerprint AAAAAAAA
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer(
        (_) async => [
          _fakeAccount(
            descriptor: 'wpkh([aaaaaaaa/84h/0h/0h]xpubA.../<0;1>/*)#csum',
          ),
        ],
      );
      final first = await repo.getDefaultAccount(
        scriptType: ScriptType.bip84,
        isTestnet: false,
      );
      expect(first.masterFingerprint, 'aaaaaaaa');

      // Second device returns fingerprint BBBBBBBB — must NOT leak
      // the first fingerprint into the second account.
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer(
        (_) async => [
          _fakeAccount(
            descriptor: 'wpkh([bbbbbbbb/84h/0h/0h]xpubB.../<0;1>/*)#csum',
          ),
        ],
      );
      final second = await repo.getDefaultAccount(
        scriptType: ScriptType.bip84,
        isTestnet: false,
      );
      expect(second.masterFingerprint, 'bbbbbbbb');
      expect(second.masterFingerprint, isNot('aaaaaaaa'));
    });

    test('throws TrezorMissingDescriptor when descriptor is null '
        '(regression: review #5 Model One)', () async {
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((_) async => [_fakeAccount(descriptor: null)]);

      expect(
        () => repo.getDefaultAccount(
          scriptType: ScriptType.bip84,
          isTestnet: false,
        ),
        throwsA(isA<TrezorMissingDescriptor>()),
      );
    });

    test(
      'throws TrezorMissingDescriptor when descriptor is malformed',
      () async {
        when(
          () => datasource.getPublicKeyBundle(
            any(),
            isTestnet: any(named: 'isTestnet'),
          ),
        ).thenAnswer(
          (_) async => [
            _fakeAccount(descriptor: 'this-is-not-a-bip380-descriptor'),
          ],
        );

        expect(
          () => repo.getDefaultAccount(
            scriptType: ScriptType.bip84,
            isTestnet: false,
          ),
          throwsA(isA<TrezorMissingDescriptor>()),
        );
      },
    );
  });

  group('getDefaultAccount — network threading', () {
    test('builds mainnet path with coin-type 0 when not isTestnet', () async {
      final capturedPaths = <List<String>>[];
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((invocation) async {
        capturedPaths.add(invocation.positionalArguments[0] as List<String>);
        return [
          _fakeAccount(
            descriptor: 'wpkh([aaaaaaaa/84h/0h/0h]xpub.../<0;1>/*)#csum',
          ),
        ];
      });

      await repo.getDefaultAccount(
        scriptType: ScriptType.bip84,
        isTestnet: false,
      );

      expect(capturedPaths.single, equals(["m/84'/0'/0'"]));
    });

    test('builds testnet path with coin-type 1 when isTestnet', () async {
      final capturedPaths = <List<String>>[];
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((invocation) async {
        capturedPaths.add(invocation.positionalArguments[0] as List<String>);
        return [
          _fakeAccount(
            descriptor: 'wpkh([aaaaaaaa/84h/1h/0h]vpub.../<0;1>/*)#csum',
          ),
        ];
      });

      await repo.getDefaultAccount(
        scriptType: ScriptType.bip84,
        isTestnet: true,
      );

      expect(capturedPaths.single, equals(["m/84'/1'/0'"]));
    });

    test('passes isTestnet through to the datasource', () async {
      final capturedFlags = <bool>[];
      when(
        () => datasource.getPublicKeyBundle(
          any(),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenAnswer((invocation) async {
        capturedFlags.add(invocation.namedArguments[#isTestnet] as bool);
        return [
          _fakeAccount(
            descriptor: 'wpkh([aaaaaaaa/84h/1h/0h]vpub.../<0;1>/*)#csum',
          ),
        ];
      });

      await repo.getDefaultAccount(
        scriptType: ScriptType.bip84,
        isTestnet: true,
      );

      expect(capturedFlags.single, isTrue);
    });
  });

  group('_mapError classification', () {
    test('"user rejected" string → TrezorUserRejected', () async {
      when(
        () => datasource.verifyAddress(
          address: any(named: 'address'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenThrow(Exception('User rejected request'));

      expect(
        () => repo.verifyAddress(
          address: 'bc1q',
          derivationPath: 'm',
          scriptType: ScriptType.bip84,
          isTestnet: false,
        ),
        throwsA(isA<TrezorUserRejected>()),
      );
    });

    test('TrezorLaunchException → TrezorSuiteNotInstalled '
        '(regression: review #12 fast-fail on launch failure)', () async {
      when(
        () => datasource.verifyAddress(
          address: any(named: 'address'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenThrow(const TrezorLaunchException());

      expect(
        () => repo.verifyAddress(
          address: 'bc1q',
          derivationPath: 'm',
          scriptType: ScriptType.bip84,
          isTestnet: false,
        ),
        throwsA(isA<TrezorSuiteNotInstalled>()),
      );
    });

    test('"not installed" string → TrezorSuiteNotInstalled', () async {
      when(
        () => datasource.verifyAddress(
          address: any(named: 'address'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
          isTestnet: any(named: 'isTestnet'),
        ),
      ).thenThrow(Exception('Trezor Suite is not installed'));

      expect(
        () => repo.verifyAddress(
          address: 'bc1q',
          derivationPath: 'm',
          scriptType: ScriptType.bip84,
          isTestnet: false,
        ),
        throwsA(isA<TrezorSuiteNotInstalled>()),
      );
    });

    test(
      'unrecognized exception → TrezorUnknown with original message',
      () async {
        when(
          () => datasource.verifyAddress(
            address: any(named: 'address'),
            derivationPath: any(named: 'derivationPath'),
            scriptType: any(named: 'scriptType'),
            isTestnet: any(named: 'isTestnet'),
          ),
        ).thenThrow(Exception('something unexpected happened'));

        expect(
          () => repo.verifyAddress(
            address: 'bc1q',
            derivationPath: 'm',
            scriptType: ScriptType.bip84,
            isTestnet: false,
          ),
          throwsA(
            isA<TrezorUnknown>().having(
              (e) => e.message,
              'message',
              contains('something unexpected happened'),
            ),
          ),
        );
      },
    );
  });
}
