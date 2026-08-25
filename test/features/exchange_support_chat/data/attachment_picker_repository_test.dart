import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/features/exchange_support_chat/data/attachment_picker_repository_impl.dart';
import 'package:bb_mobile/features/exchange_support_chat/data/photo_library_permission_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:primitives/primitives.dart';

class _MockPermissions extends Mock
    implements PhotoLibraryPermissionDatasource {}

class _MockPicker extends Mock implements ImagePicker {}

void main() {
  late _MockPermissions permissions;
  late _MockPicker picker;

  setUpAll(() {
    registerFallbackValue(Permission.photos);
  });

  setUp(() {
    permissions = _MockPermissions();
    picker = _MockPicker();
    when(() => picker.pickMultiImage()).thenAnswer((_) async => []);
  });

  AttachmentPickerRepositoryImpl build({required bool isAndroid}) =>
      AttachmentPickerRepositoryImpl(
        permissions: permissions,
        isAndroid: isAndroid,
        picker: picker,
      );

  /// Current status, then the status the OS returns if we prompt.
  void stub(
    Permission permission, {
    required PermissionStatus status,
    PermissionStatus? afterRequest,
  }) {
    when(() => permissions.status(permission)).thenAnswer((_) async => status);
    when(
      () => permissions.request(permission),
    ).thenAnswer((_) async => afterRequest ?? status);
  }

  Failure failureOf(Object result) => (result as Err).failure;

  group('platforms with no gallery permission model', () {
    // The PHPicker runs out of process, so iOS needs no grant. Gating on one would prompt every user for nothing and let a refusal block a picker that works, which is exactly the regression these two tests exist to prevent.
    test('iOS asks for no photo permission, even a denied one', () async {
      stub(Permission.photos, status: PermissionStatus.permanentlyDenied);
      stub(Permission.storage, status: PermissionStatus.permanentlyDenied);

      final result = await build(isAndroid: false).pickImages();

      expect(result, isA<Ok>());
      verifyNever(() => permissions.status(any()));
      verifyNever(() => permissions.request(any()));
    });

    test('a desktop platform needs no permission at all', () async {
      final result = await build(isAndroid: false).pickImages();

      expect(result, isA<Ok>());
      verifyNever(() => permissions.status(any()));
    });
  });

  group('Android', () {
    test(
      'partial photo access counts as access and is never re-prompted',
      () async {
        stub(Permission.photos, status: PermissionStatus.limited);

        final result = await build(isAndroid: true).pickImages();

        expect(result, isA<Ok>());
        verifyNever(() => permissions.request(any()));
      },
    );

    test('pre-13 devices fall back to the legacy storage permission', () async {
      stub(Permission.photos, status: PermissionStatus.denied);
      stub(Permission.storage, status: PermissionStatus.granted);

      final result = await build(isAndroid: true).pickImages();

      expect(result, isA<Ok>());
    });

    test('a dead end on photos alone is still only retryable while storage '
        'can be granted', () async {
      stub(Permission.photos, status: PermissionStatus.permanentlyDenied);
      stub(
        Permission.storage,
        status: PermissionStatus.denied,
        afterRequest: PermissionStatus.denied,
      );

      expect(
        failureOf(await build(isAndroid: true).pickImages()),
        isA<PermissionDeniedFailure>(),
      );
    });

    test(
      'only a dead end on both routes sends the user to the settings',
      () async {
        stub(Permission.photos, status: PermissionStatus.permanentlyDenied);
        stub(Permission.storage, status: PermissionStatus.permanentlyDenied);

        expect(
          failureOf(await build(isAndroid: true).pickImages()),
          isA<PermissionDeniedNeedsSettingsFailure>(),
        );
      },
    );

    test(
      'granting on the prompt is enough, no storage fallback needed',
      () async {
        stub(
          Permission.photos,
          status: PermissionStatus.denied,
          afterRequest: PermissionStatus.granted,
        );

        final result = await build(isAndroid: true).pickImages();

        expect(result, isA<Ok>());
        verifyNever(() => permissions.status(Permission.storage));
      },
    );
  });

  group('picking', () {
    test('a dismissed picker is an empty success, not a failure', () async {
      stub(Permission.photos, status: PermissionStatus.granted);
      when(() => picker.pickMultiImage()).thenAnswer((_) async => []);

      final result = await build(isAndroid: true).pickImages();

      expect((result as Ok).value, isEmpty);
    });

    test('picked images become attachments carrying their bytes', () async {
      stub(Permission.photos, status: PermissionStatus.granted);
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

      final attachments =
          (await build(isAndroid: true).pickImages() as Ok).value;

      expect(attachments, hasLength(1));
      expect(attachments.single.fileName, 'receipt.png');
      expect(attachments.single.fileType, 'image/png');
      expect(attachments.single.fileSize, 3);
    });

    test(
      'a throwing picker is sanitized, keeping the reason for logs only',
      () async {
        stub(Permission.photos, status: PermissionStatus.granted);
        when(
          () => picker.pickMultiImage(),
        ).thenThrow(Exception('MissingPluginException at /data/user/0/secret'));

        final failure = failureOf(await build(isAndroid: true).pickImages());

        expect(failure, isA<PickFilesFailure>());
        expect(failure.logMessage, contains('/data/user/0/secret'));
      },
    );
  });
}
