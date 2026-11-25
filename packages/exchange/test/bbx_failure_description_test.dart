import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `BbxFailure.toString` is the one log-safe description of an API failure
/// (kind, codes, the server's request id). A repository that rebuilds that
/// text from the failure's fields drops whatever it forgets, as the request
/// id once was, so none may.
void main() {
  test('no exchange code rebuilds the description of a bbx failure', () {
    final rebuilt = RegExp(r'''['"]Bbx[A-Za-z]*Failure\(''');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (rebuilt.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: r"log '$failure' instead");
  });
}
