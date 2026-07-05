import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// INTERNAL bridge that lets the sealed widgets (and ONLY them, being
/// in-package) read a stored mnemonic for display. The words are handed to the
/// widget that renders them and never exposed through the public API. Never
/// exported from the barrel.
class MnemonicReader {
  MnemonicReader(this._store);
  final SecretStorePort _store;

  Future<({List<String> words, String? passphrase})> read(Fingerprint fp) {
    return _store.useAndForget(SecretStoreKeys.seedKey(fp.hex), (bytes) async {
      final mnemonic = Mnemonic.fromStorageBytes(bytes);
      return (words: mnemonic.words, passphrase: mnemonic.passphrase);
    });
  }
}
