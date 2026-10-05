import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/features/exchange_support_chat/data/attachment_picker_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPicker extends Mock implements ImagePicker {}

void main() {
  late _MockPicker picker;

  setUp(() {
    picker = _MockPicker();
    when(() => picker.pickMultiImage()).thenAnswer((_) async => []);
  });

  AttachmentPickerRepositoryImpl build() =>
      AttachmentPickerRepositoryImpl(picker: picker);

  Failure failureOf(Object result) => (result as Err).failure;

  test('picking asks for no permission on any platform', () async {
    // The gallery is read through an out-of-process picker that grants access
    // to the chosen items only, so gating on a photo-library permission would
    // prompt for nothing and, on Android 13+, block on a permission that is not
    // in the manifest and can never be granted.
    final result = await build().pickImages();

    expect(result, isA<Ok>());
    verify(() => picker.pickMultiImage()).called(1);
  });

  test('a dismissed picker is an empty success, not a failure', () async {
    when(() => picker.pickMultiImage()).thenAnswer((_) async => []);

    expect((await build().pickImages() as Ok).value, isEmpty);
  });

  test('picked images become attachments carrying their bytes', () async {
    when(() => picker.pickMultiImage()).thenAnswer(
      (_) async => [
        // `name:` alone is not enough — XFile derives `.name` from the path.
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.png',
          path: 'receipt.png',
        ),
      ],
    );

    final attachments = (await build().pickImages() as Ok).value;

    expect(attachments, hasLength(1));
    expect(attachments.single.fileName, 'receipt.png');
    expect(attachments.single.fileType, 'image/png');
    expect(attachments.single.fileSize, 3);
  });

  test(
    'a throwing picker is sanitized, keeping the reason for logs only',
    () async {
      when(
        () => picker.pickMultiImage(),
      ).thenThrow(Exception('MissingPluginException at /data/user/0/secret'));

      final failure = failureOf(await build().pickImages());

      expect(failure, isA<PickFilesFailure>());
      expect(failure.logMessage, contains('/data/user/0/secret'));
    },
  );
}
