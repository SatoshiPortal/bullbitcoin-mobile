import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// INTERNAL bridge that lets the sealed widgets (and ONLY them, being
/// in-package) read a stored mnemonic for display. The words are handed to the
/// widget that renders them and never exposed through the public API. Never
/// exported from the barrel.
class MnemonicReader {
  MnemonicReader(this._store);
  final SecretStore _store;

  Future<({List<String> words, String? passphrase})> read(Fingerprint fp) {
    return _store.useAndForget(SecretStoreKeys.seedKey(fp.hex), (bytes) async {
      final secret = SeedSecret.fromStorageBytes(bytes);
      if (secret is MnemonicSeedSecret) {
        return (words: secret.words, passphrase: secret.passphrase);
      }
      return (words: <String>[], passphrase: null);
    });
  }
}
