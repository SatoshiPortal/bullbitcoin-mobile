import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/data/repositories/bitbox_device_repository_impl.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/get_bitbox_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/pair_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/sign_psbt_bitbox_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/unlock_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/verify_address_bitbox_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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

    test('validates missing psbt below presentation — no raw leak', () async {
      final usecase = SignPsbtBitBoxUsecase(
        repository: _MockRepository(),
        settingsRepository: _MockSettingsRepository(),
      );

      final result = await usecase.execute(
        _device,
        psbt: null,
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<InvalidParametersBitBoxFailure>());
    });
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
    test('returns InvalidParameters on missing input — no raw leak', () async {
      final usecase = VerifyAddressBitBoxUsecase(
        repository: _MockRepository(),
        settingsRepository: _MockSettingsRepository(),
      );

      final result = await usecase.execute(
        device: _device,
        address: null,
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<InvalidParametersBitBoxFailure>());
    });

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

class _MockRepository extends Mock implements BitBoxDeviceRepository {}
