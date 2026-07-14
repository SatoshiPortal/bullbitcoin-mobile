import 'dart:typed_data';

import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/verified_coldcard_firmware_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_cubit.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetLatestUsecase extends Mock
    implements GetLatestColdcardFirmwareUsecase {}

class _MockDownloadAndVerifyUsecase extends Mock
    implements DownloadAndVerifyColdcardFirmwareUsecase {}

class _MockSaveUsecase extends Mock implements SaveColdcardFirmwareUsecase {}

class _MockCancelDownloadUsecase extends Mock
    implements CancelColdcardFirmwareDownloadUsecase {}

final _release = ColdcardFirmwareReleaseEntity(
  device: ColdcardDevice.q,
  versionLabel: 'v1.4.1Q',
  filename: '2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu',
  sha256Hex: 'a' * 64,
);

final _verified = VerifiedColdcardFirmwareEntity(
  release: _release,
  bytes: Uint8List.fromList([1, 2, 3]),
  sha256Hex: 'a' * 64,
  signerName: 'Peter D. Gray <peter@coinkite.com>',
  signerFingerprintHex: '4589779adfc14f3327534ea8a3a31bad5a2a5b10',
);

void main() {
  setUpAll(() {
    registerFallbackValue(ColdcardDevice.q);
    registerFallbackValue(_release);
    registerFallbackValue(_verified);
  });

  late _MockGetLatestUsecase getLatest;
  late _MockDownloadAndVerifyUsecase downloadAndVerify;
  late _MockSaveUsecase save;
  late _MockCancelDownloadUsecase cancelDownload;

  setUp(() {
    getLatest = _MockGetLatestUsecase();
    downloadAndVerify = _MockDownloadAndVerifyUsecase();
    save = _MockSaveUsecase();
    cancelDownload = _MockCancelDownloadUsecase();
    when(() => cancelDownload.execute()).thenReturn(null);
  });

  ColdcardFirmwareCubit buildCubit() {
    return ColdcardFirmwareCubit(
      getLatestColdcardFirmwareUsecase: getLatest,
      downloadAndVerifyColdcardFirmwareUsecase: downloadAndVerify,
      saveColdcardFirmwareUsecase: save,
      cancelColdcardFirmwareDownloadUsecase: cancelDownload,
    );
  }

  group('loadLatest', () {
    test('emits fetchingLatest then latestReady on success', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      final cubit = buildCubit();
      final statuses = <ColdcardFirmwareStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));

      await cubit.loadLatest(ColdcardDevice.q);
      // Stream delivery is async; let the pending events reach the listener.
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [
        ColdcardFirmwareStatus.fetchingLatest,
        ColdcardFirmwareStatus.latestReady,
      ]);
      expect(cubit.state.latestRelease, _release);
      expect(cubit.state.device, ColdcardDevice.q);
      await sub.cancel();
      await cubit.close();
    });

    test('emits failure status carrying the failure', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareNetworkFailure()));
      final cubit = buildCubit();

      await cubit.loadLatest(ColdcardDevice.mk4);

      expect(cubit.state.status, ColdcardFirmwareStatus.failure);
      expect(cubit.state.failure, isA<ColdcardFirmwareNetworkFailure>());
      await cubit.close();
    });
  });

  group('downloadAndVerify', () {
    test('walks downloading (with progress) → verifying → verified', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      when(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(int, int?)?;
        final onVerifying =
            invocation.namedArguments[#onVerifying] as void Function()?;
        onProgress?.call(512, 1024);
        onProgress?.call(1024, 1024);
        onVerifying?.call();
        return Ok(_verified);
      });
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardDevice.q);
      final states = <ColdcardFirmwareState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.downloadAndVerify();
      // Stream delivery is async; let the pending events reach the listener.
      await Future<void>.delayed(Duration.zero);

      expect(states.first.status, ColdcardFirmwareStatus.downloading);
      expect(
        states.map((s) => s.status),
        containsAllInOrder([
          ColdcardFirmwareStatus.downloading,
          ColdcardFirmwareStatus.verifying,
          ColdcardFirmwareStatus.verified,
        ]),
      );
      final progressStates = states
          .where((s) => s.status == ColdcardFirmwareStatus.downloading)
          .toList();
      expect(progressStates.last.downloadedBytes, 1024);
      expect(progressStates.last.downloadProgress, 1.0);
      expect(cubit.state.verifiedFirmware, _verified);
      await sub.cancel();
      await cubit.close();
    });

    test('does nothing when no release is loaded', () async {
      final cubit = buildCubit();
      await cubit.downloadAndVerify();
      expect(cubit.state.status, ColdcardFirmwareStatus.initial);
      verifyNever(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      );
      await cubit.close();
    });

    test('verification failure lands on failure status', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      when(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer(
        (_) async => const Err(ColdcardFirmwareVerificationFailure()),
      );
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardDevice.q);

      await cubit.downloadAndVerify();

      expect(cubit.state.status, ColdcardFirmwareStatus.failure);
      expect(cubit.state.failure, isA<ColdcardFirmwareVerificationFailure>());
      expect(cubit.state.verifiedFirmware, isNull);
      await cubit.close();
    });
  });

  group('exportFirmware', () {
    Future<ColdcardFirmwareCubit> verifiedCubit() async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      when(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((_) async => Ok(_verified));
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardDevice.q);
      await cubit.downloadAndVerify();
      return cubit;
    }

    test('sets one-shot exportSucceeded on save', () async {
      when(() => save.execute(any())).thenAnswer((_) async => const Ok(true));
      final cubit = await verifiedCubit();

      await cubit.exportFirmware();

      expect(cubit.state.exportSucceeded, isTrue);
      expect(cubit.state.status, ColdcardFirmwareStatus.verified);
      cubit.clearExportFlags();
      expect(cubit.state.exportSucceeded, isFalse);
      await cubit.close();
    });

    test('a cancelled picker is neither success nor failure', () async {
      when(() => save.execute(any())).thenAnswer((_) async => const Ok(false));
      final cubit = await verifiedCubit();

      await cubit.exportFirmware();

      expect(cubit.state.exportSucceeded, isFalse);
      expect(cubit.state.exportFailure, isNull);
      expect(cubit.state.status, ColdcardFirmwareStatus.verified);
      await cubit.close();
    });

    test('a save failure stays on the verified screen', () async {
      when(
        () => save.execute(any()),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareSaveFailure()));
      final cubit = await verifiedCubit();

      await cubit.exportFirmware();

      expect(cubit.state.exportFailure, isA<ColdcardFirmwareSaveFailure>());
      expect(cubit.state.status, ColdcardFirmwareStatus.verified);
      await cubit.close();
    });
  });

  group('retry', () {
    test('re-discovers after a discovery failure instead of looping the '
        'same stale release', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      when(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareDiscoveryFailure()));
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardDevice.q);
      await cubit.downloadAndVerify();
      expect(cubit.state.status, ColdcardFirmwareStatus.failure);

      cubit.retry();
      await Future<void>.delayed(Duration.zero);

      verify(() => getLatest.execute(ColdcardDevice.q)).called(2);
      await cubit.close();
    });

    test('retries the download after a non-discovery failure', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      when(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareNetworkFailure()));
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardDevice.q);
      await cubit.downloadAndVerify();

      cubit.retry();
      await Future<void>.delayed(Duration.zero);

      verify(() => getLatest.execute(any())).called(1); // only the initial load
      verify(
        () => downloadAndVerify.execute(
          any(),
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).called(2);
      await cubit.close();
    });
  });

  test('close aborts an in-flight download', () async {
    final cubit = buildCubit();
    await cubit.close();
    verify(() => cancelDownload.execute()).called(1);
  });
}
