import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockColdcardFirmwareRepository extends Mock
    implements ColdcardFirmwareRepository {}

void main() {
  late _MockColdcardFirmwareRepository repository;

  setUp(() {
    repository = _MockColdcardFirmwareRepository();
  });

  group('GetLatestColdcardFirmwareUsecase', () {
    test('forwards the model and returns the repository result', () async {
      const repositoryResult = Err<FirmwareRelease, ColdcardFirmwareFailure>(
        ColdcardFirmwareDiscoveryFailure(),
      );
      when(
        () => repository.fetchLatest(ColdcardModel.q),
      ).thenAnswer((_) async => repositoryResult);
      final usecase = GetLatestColdcardFirmwareUsecase(repository: repository);

      final result = await usecase.execute(ColdcardModel.q);

      expect(result, same(repositoryResult));
      verify(() => repository.fetchLatest(ColdcardModel.q)).called(1);
    });
  });

  group('DownloadAndVerifyColdcardFirmwareUsecase', () {
    test('forwards callbacks and returns the repository result', () async {
      const repositoryResult = Err<void, ColdcardFirmwareFailure>(
        ColdcardFirmwareVerificationFailure(),
      );
      int? reportedReceived;
      int? reportedTotal;
      var verifyingCalled = false;
      void onProgress(int received, int? total) {
        reportedReceived = received;
        reportedTotal = total;
      }

      void onVerifying() => verifyingCalled = true;

      when(
        () => repository.downloadAndVerify(
          onProgress: onProgress,
          onVerifying: onVerifying,
        ),
      ).thenAnswer((invocation) async {
        final forwardedProgress =
            invocation.namedArguments[#onProgress]
                as void Function(int received, int? total)?;
        final forwardedVerifying =
            invocation.namedArguments[#onVerifying] as void Function()?;
        forwardedProgress?.call(25, 100);
        forwardedVerifying?.call();
        return repositoryResult;
      });
      final usecase = DownloadAndVerifyColdcardFirmwareUsecase(
        repository: repository,
      );

      final result = await usecase.execute(
        onProgress: onProgress,
        onVerifying: onVerifying,
      );

      expect(result, same(repositoryResult));
      expect(reportedReceived, 25);
      expect(reportedTotal, 100);
      expect(verifyingCalled, isTrue);
      verify(
        () => repository.downloadAndVerify(
          onProgress: onProgress,
          onVerifying: onVerifying,
        ),
      ).called(1);
    });
  });

  group('SaveColdcardFirmwareUsecase', () {
    test('returns the repository result', () async {
      const repositoryResult = Ok<bool, ColdcardFirmwareFailure>(false);
      when(
        () => repository.saveVerifiedFirmware(),
      ).thenAnswer((_) async => repositoryResult);
      final usecase = SaveColdcardFirmwareUsecase(repository: repository);

      final result = await usecase.execute();

      expect(result, same(repositoryResult));
      verify(() => repository.saveVerifiedFirmware()).called(1);
    });
  });

  group('CancelColdcardFirmwareDownloadUsecase', () {
    test('delegates cancellation to the repository', () {
      when(() => repository.cancelDownload()).thenReturn(null);
      final usecase = CancelColdcardFirmwareDownloadUsecase(
        repository: repository,
      );

      usecase.execute();

      verify(() => repository.cancelDownload()).called(1);
    });
  });
}
