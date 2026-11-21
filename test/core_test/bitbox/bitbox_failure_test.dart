import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/data/repositories/bitbox_device_repository_impl.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/features/bitbox/domain/read_bitbox_account_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/pair_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/features/bitbox/domain/sign_psbt_bitbox_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/unlock_bitbox_device_usecase.dart';
import 'package:bb_mobile/features/bitbox/domain/verify_address_bitbox_usecase.dart';
import 'package:primitives/primitives.dart'
    show NetworkEnv, Err, Ok, ScriptType;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements BitBoxDeviceDatasource {}

const _device = BitBoxDeviceEntity(
  deviceName: 'BitBox02',
  serialNumber: '0001',
  product: 'bitbox02',
  connectionType: BitBoxConnectionType.usb,
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
        when(() => datasource.getMasterFingerprint(any()))
            .thenThrow(Exception('SECRET raw SDK internals'));

        final result = await repository.getMasterFingerprint(_device);

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<BitBoxUnexpectedFailure>());
      },
    );

    test('passes through a semantic BitBoxFailure unchanged', () async {
      when(() => datasource.getMasterFingerprint(any()))
          .thenThrow(const PermissionDeniedBitBoxFailure());

      final result = await repository.getMasterFingerprint(_device);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<PermissionDeniedBitBoxFailure>());
    });

    test('returns Ok on success', () async {
      when(() => datasource.getMasterFingerprint(any()))
          .thenAnswer((_) async => 'aabbccdd');

      final result = await repository.getMasterFingerprint(_device);

      expect(result, isA<Ok>());
      expect((result as Ok).value, 'aabbccdd');
    });
  });

  group('SignPsbtBitBoxUsecase (network boundary)', () {
    test('refuses regtest before accessing the device', () async {
      final repo = _MockRepository();
      final usecase = SignPsbtBitBoxUsecase(repository: repo);

      final result = await usecase.execute(
        _device,
        network: NetworkEnv.regtest,
        psbt: 'psbt',
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
      when(() => repo.connectDevice(_device))
          .thenAnswer((_) async => const Err(ConnectionFailedBitBoxFailure()));

      final result = await usecase.execute(_device);

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ConnectionFailedBitBoxFailure>());
    });
  });

  group('UnlockBitBoxDeviceUsecase', () {
    test('propagates the sanitized failure from the repository', () async {
      final repo = _MockRepository();
      final usecase = UnlockBitBoxDeviceUsecase(repository: repo);
      when(() => repo.unlockDevice(_device))
          .thenAnswer((_) async => const Err(OperationTimeoutBitBoxFailure()));

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
      when(
        () => repo.verifyAddress(
          _device,
          address: 'bc1qexpected',
          derivationPath: "m/84'/0'/0'",
          scriptType: ScriptType.bip84,
          isTestnet: false,
        ),
      ).thenAnswer((_) async => const Ok(false));
      final usecase = VerifyAddressBitBoxUsecase(repository: repo);

      final result = await usecase.execute(
        network: NetworkEnv.mainnet,
        device: _device,
        address: 'bc1qexpected',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<InvalidResponseBitBoxFailure>());
    });
  });

  group('ReadBitBoxAccountUsecase', () {
    test('refuses regtest before accessing the device', () async {
      final usecase = ReadBitBoxAccountUsecase(repository: _MockRepository());

      final result = await usecase.execute(
        network: NetworkEnv.regtest,
        device: _device,
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<InvalidParametersBitBoxFailure>());
    });
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
      when(() => repo.scanDevices())
          .thenAnswer((_) async => const Ok([_device]));

      final result = await usecase.execute();

      expect(result, isA<Ok>());
      expect((result as Ok).value, [_device]);
    });
  });
}

class _MockRepository extends Mock implements BitBoxDeviceRepository {}
