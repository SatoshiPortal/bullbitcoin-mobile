import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onion/onion.dart';

void main() {
  test('rejects Snowflake on unsupported desktop platforms', () {
    expect(SnowflakeTransport.start, throwsUnsupportedError);
  }, skip: Platform.isAndroid || Platform.isIOS);
}
