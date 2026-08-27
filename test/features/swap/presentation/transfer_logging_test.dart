import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transfer error reports never attach raw exception objects', () {
    final source = File(
      'lib/features/swap/presentation/transfer_bloc.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('error: e,')));
    expect(source, isNot(contains(r'failed: $error')));
  });
}
