import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_input_parser.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinDescriptorPort extends Mock
    implements BitcoinDescriptorPort {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockSeedVerificationPort extends Mock implements SeedVerificationPort {}

class _MockSettings extends Mock implements SettingsEntity {}

const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';

void main() {
  late _MockBitcoinDescriptorPort descriptorPort;
  late _MockGetSettingsUsecase getSettingsUsecase;
  late _MockSeedVerificationPort seedVerification;
  late ParseWatchOnlyInputUsecase usecase;

  setUp(() {
    descriptorPort = _MockBitcoinDescriptorPort();
    getSettingsUsecase = _MockGetSettingsUsecase();
    seedVerification = _MockSeedVerificationPort();
    when(
      () => seedVerification.matchesXpubs(
        fingerprint: any(named: 'fingerprint'),
        keys: any(named: 'keys'),
      ),
    ).thenAnswer((_) async => false);
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(() => getSettingsUsecase.execute()).thenAnswer((_) async => settings);
    usecase = ParseWatchOnlyInputUsecase(
      WatchOnlyInputParser(descriptorPort),
      getSettingsUsecase,
      seedVerification,
    );
  });

  group('ParseWatchOnlyInputUsecase', () {
    test('maps raw xpub input to Bull wallet types', () async {
      final result = await usecase.execute(_xpub);

      expect(result, isA<Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyXpubEntity;
      expect(entity.extendedPublicKey, _xpub);
      expect(entity.canonicalXpub, _xpub);
      expect(entity.network, Network.bitcoinMainnet);
      expect(entity.scriptType, ScriptType.bip44);
      verifyNever(() => getSettingsUsecase.execute());
    });

    test('preserves xpub origin and supplied signer device', () async {
      final result = await usecase.execute(
        '[deadbeef/84h/0h/0h]$_xpub',
        signerDevice: SignerDeviceEntity.krux,
      );

      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyXpubEntity;
      expect(entity.canonicalXpub, _xpub);
      expect(entity.scriptType, ScriptType.bip84);
      expect(entity.masterFingerprint, 'deadbeef');
      expect(entity.derivationPath, 'm/84h/0h/0h');
      expect(entity.signer, SignerEntity.remote);
      expect(entity.signerDevice, SignerDeviceEntity.krux);
    });

    test('requires an account origin for a hardware signer xpub', () async {
      final result = await usecase.execute(
        _xpub,
        signerDevice: SignerDeviceEntity.krux,
      );

      expect(
        (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).failure,
        isA<SignerOriginRequiredFailure>(),
      );
    });

    test('requires a matching complete hardware account origin', () async {
      final seedBytes = Uint8List.fromList(
        List<int>.generate(32, (index) => index + 1),
      );
      final rootXpub = bip32.Bip32Keys.fromSeed(seedBytes).neutered.toBase58();
      final accountOneXpub = (await Bip32Derivation.getAccountXpub(
        seedBytes: seedBytes,
        scriptType: ScriptType.bip84,
        network: Network.bitcoinMainnet,
        accountIndex: 1,
      )).toBase58();

      for (final input in [
        '[deadbeef/84h/0h]$_xpub',
        '[deadbeef/84h/0h/0]$_xpub',
        '[deadbeef/84h/0h/0h]$rootXpub',
        '[deadbeef/84h/0h/0h]$accountOneXpub',
      ]) {
        final result = await usecase.execute(
          input,
          signerDevice: SignerDeviceEntity.krux,
        );

        expect(
          (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
              .failure,
          isA<InvalidFormatFailure>(),
        );
      }
    });

    test('uses the account origin for standard xpub script type', () async {
      final tpub = Bip32Derivation.getBip32Xpub(_xpub).convert(XpubType.tpub);
      final cases = [
        (
          input: "[deadbeef/49'/0'/0']$_xpub",
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip49,
        ),
        (
          input: '[deadbeef/84h/0h/0h]$_xpub',
          network: Network.bitcoinMainnet,
          scriptType: ScriptType.bip84,
        ),
        (
          input: "[deadbeef/49'/1'/0']$tpub",
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip49,
        ),
        (
          input: '[deadbeef/84h/1h/0h]$tpub',
          network: Network.bitcoinTestnet,
          scriptType: ScriptType.bip84,
        ),
      ];

      for (final testCase in cases) {
        final result = await usecase.execute(testCase.input);

        final entity =
            (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
                as WatchOnlyXpubEntity;
        expect(entity.network, testCase.network);
        expect(entity.scriptType, testCase.scriptType);
      }
    });

    test('rejects conflicting or unsupported xpub origins', () async {
      final zpub = Bip32Derivation.getBip32Xpub(_xpub).convert(XpubType.zpub);
      for (final input in [
        "[deadbeef/49'/0'/0']$zpub",
        "[deadbeef/84'/1'/0']$_xpub",
        "[deadbeef/86'/0'/0']$_xpub",
      ]) {
        final result = await usecase.execute(input);

        expect(
          result,
          isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>(),
        );
        expect(
          (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
              .failure,
          isA<InvalidFormatFailure>(),
        );
      }
    });

    test('rejects malformed xpub origins', () async {
      for (final origin in const [
        'not-an-origin',
        'deadbeef/bad-path',
        'deadbeef/84H/0H/0H',
      ]) {
        final result = await usecase.execute('[$origin]$_xpub');

        expect(
          result,
          isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>(),
        );
        expect(
          (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
              .failure,
          isA<InvalidFormatFailure>(),
        );
      }
    });

    test('recognizes a Bull key only when its account xpub matches', () async {
      const input = 'wpkh(xpub/0/*)';
      const canonical = 'wpkh(xpub/<0;1>/*)#checksum';
      const localFingerprint = '86241f88';
      const remoteFingerprint = '12345678';
      final seedBytes = Uint8List.fromList(
        List<int>.generate(32, (index) => index + 1),
      );
      final localXpub = (await Bip32Derivation.getAccountXpub(
        seedBytes: seedBytes,
        scriptType: ScriptType.bip84,
        network: Network.bitcoinMainnet,
      )).toBase58();
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenReturn((
        descriptor: canonical,
        inferredChangePath: false,
        scriptType: ScriptType.bip84,
        descriptorKeys: [
          _descriptorKey(
            masterFingerprint: localFingerprint,
            xpubFingerprint: '11111111',
            xpub: localXpub,
            derivationPath: 'm/84h/0h/0h',
          ),
          _descriptorKey(
            masterFingerprint: remoteFingerprint,
            xpubFingerprint: '22222222',
            xpub: 'xpub-remote',
          ),
        ],
      ));
      when(
        () => seedVerification.matchesXpubs(
          fingerprint: localFingerprint,
          keys: any(named: 'keys'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => seedVerification.matchesXpubs(
          fingerprint: remoteFingerprint,
          keys: any(named: 'keys'),
        ),
      ).thenAnswer((_) async => false);

      final result = await usecase.execute(
        input,
        signerDevice: SignerDeviceEntity.coldcardQ,
      );

      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyDescriptorEntity;
      expect(entity.inferredChangePath, isFalse);
      expect(entity.descriptor, canonical);
      expect(entity.scriptType, ScriptType.bip84);
      expect(entity.signers, hasLength(2));
      expect(entity.signers.first.signer, SignerEntity.local);
      expect(entity.signers.first.signerDevice, isNull);
      expect(entity.signers.last.signer, SignerEntity.remote);
      expect(entity.signers.last.signerDevice, SignerDeviceEntity.coldcardQ);
    });

    test(
      'preserves a scanned device for a locally stored higher account',
      () async {
        const input = 'wpkh(account-one/<0;1>/*)';
        const fingerprint = '86241f88';
        final seedBytes = Uint8List.fromList(
          List<int>.generate(32, (index) => index + 1),
        );
        final accountOneXpub = (await Bip32Derivation.getAccountXpub(
          seedBytes: seedBytes,
          scriptType: ScriptType.bip84,
          network: Network.bitcoinMainnet,
          accountIndex: 1,
        )).toBase58();
        when(
          () => descriptorPort.parseBitcoinDescriptor(
            descriptor: input,
            network: Network.bitcoinMainnet,
          ),
        ).thenReturn((
          descriptor: '$input#checksum',
          inferredChangePath: false,
          scriptType: ScriptType.bip84,
          descriptorKeys: [
            _descriptorKey(
              masterFingerprint: fingerprint,
              xpubFingerprint: Bip32Derivation.getBip32Xpub(
                accountOneXpub,
              ).fingerprintHex,
              xpub: accountOneXpub,
              derivationPath: 'm/84h/0h/1h',
              descriptorPath: standardSingleSignatureDescriptorPath,
            ),
          ],
        ));
        when(
          () => seedVerification.matchesXpubs(
            fingerprint: fingerprint,
            keys: any(named: 'keys'),
          ),
        ).thenAnswer((_) async => true);

        final result = await usecase.execute(
          input,
          signerDevice: SignerDeviceEntity.coldcardQ,
        );

        final entity =
            (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
                as WatchOnlyDescriptorEntity;
        expect(entity.signers.single.signer, SignerEntity.remote);
        expect(
          entity.signers.single.signerDevice,
          SignerDeviceEntity.coldcardQ,
        );
      },
    );

    test('does not trust a matching fingerprint with another xpub', () async {
      const input = 'wpkh(xpub/0/*)';
      const fingerprint = '86241f88';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenReturn((
        descriptor: 'wpkh(xpub/<0;1>/*)#checksum',
        inferredChangePath: true,
        scriptType: ScriptType.bip84,
        descriptorKeys: [
          _descriptorKey(
            masterFingerprint: fingerprint,
            xpubFingerprint: '11111111',
            xpub: _xpub,
            derivationPath: 'm/84h/0h/0h',
          ),
        ],
      ));
      when(
        () => seedVerification.matchesXpubs(
          fingerprint: fingerprint,
          keys: any(named: 'keys'),
        ),
      ).thenAnswer((_) async => false);

      final result = await usecase.execute(input);

      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyDescriptorEntity;
      expect(entity.inferredChangePath, isTrue);
      expect(entity.signers.single.signer, SignerEntity.remote);
    });

    test('applies a scanned device to a single external signer', () async {
      const input = 'wpkh(xpub/0/*)';
      const canonical = 'wpkh(xpub/<0;1>/*)#checksum';
      const fingerprint = '12345678';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenReturn((
        descriptor: canonical,
        inferredChangePath: false,
        scriptType: ScriptType.bip84,
        descriptorKeys: [
          _descriptorKey(
            masterFingerprint: fingerprint,
            xpubFingerprint: '22222222',
            xpub: 'xpub-remote',
          ),
        ],
      ));
      final result = await usecase.execute(
        input,
        signerDevice: SignerDeviceEntity.coldcardQ,
      );

      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyDescriptorEntity;
      expect(entity.signers.single.signer, SignerEntity.remote);
      expect(entity.signers.single.signerDevice, SignerDeviceEntity.coldcardQ);
    });

    test('applies one scanned device to every key for the signer', () async {
      const input = 'wsh(or_d(pk(key-a),pk(key-b)))';
      const fingerprint = '12345678';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenReturn((
        descriptor: '$input#checksum',
        inferredChangePath: false,
        scriptType: null,
        descriptorKeys: [
          _descriptorKey(
            masterFingerprint: fingerprint,
            xpubFingerprint: '11111111',
            xpub: 'xpub-first',
          ),
          _descriptorKey(
            masterFingerprint: fingerprint,
            xpubFingerprint: '22222222',
            xpub: 'xpub-second',
          ),
        ],
      ));
      final result = await usecase.execute(
        input,
        signerDevice: SignerDeviceEntity.coldcardQ,
      );

      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyDescriptorEntity;
      expect(entity.signers, hasLength(1));
      expect(
        entity.signers.map((signer) => signer.signerDevice),
        everyElement(SignerDeviceEntity.coldcardQ),
      );
    });

    test('groups mixed-origin occurrences of the same xpub', () async {
      const input = 'wsh(or_d(pk(key-a),pk(key-b)))';
      const fingerprint = '12345678';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenReturn((
        descriptor: '$input#checksum',
        inferredChangePath: false,
        scriptType: null,
        descriptorKeys: [
          _descriptorKey(
            masterFingerprint: fingerprint,
            xpubFingerprint: '11111111',
            xpub: 'xpub-shared',
            derivationPath: 'm/84h/0h/0h',
          ),
          _descriptorKey(
            masterFingerprint: '',
            xpubFingerprint: '11111111',
            xpub: 'xpub-shared',
          ),
        ],
      ));
      final result = await usecase.execute(
        input,
        signerDevice: SignerDeviceEntity.coldcardQ,
      );

      final entity =
          (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
              as WatchOnlyDescriptorEntity;
      expect(entity.signers, hasLength(1));
      expect(entity.signers.single.descriptorKeys, hasLength(2));
      expect(entity.signers.single.signerDevice, SignerDeviceEntity.coldcardQ);
    });

    test(
      'preserves an opposite-network descriptor for mismatch handling',
      () async {
        const input = 'wpkh(tpub/<0;1>/*)';
        when(
          () => descriptorPort.parseBitcoinDescriptor(
            descriptor: input,
            network: Network.bitcoinMainnet,
          ),
        ).thenThrow(const FormatException('invalid network'));
        when(
          () => descriptorPort.parseBitcoinDescriptor(
            descriptor: input,
            network: Network.bitcoinTestnet,
          ),
        ).thenReturn((
          descriptor: '$input#checksum',
          inferredChangePath: false,
          scriptType: ScriptType.bip84,
          descriptorKeys: [
            _descriptorKey(
              masterFingerprint: '',
              xpubFingerprint: '22222222',
              xpub: 'tpub-remote',
            ),
          ],
        ));

        final result = await usecase.execute(input);

        final entity =
            (result as Ok<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).value
                as WatchOnlyDescriptorEntity;
        expect(entity.network, Network.bitcoinTestnet);
      },
    );

    test('maps unparseable input to InvalidFormatFailure', () async {
      const input =
          'this is definitely not a descriptor or an extended public key';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenThrow(const FormatException('invalid descriptor'));
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinTestnet,
        ),
      ).thenThrow(const FormatException('invalid descriptor'));

      final result = await usecase.execute(input);

      expect(result, isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
      final failure =
          (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
              .failure;
      expect(failure, isA<InvalidFormatFailure>());
      expect(failure.logMessage, isNull);
    });

    test('maps settings lookup failures to ImportFailedFailure', () async {
      when(
        () => getSettingsUsecase.execute(),
      ).thenThrow(const FormatException('settings unavailable'));

      final result = await usecase.execute('wpkh(xpub/<0;1>/*)');

      expect(result, isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
      expect(
        (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).failure,
        isA<ImportFailedFailure>(),
      );
    });

    test('maps seed verification failures to ImportFailedFailure', () async {
      const input = 'wpkh(xpub/<0;1>/*)';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenReturn((
        descriptor: '$input#checksum',
        inferredChangePath: false,
        scriptType: ScriptType.bip84,
        descriptorKeys: [
          _descriptorKey(
            masterFingerprint: '12345678',
            xpubFingerprint: '12345678',
            xpub: _xpub,
            derivationPath: 'm/84h/0h/0h',
          ),
        ],
      ));
      when(
        () => seedVerification.matchesXpubs(
          fingerprint: '12345678',
          keys: any(named: 'keys'),
        ),
      ).thenThrow(const FormatException('seed storage unavailable'));

      final result = await usecase.execute(input);

      expect(result, isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
      expect(
        (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>).failure,
        isA<ImportFailedFailure>(),
      );
    });

    test('maps fixed public keys to their unsupported failure', () async {
      const fixedPublicKey =
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
      const input = 'wsh(sortedmulti(2,$_xpub/<0;1>/*,$fixedPublicKey))';
      when(
        () => descriptorPort.parseBitcoinDescriptor(
          descriptor: input,
          network: Network.bitcoinMainnet,
        ),
      ).thenThrow(const UnsupportedFixedPublicKeyDescriptorException());

      final result = await usecase.execute(input);

      expect(result, isA<Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>>());
      final failure =
          (result as Err<WatchOnlyWalletEntity, ImportWatchOnlyFailure>)
              .failure;
      expect(failure, isA<FixedPublicKeyUnsupportedFailure>());
      expect(failure.logMessage, isNull);
    });
  });
}

WalletDescriptorKey _descriptorKey({
  required String masterFingerprint,
  required String xpubFingerprint,
  required String xpub,
  String? derivationPath,
  String descriptorPath = '',
}) => WalletDescriptorKey(
  id: 'key-$xpubFingerprint',
  signerId: 'unassigned-$xpubFingerprint',
  masterFingerprint: masterFingerprint,
  xpubFingerprint: xpubFingerprint,
  xpub: xpub,
  derivationPath: derivationPath,
  descriptorPath: descriptorPath,
);
