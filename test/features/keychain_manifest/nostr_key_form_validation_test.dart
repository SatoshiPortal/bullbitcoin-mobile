import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assigns invalid name characters only to the name field', () {
    expect(
      validateNostrKeyForm('bad\nname', 'valid'),
      NostrKeyFormError.invalidNameCharacters,
    );
  });

  test('assigns invalid description characters only to description', () {
    expect(
      validateNostrKeyForm('valid', 'bad\ndescription'),
      NostrKeyFormError.invalidDescriptionCharacters,
    );
  });
}
