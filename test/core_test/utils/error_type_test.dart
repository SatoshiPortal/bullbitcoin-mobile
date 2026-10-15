import 'package:bb_mobile/core/utils/error_type.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names an error by its type, never its text', () {
    expect(errorType(const FormatException('legal winner')), 'FormatException');
  });

  test('keeps a platform error code and numeric status, not its message', () {
    final ios = PlatformException(
      code: 'Unexpected security result code',
      message: 'legal winner',
      details: -25300,
    );
    final android = PlatformException(
      code: 'Exception encountered',
      message: 'legal winner',
      details: 'stack trace',
    );
    expect(
      errorType(ios),
      'PlatformException(Unexpected security result code, -25300)',
    );
    expect(errorType(android), 'PlatformException(Exception encountered)');
  });
}
