import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_cubit.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_state.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetLatestUsecase extends Mock
    implements GetLatestColdcardFirmwareUsecase {}

class _MockDownloadAndVerifyUsecase extends Mock
    implements DownloadAndVerifyColdcardFirmwareUsecase {}

class _MockSaveUsecase extends Mock implements SaveColdcardFirmwareUsecase {}

class _MockCancelDownloadUsecase extends Mock
    implements CancelColdcardFirmwareDownloadUsecase {}

final _release = FirmwareRelease(
  model: ColdcardModel.q,
  version: const FirmwareVersion(1, 4, 1, hasQMarker: true),
  timestampRaw: '2026-07-01T1727',
  filename: '2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu',
  downloadUrl:
      'https://coldcard.com/downloads/2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu',
  expectedSha256Hex: 'a' * 64,
);

void main() {
  setUpAll(() => registerFallbackValue(ColdcardModel.q));

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

  ColdcardFirmwareCubit buildCubit() => ColdcardFirmwareCubit(
    getLatestColdcardFirmwareUsecase: getLatest,
    downloadAndVerifyColdcardFirmwareUsecase: downloadAndVerify,
    saveColdcardFirmwareUsecase: save,
    cancelColdcardFirmwareDownloadUsecase: cancelDownload,
  );

  Future<ColdcardFirmwareCubit> buildLoadedCubit() async {
    when(() => getLatest.execute(any())).thenAnswer((_) async => Ok(_release));
    final cubit = buildCubit();
    await cubit.loadLatest(ColdcardModel.q);
    return cubit;
  }

  Future<ColdcardFirmwareCubit> buildVerifiedCubit() async {
    when(
      () => downloadAndVerify.execute(
        onProgress: any(named: 'onProgress'),
        onVerifying: any(named: 'onVerifying'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = await buildLoadedCubit();
    await cubit.downloadAndVerify();
    return cubit;
  }

  group('loadLatest', () {
    test('emits fetchingLatest then latestReady on success', () async {
      when(
        () => getLatest.execute(any()),
      ).thenAnswer((_) async => Ok(_release));
      final cubit = buildCubit();
      final statuses = <ColdcardFirmwareStatus>[];
      final subscription = cubit.stream.listen(
        (state) => statuses.add(state.status),
      );

      await cubit.loadLatest(ColdcardModel.q);
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [
        ColdcardFirmwareStatus.fetchingLatest,
        ColdcardFirmwareStatus.latestReady,
      ]);
      expect(cubit.state.latestRelease, same(_release));
      expect(cubit.state.model, ColdcardModel.q);
      await subscription.cancel();
      await cubit.close();
    });

    test('clears a stale release before rediscovery', () async {
      var call = 0;
      when(() => getLatest.execute(any())).thenAnswer((_) async {
        call++;
        return call == 1
            ? Ok(_release)
            : const Err<FirmwareRelease, ColdcardFirmwareFailure>(
                ColdcardFirmwareNetworkFailure(),
              );
      });
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardModel.q);

      await cubit.loadLatest(ColdcardModel.q);

      expect(cubit.state.status, ColdcardFirmwareStatus.failure);
      expect(cubit.state.latestRelease, isNull);
      await cubit.close();
    });
  });

  group('downloadAndVerify', () {
    test('walks download progress through verification to verified', () async {
      when(
        () => downloadAndVerify.execute(
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
        return const Ok(null);
      });
      final cubit = await buildLoadedCubit();
      final states = <ColdcardFirmwareState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.downloadAndVerify();
      await Future<void>.delayed(Duration.zero);

      expect(
        states.map((state) => state.status),
        containsAllInOrder([
          ColdcardFirmwareStatus.downloading,
          ColdcardFirmwareStatus.verifying,
          ColdcardFirmwareStatus.verified,
        ]),
      );
      expect(
        states
            .where(
              (state) => state.status == ColdcardFirmwareStatus.downloading,
            )
            .last
            .downloadProgress,
        1,
      );
      await subscription.cancel();
      await cubit.close();
    });

    test('does nothing before a release is loaded', () async {
      final cubit = buildCubit();

      await cubit.downloadAndVerify();

      expect(cubit.state.status, ColdcardFirmwareStatus.initial);
      verifyNever(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      );
      await cubit.close();
    });

    test('verification failure lands on failure status', () async {
      when(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer(
        (_) async => const Err(ColdcardFirmwareVerificationFailure()),
      );
      final cubit = await buildLoadedCubit();

      await cubit.downloadAndVerify();

      expect(cubit.state.status, ColdcardFirmwareStatus.failure);
      expect(cubit.state.failure, isA<ColdcardFirmwareVerificationFailure>());
      await cubit.close();
    });
  });

  group('exportFirmware', () {
    test('does not call save before verification', () async {
      final cubit = await buildLoadedCubit();

      await cubit.exportFirmware();

      verifyNever(() => save.execute());
      await cubit.close();
    });

    test('supports successful repeated exports', () async {
      when(() => save.execute()).thenAnswer((_) async => const Ok(true));
      final cubit = await buildVerifiedCubit();

      await cubit.exportFirmware();
      expect(cubit.state.exportSucceeded, isTrue);
      cubit.clearExportFlags();
      await cubit.exportFirmware();

      verify(() => save.execute()).called(2);
      expect(cubit.state.status, ColdcardFirmwareStatus.verified);
      await cubit.close();
    });

    test('picker cancellation is neither success nor failure', () async {
      when(() => save.execute()).thenAnswer((_) async => const Ok(false));
      final cubit = await buildVerifiedCubit();

      await cubit.exportFirmware();

      expect(cubit.state.exportSucceeded, isFalse);
      expect(cubit.state.exportFailure, isNull);
      expect(cubit.state.status, ColdcardFirmwareStatus.verified);
      await cubit.close();
    });

    test('save failure leaves export available', () async {
      when(
        () => save.execute(),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareSaveFailure()));
      final cubit = await buildVerifiedCubit();

      await cubit.exportFirmware();

      expect(cubit.state.exportFailure, isA<ColdcardFirmwareSaveFailure>());
      expect(cubit.state.status, ColdcardFirmwareStatus.verified);
      await cubit.close();
    });
  });

  group('retry', () {
    test('keeps rediscovering after rediscovery itself fails', () async {
      var fetchCall = 0;
      when(() => getLatest.execute(any())).thenAnswer((_) async {
        fetchCall++;
        return switch (fetchCall) {
          1 => Ok(_release),
          _ => const Err<FirmwareRelease, ColdcardFirmwareFailure>(
            ColdcardFirmwareNetworkFailure(),
          ),
        };
      });
      when(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareDiscoveryFailure()));
      final cubit = buildCubit();
      await cubit.loadLatest(ColdcardModel.q);
      await cubit.downloadAndVerify();

      cubit.retry();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.latestRelease, isNull);
      cubit.retry();
      await Future<void>.delayed(Duration.zero);

      verify(() => getLatest.execute(ColdcardModel.q)).called(3);
      verify(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).called(1);
      await cubit.close();
    });

    test('retries download after a non-discovery failure', () async {
      when(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((_) async => const Err(ColdcardFirmwareNetworkFailure()));
      final cubit = await buildLoadedCubit();
      await cubit.downloadAndVerify();

      cubit.retry();
      await Future<void>.delayed(Duration.zero);

      verify(() => getLatest.execute(any())).called(1);
      verify(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).called(2);
      await cubit.close();
    });
  });

  test(
    'close cancels a pending download and ignores late completion',
    () async {
      final completion = Completer<Result<void, ColdcardFirmwareFailure>>();
      when(
        () => downloadAndVerify.execute(
          onProgress: any(named: 'onProgress'),
          onVerifying: any(named: 'onVerifying'),
        ),
      ).thenAnswer((_) => completion.future);
      final cubit = await buildLoadedCubit();
      final operation = cubit.downloadAndVerify();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, ColdcardFirmwareStatus.downloading);

      await cubit.close();
      completion.complete(const Ok(null));
      await operation;

      verify(() => cancelDownload.execute()).called(1);
    },
  );
}
