import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation does not depend on the data layer or repository', () {
    final source = File(
      'lib/src/presentation/quick_actions_cubit.dart',
    ).readAsStringSync();
    expect(source, isNot(contains("../data/")));
    expect(source, isNot(contains('QuickActionsRepository')));
  });
}
