import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/add_custom_server_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isOnionCustomServerInput', () {
    test('recognizes supported onion server formats', () {
      expect(isOnionCustomServerInput('hidden.onion:50002'), isTrue);
      expect(isOnionCustomServerInput('hidden.onion:50002:t'), isTrue);
      expect(isOnionCustomServerInput('hidden.onion:50002:s'), isTrue);
    });

    test('rejects clearnet and incomplete inputs', () {
      expect(isOnionCustomServerInput('electrum.example.com:50002'), isFalse);
      expect(isOnionCustomServerInput('hidden.onion'), isFalse);
      expect(isOnionCustomServerInput(''), isFalse);
    });
  });
}
