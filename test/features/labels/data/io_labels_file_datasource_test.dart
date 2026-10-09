import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/data/io_labels_file_datasource.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final datasource = IoLabelsFileDatasource();

  Future<String> writeFile(List<int> bytes) async {
    final dir = await Directory.systemTemp.createTemp('labels_file_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/labels.jsonl');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('reads a UTF-8 file', () async {
    const jsonl = '{"type":"tx","ref":"abc","label":"café"}';
    final path = await writeFile(utf8.encode(jsonl));

    final result = await datasource.readText(path, maxBytes: 1024);

    expect((result as Ok<String, LabelFailure>).value, jsonl);
  });

  test('a file over the limit is rejected with the limit', () async {
    final path = await writeFile(List.filled(11, 0x61));

    final result = await datasource.readText(path, maxBytes: 10);

    final failure = (result as Err<String, LabelFailure>).failure;
    expect((failure as LabelsFileTooLargeFailure).maxBytes, 10);
  });

  test('a file exactly at the limit is read', () async {
    final path = await writeFile(List.filled(10, 0x61));

    final result = await datasource.readText(path, maxBytes: 10);

    expect((result as Ok<String, LabelFailure>).value, 'a' * 10);
  });

  test('a file that is not text reads as the wrong file', () async {
    final path = await writeFile([0xff, 0xfe, 0xfd]);

    final result = await datasource.readText(path, maxBytes: 1024);

    expect(
      (result as Err<String, LabelFailure>).failure,
      isA<LabelsFileUnreadableFailure>(),
    );
  });

  test('a missing file is an unexpected failure', () async {
    final dir = await Directory.systemTemp.createTemp('labels_file_test');
    addTearDown(() => dir.delete(recursive: true));

    final result = await datasource.readText(
      '${dir.path}/gone.jsonl',
      maxBytes: 1024,
    );

    expect(
      (result as Err<String, LabelFailure>).failure,
      isA<LabelUnexpectedFailure>(),
    );
  });
}
