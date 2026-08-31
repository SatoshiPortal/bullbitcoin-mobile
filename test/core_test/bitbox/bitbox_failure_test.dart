import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/data/repositories/bitbox_device_repository_impl.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/get_bitbox_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/get_bitbox_account_key_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/pair_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/sign_psbt_bitbox_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/unlock_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/verify_address_bitbox_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements BitBoxDeviceDatasource {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

const _device = BitBoxDeviceEntity(
  deviceName: 'BitBox02',
  serialNumber: '0001',
  product: 'bitbox02',
  connectionType: BitBoxConnectionType.usb,
);

SettingsEntity _mainnetSettings() => const SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);

void main() {
  group('BitBoxDeviceRepositoryImpl (data boundary)', () {
    late _MockDatasource datasource;
    late BitBoxDeviceRepositoryImpl repository;

    setUpAll(() {
      registerFallbackValue(_device.toModel());
    });

    setUp(() {
      datasource = _MockDatasource();
      repository = BitBoxDeviceRepositoryImpl(datasource: datasource);
    });

    test(
      'maps a raw thrown exception to BitBoxUnexpectedFailure — no raw leak',
      () async {
        when(
          () => datasource.getMasterFingerprint(any()),
        ).thenThrow(Exception('SECRET raw SDK internals'));

        final result = await repository.getMasterFingerprint(_device);

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<BitBoxUnexpectedFailure>());
      },
    );

    test('passes through a semantic BitBoxFailure unchanged', () async {
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenThrow(const PermissionDeniedBitBoxFailure());

      final result = await repository.getMasterFingerprint(_device);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<PermissionDeniedBitBoxFailure>());
    });

    test('returns Ok on success', () async {
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'aabbccdd');

      final result = await repository.getMasterFingerprint(_device);

      expect(result, isA<Ok>());
      expect((result as Ok).value, 'aabbccdd');
    });

    test('requires the fingerprint and account xpub to match', () async {
      final wallet = _policyWallet(SignerDeviceEntity.bitbox02);
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'aabbccdd');
      when(
        () => datasource.getWalletPolicyXpub(
          any(),
          derivationPath: _accountPath,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => _otherXpub);

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<WalletSignerMismatchBitBoxFailure>());
      verifyNever(
        () => datasource.isWalletPolicyRegistered(
          any(),
          descriptor: any(named: 'descriptor'),
          isTestnet: any(named: 'isTestnet'),
        ),
      );
    });

    test(
      'registers an unregistered policy after matching its signer',
      () async {
        final wallet = _policyWallet(SignerDeviceEntity.bitbox02);
        when(
          () => datasource.getMasterFingerprint(any()),
        ).thenAnswer((_) async => 'aabbccdd');
        when(
          () => datasource.getWalletPolicyXpub(
            any(),
            derivationPath: _accountPath,
            isTestnet: false,
          ),
        ).thenAnswer((_) async => _xpub);
        when(
          () => datasource.isWalletPolicyRegistered(
            any(),
            descriptor: wallet.publicDescriptor,
            isTestnet: false,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => datasource.registerWalletPolicy(
            any(),
            descriptor: wallet.publicDescriptor,
            isTestnet: false,
            name: 'Policy wallet wallet-i',
          ),
        ).thenAnswer((_) async {});

        final result = await repository.registerWalletPolicy(
          _device,
          wallet: wallet,
        );

        expect(result, isA<Ok>());
        verify(
          () => datasource.registerWalletPolicy(
            any(),
            descriptor: wallet.publicDescriptor,
            isTestnet: false,
            name: 'Policy wallet wallet-i',
          ),
        ).called(1);
      },
    );

    test('rejects multisig with two keys assigned to one BitBox', () async {
      final wallet = _multiKeyPolicyWallet();
      final secondPath = "m/48'/0'/1'/2'";
      final secondXpub = Bip32Derivation.getBip32Xpub(_otherXpub).toBase58();
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'aabbccdd');
      when(
        () => datasource.getWalletPolicyXpub(
          any(),
          derivationPath: _accountPath,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => _xpub);
      when(
        () => datasource.getWalletPolicyXpub(
          any(),
          derivationPath: secondPath,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => secondXpub);

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(result, isA<Err>());
      expect(
        (result as Err).failure,
        isA<UnsupportedWalletPolicyBitBoxFailure>(),
      );
      verifyNever(
        () => datasource.isWalletPolicyRegistered(
          any(),
          descriptor: any(named: 'descriptor'),
          isTestnet: any(named: 'isTestnet'),
        ),
      );
    });

    test('accepts disjoint policy roles for one BitBox account key', () async {
      final wallet = _disjointRolePolicyWallet(SignerDeviceEntity.bitbox02);
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'aabbccdd');
      when(
        () => datasource.getWalletPolicyXpub(
          any(),
          derivationPath: _accountPath,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => _xpub);
      when(
        () => datasource.isWalletPolicyRegistered(
          any(),
          descriptor: wallet.publicDescriptor,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => true);

      final result = await repository.registerWalletPolicy(
        _device,
        wallet: wallet,
      );

      expect(wallet.supportsWalletPolicySigner(wallet.signers.single), isTrue);
      expect(result, isA<Ok>());
    });

    test('rejects a wallet-policy address mismatch', () async {
      final wallet = _policyWallet(SignerDeviceEntity.bitbox02);
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'aabbccdd');
      when(
        () => datasource.getWalletPolicyXpub(
          any(),
          derivationPath: _accountPath,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => _xpub);
      when(
        () => datasource.isWalletPolicyRegistered(
          any(),
          descriptor: wallet.publicDescriptor,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => true);
      when(
        () => datasource.verifyWalletAddress(
          any(),
          descriptor: wallet.publicDescriptor,
          isTestnet: false,
          keychain: BitcoinPolicyKeychain.external,
          index: 4,
        ),
      ).thenAnswer((_) async => 'bc1qwrong');

      final result = await repository.verifyWalletAddress(
        _device,
        wallet: wallet,
        address: 'bc1qexpected',
        keychain: BitcoinPolicyKeychain.external,
        index: 4,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<AddressMismatchBitBoxFailure>());
    });
  });

  group('SignPsbtBitBoxUsecase (settings boundary)', () {
    test(
      'maps a throwing settings fetch to a sanitized failure — no raw leak',
      () async {
        final repo = _MockRepository();
        final settings = _MockSettingsRepository();
        final usecase = SignPsbtBitBoxUsecase(
          repository: repo,
          settingsRepository: settings,
        );
        when(() => settings.fetch()).thenThrow(Exception('boom'));

        final result = await usecase.execute(
          _device,
          psbt: 'psbt',
          derivationPath: "m/84'/0'/0'",
          scriptType: ScriptType.bip84,
        );

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<BitBoxUnexpectedFailure>());
      },
    );
  });

  group('ConnectBitBoxDeviceUsecase', () {
    test('propagates the sanitized failure from the repository', () async {
      final repo = _MockRepository();
      final usecase = ConnectBitBoxDeviceUsecase(repository: repo);
      when(
        () => repo.connectDevice(_device),
      ).thenAnswer((_) async => const Err(ConnectionFailedBitBoxFailure()));

      final result = await usecase.execute(_device);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ConnectionFailedBitBoxFailure>());
    });
  });

  group('UnlockBitBoxDeviceUsecase', () {
    test('propagates the sanitized failure from the repository', () async {
      final repo = _MockRepository();
      final usecase = UnlockBitBoxDeviceUsecase(repository: repo);
      when(
        () => repo.unlockDevice(_device),
      ).thenAnswer((_) async => const Err(OperationTimeoutBitBoxFailure()));

      final result = await usecase.execute(_device);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<OperationTimeoutBitBoxFailure>());
    });
  });

  group('PairBitBoxDeviceUsecase', () {
    test('propagates the sanitized failure from the repository', () async {
      final repo = _MockRepository();
      final usecase = PairBitBoxDeviceUsecase(repository: repo);
      when(
        () => repo.pairDevice(_device),
      ).thenAnswer((_) async => const Err(OperationCancelledBitBoxFailure()));

      final result = await usecase.execute(_device);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<OperationCancelledBitBoxFailure>());
    });
  });

  group('VerifyAddressBitBoxUsecase', () {
    test('maps an address mismatch to InvalidResponse', () async {
      final repo = _MockRepository();
      final settings = _MockSettingsRepository();
      when(() => settings.fetch()).thenAnswer((_) async => _mainnetSettings());
      when(
        () => repo.verifyAddress(
          _device,
          address: 'bc1qexpected',
          derivationPath: "m/84'/0'/0'",
          scriptType: ScriptType.bip84,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => const Ok(false));
      final usecase = VerifyAddressBitBoxUsecase(
        repository: repo,
        settingsRepository: settings,
      );

      final result = await usecase.execute(
        device: _device,
        address: 'bc1qexpected',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<InvalidResponseBitBoxFailure>());
    });
  });

  group('GetBitBoxWatchOnlyWalletUsecase', () {
    test(
      'maps a throwing settings fetch to a sanitized failure — no raw leak',
      () async {
        final settings = _MockSettingsRepository();
        final usecase = GetBitBoxWatchOnlyWalletUsecase(
          repository: _MockRepository(),
          settingsRepository: settings,
        );
        when(() => settings.fetch()).thenThrow(Exception('boom'));

        final result = await usecase.execute(label: 'wallet', device: _device);

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<BitBoxUnexpectedFailure>());
      },
    );
  });

  test('reads the requested account key with its verified origin', () async {
    const path = "m/48'/1'/0'/2'";
    final repository = _MockRepository();
    final usecase = GetBitBoxAccountKeyUsecase(repository);
    when(
      () => repository.getMasterFingerprint(_device),
    ).thenAnswer((_) async => const Ok('AABBCCDD'));
    when(
      () => repository.getXpub(
        _device,
        derivationPath: path,
        scriptType: ScriptType.bip44,
        isTestnet: true,
      ),
    ).thenAnswer((_) async => const Ok(_otherXpub));

    final result = await usecase.execute(
      device: _device,
      derivationPath: path,
      isTestnet: true,
    );

    expect(result, isA<Ok>());
    expect((result as Ok).value, '[aabbccdd/48\'/1\'/0\'/2\']$_otherXpub');
  });

  group('ScanBitBoxDevicesUsecase', () {
    test('maps an empty scan to NoDevicesFoundBitBoxFailure', () async {
      final repo = _MockRepository();
      final usecase = ScanBitBoxDevicesUsecase(repository: repo);
      when(() => repo.scanDevices()).thenAnswer((_) async => const Ok([]));

      final result = await usecase.execute();

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<NoDevicesFoundBitBoxFailure>());
    });

    test('returns the devices when the scan is non-empty', () async {
      final repo = _MockRepository();
      final usecase = ScanBitBoxDevicesUsecase(repository: repo);
      when(
        () => repo.scanDevices(),
      ).thenAnswer((_) async => const Ok([_device]));

      final result = await usecase.execute();

      expect(result, isA<Ok>());
      expect((result as Ok).value, [_device]);
    });
  });
}

