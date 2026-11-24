import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('swaps and wallet do not leave a legacy core entry point', () {
    for (final name in ['swaps', 'wallet']) {
      expect(Directory('lib/core/$name').existsSync(), isFalse);
    }
  });
}
