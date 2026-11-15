import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/features/exchange_settings/data/file_picker_document_adapter.dart';
import 'package:bb_mobile/features/exchange_settings/domain/document_picker_port.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Picker extends Mock implements FilePickerPlatform {}

final class _Document extends PlatformFile {
  final bool readable;

  _Document({this.readable = true});

  @override
  String get name => 'document.PDF';

  @override
  Future<Uint8List> readAsBytes() async {
    if (!readable) throw const FileSystemException('unreadable test document');
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Picker picker;
  late FilePickerDocumentAdapter adapter;

  setUp(() {
    picker = _Picker();
    adapter = FilePickerDocumentAdapter(filePicker: picker);
    registerFallbackValue(FileType.any);
  });

  void selects(PlatformFile? document) {
    when(
      () => picker.pickFile(
        type: any(named: 'type'),
        allowedExtensions: any(named: 'allowedExtensions'),
      ),
    ).thenAnswer((_) async => document);
  }

  test('returns the selected document bytes and their actual size', () async {
    selects(_Document());
    final result = await adapter.pick(allowedExtensions: ['pdf']);
    switch (result) {
      case Ok(:final value):
        expect(value?.name, 'document.PDF');
        expect(value?.extension, 'pdf');
        expect(value?.bytes, [1, 2, 3]);
        expect(value?.sizeBytes, 3);
      case Err():
        fail('the selected readable document should be returned');
    }
  });

  test('cancelled selection returns no document', () async {
    selects(null);
    expect(
      await adapter.pick(allowedExtensions: ['pdf']),
      const Ok<PickedDocument?, ExchangeSettingsFailure>(null),
    );
  });

  test('a selected unreadable file retains the document failure', () async {
    selects(_Document(readable: false));
    final result = await adapter.pick(allowedExtensions: ['pdf']);
    expect(
      result,
      isA<Err<PickedDocument?, ExchangeSettingsFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSettingsDocumentUnreadableFailure>(),
      ),
    );
  });
}