const _accountPath = "m/48'/0'/0'/2'";
const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
const _otherXpub =
    'tpubDFH9dgzveyD8zTbPUFuLrGmCydNvxehyNdUXKJAQN8x4aZ4j6UZqGfnqFrD4NqyaTVGKbvEW54tsvPTK2UoSbCC1PJY8iCNiwTL3RWZEheQ';

Wallet _policyWallet(SignerDeviceEntity device) {
  const key = '[aabbccdd/48\'/0\'/0\'/2\']$_xpub/<0;1>/*';
  return Wallet(
    origin: 'wallet-id',
    label: 'Policy wallet',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner.single(
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: '',
        xpub: _xpub,
        derivationPath: _accountPath,
        signer: SignerEntity.remote,
        signerDevice: device,
      ),
    ],
    scriptType: null,
    publicDescriptor: 'wsh(pk($key))',
    balanceSat: BigInt.zero,
  );
}

Wallet _multiKeyPolicyWallet() {
  final secondXpub = Bip32Derivation.getBip32Xpub(_otherXpub).toBase58();
  const secondPath = "m/48'/0'/1'/2'";
  final keys = [
    WalletDescriptorKey(
      id: 'key-0',
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '',
      xpub: _xpub,
      derivationPath: _accountPath,
    ),
    WalletDescriptorKey(
      id: 'key-1',
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '',
      xpub: secondXpub,
      derivationPath: secondPath,
    ),
  ];
  final descriptorKeys = keys
      .map(
        (key) =>
            '[${key.masterFingerprint}/${key.derivationPath!.substring(2)}]'
            '${key.xpub}/<0;1>/*',
      )
      .join(',');
  return Wallet(
    origin: 'wallet-id',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner(
        id: 'signer-0',
        signer: SignerEntity.remote,
        signerDevice: SignerDeviceEntity.bitbox02,
        descriptorKeys: keys,
      ),
    ],
    scriptType: null,
    publicDescriptor: 'wsh(sortedmulti(1,$descriptorKeys))',
    balanceSat: BigInt.zero,
  );
}

Wallet _disjointRolePolicyWallet(SignerDeviceEntity device) {
  const origin = '[aabbccdd/48\'/0\'/0\'/2\']$_xpub';
  final keys = [
    WalletDescriptorKey(
      id: 'key-0',
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '',
      xpub: _xpub,
      derivationPath: _accountPath,
      descriptorPath: '/<0;1>/*',
    ),
    WalletDescriptorKey(
      id: 'key-1',
      signerId: 'signer-0',
      masterFingerprint: 'aabbccdd',
      xpubFingerprint: '',
      xpub: _xpub,
      derivationPath: _accountPath,
      descriptorPath: '/<2;3>/*',
    ),
  ];
  return Wallet(
    origin: 'wallet-id',
    network: Network.bitcoinMainnet,
    signers: [
      WalletSigner(
        id: 'signer-0',
        signer: SignerEntity.remote,
        signerDevice: device,
        descriptorKeys: keys,
      ),
    ],
    scriptType: null,
    publicDescriptor:
        'wsh(or_d(pk($origin/<0;1>/*),'
        'and_v(v:older(20),pk($origin/<2;3>/*))))',
    balanceSat: BigInt.zero,
  );
}

class _MockRepository extends Mock implements BitBoxDeviceRepository {}
