import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'exchange_state_machine_rules_test.dart' as rules;

void main() {
  test('the exchange route guard detects route literals in every context', () {
    final directory = Directory.systemTemp.createTempSync('exchange-routes-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/sentinel.dart');
    for (final expression in [
      "void f(dynamic context) { context.go('/settings'); }",
      "const destination = '/settings';",
      "final destination = Uri.base.resolve('/settings');",
    ]) {
      source.writeAsStringSync(expression);
      expect(rules.appPathLiterals([source], {'/settings'}), hasLength(1));
    }
    source.writeAsStringSync(
      "const destination = 'https://accounts.bullbitcoin.com/settings';",
    );
    expect(rules.appPathLiterals([source], {'/settings'}), isEmpty);
  });
}
