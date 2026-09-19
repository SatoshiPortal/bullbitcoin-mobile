import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'user Nostr identities preserve the existing user and application ranges',
    () {
      expect(nostrUserKeyPath(99), "128002'/99'/1'");
      expect(nostrUserKeyPath(200), "128002'/200'/1'");
      for (final index in [0, 100, 199, 0x80000000]) {
        expect(() => nostrUserKeyPath(index), throwsFormatException);
      }
      expect(nostrUserKeyIdentity("128002'/200'/1'"), 200);
      expect(nostrUserKeyIdentity("128002'/101'/1'"), isNull);
      expect(nostrUserKeyIdentity("128002'/1'/2'"), isNull);
    },
  );
}
