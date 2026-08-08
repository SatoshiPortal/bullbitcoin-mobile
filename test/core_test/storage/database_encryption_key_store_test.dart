import 'package:bb_mobile/core/storage/database_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refuses to replace a missing key when a database exists', () {
    expect(
      () => DatabaseEncryptionKeyStore.ensureKeyCanBeCreated(
        hasExistingDatabase: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('allows a key to be created for a new installation', () {
    expect(
      () => DatabaseEncryptionKeyStore.ensureKeyCanBeCreated(
        hasExistingDatabase: false,
      ),
      returnsNormally,
    );
  });
}
