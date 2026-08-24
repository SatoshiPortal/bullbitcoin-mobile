// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2644
// Finding: derived secrets remain in memory and the clipboard too long.
// Regression test for the implemented mitigation: the clipboard is
// overwritten with empty text on a timer after a copy.
// NOTE: deriving every stored secret on page open and retaining entropy in
// widget controllers is NOT changed — tracked as a remaining partial in the
// audit PR.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2644 secret lifetime', () {
    test('secret widget clears the clipboard on a timer after copy', () {
      final widget = File(
        'lib/core/widgets/bip85_derivation_widget.dart',
      ).readAsStringSync();

      expect(widget, contains('Clipboard.setData'));
      // Flutter has no Clipboard.clear — the fix overwrites the clipboard
      // with empty text after a timeout.
      expect(widget, contains("ClipboardData(text: '')"));
      expect(widget, contains('_clipboardClearTimer'));
    });
  });
}
