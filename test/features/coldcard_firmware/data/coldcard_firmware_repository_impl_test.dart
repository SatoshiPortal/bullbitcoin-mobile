import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/data/coldcard_firmware_repository_impl.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart' as ckf;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingFilePicker extends FilePicker {
  int saveFileCalls = 0;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) {
    saveFileCalls++;
    return Future.value('/tmp/$fileName');
  }
}

void main() {
  late _RecordingFilePicker filePicker;

  setUp(() {
    filePicker = _RecordingFilePicker();
    FilePicker.platform = filePicker;
  });

  group('ColdcardFirmwareRepositoryImpl', () {
    test('downloadAndVerify before fetchLatest fails closed', () async {
      final repository = ColdcardFirmwareRepositoryImpl();

      final result = await repository.downloadAndVerify();

      expect(
        result,
        isA<Err<void, ColdcardFirmwareFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ColdcardFirmwareDiscoveryFailure>(),
        ),
      );
    });

    test(
      'saveVerifiedFirmware before verification fails without opening picker',
      () async {
        final repository = ColdcardFirmwareRepositoryImpl();

        final result = await repository.saveVerifiedFirmware();

        expect(
          result,
          isA<Err<bool, ColdcardFirmwareFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<ColdcardFirmwareVerificationFailure>(),
          ),
        );
        expect(filePicker.saveFileCalls, 0);
      },
    );

    test('maps a package network exception to a network failure', () async {
      final repository = ColdcardFirmwareRepositoryImpl(
        clientFactory: () => throw const ckf.FirmwareNetworkException(
          'https://coldcard.com',
          'offline',
        ),
      );

      final result = await repository.fetchLatest(ckf.ColdcardModel.q);

      expect(
        result,
        isA<Err<ckf.FirmwareRelease, ColdcardFirmwareFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ColdcardFirmwareNetworkFailure>(),
        ),
      );
    });

    test('maps an ordinary exception to an unexpected failure', () async {
      final repository = ColdcardFirmwareRepositoryImpl(
        clientFactory: () => throw Exception('boom'),
      );

      final result = await repository.fetchLatest(ckf.ColdcardModel.q);

      expect(
        result,
        isA<Err<ckf.FirmwareRelease, ColdcardFirmwareFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ColdcardFirmwareUnexpectedFailure>(),
        ),
      );
    });

    test('does not catch programmer errors', () async {
      final repository = ColdcardFirmwareRepositoryImpl(
        clientFactory: () => throw StateError('programmer error'),
      );

      await expectLater(
        repository.fetchLatest(ckf.ColdcardModel.q),
        throwsA(isA<StateError>()),
      );
    });
  });
}
